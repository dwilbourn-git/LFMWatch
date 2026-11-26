-- LFMWatch automatic watching: dungeons picked for you, on top of the ones
-- ticked by hand. Manual ticks (ns.cdb.watched) are never changed here, so
-- turning the options off leaves them exactly as they were.
--
-- Two options, per character:
--   level   every dungeon whose level range includes your level
--   Legacy  the dungeons of the Legacy challenge sets you tick, by default
--           only the ones not yet completed
-- With both on, a dungeon must satisfy both.
--
-- Legacy challenges are the game's achievements (account-wide). A challenge
-- set is found by what it lists, not by its name, so any client language
-- whose instance names match will work.

local ADDON, ns = ...

local Auto = {}
ns.Auto = Auto

local READ_DELAY = 6          -- seconds after login before the first read
local REREAD_GAP = 5          -- at most one re-read in this many seconds
local MIN_PHRASE = 6          -- letters a name needs to be found inside a longer line

local picked = {}             -- key -> true
local pendingRead, pendingRecompute = false, false
local lastRead = 0
local readOnce = false

local function InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

--------------------------------------------------------------------------
-- Answers
--------------------------------------------------------------------------
function Auto.IsPicked(key)
    return picked[key] == true
end

function Auto.IsWatched(key)
    if ns.cdb and ns.cdb.watched[key] then return true end
    return picked[key] == true
end

function Auto.Level()
    if type(UnitLevel) ~= "function" then return nil end
    local ok, level = pcall(UnitLevel, "player")
    if ok and ns.Readable(level) and type(level) == "number" and level > 0 then return level end
    return nil
end

-- The challenge sets ticked on this character that the last reading knows.
local function TickedSets()
    local out = {}
    for id, on in pairs(ns.cdb.autoLegacy) do
        local set = on and ns.db.legacy.sets[id]
        if type(set) == "table" and type(set.items) == "table" then out[#out + 1] = set end
    end
    return out
end

-- Work out the picked set again and rebuild the matcher.
function Auto.Recompute(level)
    picked = {}
    local db, cdb = ns.db, ns.cdb
    if db and cdb then
        level = level or Auto.Level()
        local levelOn = cdb.autoLevel
        local sets = TickedSets()
        local legacyOn = #sets > 0
        if levelOn or legacyOn then
            for key, inst in pairs(db.instances) do
                local ok = type(inst) == "table"
                if ok and levelOn then
                    ok = level ~= nil and type(inst.min) == "number" and type(inst.max) == "number"
                        and inst.min <= level and level <= inst.max
                end
                if ok and legacyOn then
                    ok = false
                    for _, set in ipairs(sets) do
                        local done = set.items[key]
                        if done ~= nil and (cdb.legacyIncludeDone or not done) then ok = true end
                    end
                end
                if ok then picked[key] = true end
            end
        end
    end
    if ns.Match then ns.Match.Rebuild() end
end

--------------------------------------------------------------------------
-- Reading the Legacy challenges
--------------------------------------------------------------------------
local function HaveAchievementAPI()
    return type(GetCategoryList) == "function" and type(GetCategoryNumAchievements) == "function"
        and type(GetAchievementInfo) == "function" and type(GetAchievementNumCriteria) == "function"
        and type(GetAchievementCriteriaInfo) == "function"
end

-- needle (" deadmines ") -> key, for every name an instance goes by
local function NameIndex()
    local index, phrases = {}, {}
    local function Put(name, key)
        local needle = ns.Match.Normalize(name)
        if needle == " " then return end
        if index[needle] == nil then
            index[needle] = key
            if #needle - 2 >= MIN_PHRASE then phrases[#phrases + 1] = needle end
        end
    end
    for key, inst in pairs(ns.db.instances) do
        if type(inst) == "table" and type(inst.name) == "string" then
            Put(inst.name, key)
            local short = inst.name:lower():match("^the%s+(.+)$")
            if short then Put(short, key) end
            for _, other in ipairs(ns.Data.LEGACY_NAMES[inst.name] or {}) do Put(other, key) end
        end
    end
    return index, phrases
end

-- The instances one criterion names: usually one, two for "X or Y".
local function KeysNamed(text, index, phrases)
    local norm = ns.Match.Normalize(text)
    local hit = index[norm] or index[(norm:gsub("^ the ", " "))]
    if hit then return { hit } end
    local keys, seen = {}, {}
    for _, needle in ipairs(phrases) do
        if norm:find(needle, 1, true) then
            local key = index[needle]
            if not seen[key] then
                seen[key] = true
                keys[#keys + 1] = key
            end
        end
    end
    return keys
end

-- One achievement as a challenge set, or nil when it is not one.
local function ReadSet(id, title, index, phrases)
    local okN, count = pcall(GetAchievementNumCriteria, id)
    if not okN or not ns.Readable(count) or type(count) ~= "number" or count < 3 then return nil end
    local items, naming = {}, 0
    for j = 1, count do
        local okC, text, _, done = pcall(GetAchievementCriteriaInfo, id, j)
        if okC and ns.Readable(text) and type(text) == "string" and ns.Readable(done) then
            local keys = KeysNamed(text, index, phrases)
            if #keys > 0 then naming = naming + 1 end
            for _, key in ipairs(keys) do
                -- a dungeon listed twice counts as done if either line is
                items[key] = (items[key] == true) or (done and true or false)
            end
        end
    end
    if naming < 3 or naming * 2 <= count then return nil end
    local total, finished = 0, 0
    for _, done in pairs(items) do
        total = total + 1
        if done then finished = finished + 1 end
    end
    if not (ns.Readable(title) and type(title) == "string") then title = "Challenge " .. tostring(id) end
    return { title = title, items = items, total = total, done = finished }
end

-- Read the challenge sets. full = look through every achievement; otherwise
-- only the sets already known are read again. Returns true when it ran.
function Auto.ReadLegacy(full)
    if not (ns.db and ns.cdb) then return false end
    if not HaveAchievementAPI() then return false end
    if InCombat() then
        pendingRead = true
        return false
    end
    lastRead = GetTime()
    readOnce = true

    local index, phrases = NameIndex()
    local sets = {}

    if not full and next(ns.db.legacy.sets) ~= nil then
        for id in pairs(ns.db.legacy.sets) do
            local number = tonumber(id)
            if number then
                local okA, _, title = pcall(GetAchievementInfo, number)
                local set = okA and ReadSet(number, title, index, phrases)
                if set then sets[id] = set end
            end
        end
    else
        local okL, categories = pcall(GetCategoryList)
        if not okL or type(categories) ~= "table" then return false end
        for _, category in ipairs(categories) do
            local okC, n = pcall(GetCategoryNumAchievements, category, true)
            n = (okC and ns.Readable(n) and tonumber(n)) or 0
            for i = 1, n do
                local okA, id, title = pcall(GetAchievementInfo, category, i)
                if okA and ns.Readable(id) and type(id) == "number" then
                    local set = ReadSet(id, title, index, phrases)
                    if set then sets[tostring(id)] = set end
                end
            end
        end
    end

    -- a reading that found nothing keeps the last good one
    if next(sets) ~= nil then
        ns.db.legacy.sets = sets
        ns.db.legacy.time = date("%Y-%m-%d %H:%M:%S")
    end
    Auto.Recompute()
    return true
end

-- { { id, title, done, total }, ... } lowest-level set first.
function Auto.Sets()
    local out = {}
    for id, set in pairs(ns.db.legacy.sets) do
        if type(set) == "table" and type(set.items) == "table" then
            local lowest = 999
            for key in pairs(set.items) do
                local inst = ns.db.instances[key]
                if type(inst) == "table" and type(inst.min) == "number" and inst.min < lowest then
                    lowest = inst.min
                end
            end
            out[#out + 1] = {
                id = id,
                title = tostring(set.title or id),
                done = tonumber(set.done) or 0,
                total = tonumber(set.total) or 0,
                lowest = lowest,
            }
        end
    end
    table.sort(out, function(a, b)
        if a.lowest ~= b.lowest then return a.lowest < b.lowest end
        return a.title < b.title
    end)
    return out
end

-- True once a reading has been tried this session.
function Auto.HasRead()
    return readOnce
end

function Auto.PrintLegacy()
    if not HaveAchievementAPI() then
        ns.Print("this client has no achievement functions; Legacy cannot be read.")
        return
    end
    if not InCombat() then Auto.ReadLegacy(true) end
    local sets = Auto.Sets()
    if #sets == 0 then
        ns.Print("no Legacy challenge that lists dungeons was found.")
        return
    end
    for _, s in ipairs(sets) do
        ns.Print(s.title .. ": " .. s.done .. " of " .. s.total .. " done.")
        local names = {}
        for key, done in pairs(ns.db.legacy.sets[s.id].items) do
            local inst = ns.db.instances[key]
            if inst then
                names[#names + 1] = (done and "|cff808080" or "|cffffffff") .. inst.name .. "|r"
            end
        end
        table.sort(names)
        ns.Print("  " .. table.concat(names, ", "))
    end
    ns.Print("white = not yet done, grey = done.")
end

function Auto.Snapshot()
    local count = 0
    for _ in pairs(picked) do count = count + 1 end
    local sets = {}
    for _, s in ipairs(Auto.Sets()) do
        sets[#sets + 1] = s.title .. " " .. s.done .. "/" .. s.total
            .. (ns.cdb.autoLegacy[s.id] and " (ticked)" or "")
    end
    return {
        level = Auto.Level(),
        autoLevel = ns.cdb.autoLevel,
        includeDone = ns.cdb.legacyIncludeDone,
        picked = count,
        sets = sets,
        read = ns.db.legacy.time,
    }
end

--------------------------------------------------------------------------
-- Keeping up to date
--------------------------------------------------------------------------
local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LEVEL_UP", "CRITERIA_UPDATE", "ACHIEVEMENT_EARNED", "PLAYER_REGEN_ENABLED" }) do
    pcall(frame.RegisterEvent, frame, event)
end

local rereadQueued = false
local function QueueReread()
    if rereadQueued then return end
    rereadQueued = true
    local wait = math.max(0.5, REREAD_GAP - (GetTime() - lastRead))
    C_Timer.After(wait, function()
        rereadQueued = false
        if InCombat() then
            pendingRead = true
        else
            Auto.ReadLegacy(false)
        end
    end)
end

frame:SetScript("OnEvent", function(_, event, arg1)
    if not (ns.db and ns.cdb) then return end
    if event == "PLAYER_LEVEL_UP" then
        -- the new level arrives with the event; UnitLevel may still be the old one
        local level = (ns.Readable(arg1) and type(arg1) == "number") and arg1 or nil
        if InCombat() then
            pendingRecompute = true
        else
            Auto.Recompute(level)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingRead then
            pendingRead, pendingRecompute = false, false
            Auto.ReadLegacy(not readOnce)
        elseif pendingRecompute then
            pendingRecompute = false
            Auto.Recompute()
        end
    elseif readOnce then
        -- a challenge moved on
        QueueReread()
    end
end)

ns.OnLogin(function()
    Auto.Recompute()      -- from the saved reading, so picks are right at once
    C_Timer.After(READ_DELAY, function()
        Auto.ReadLegacy(true)
    end)
end)
