-- LFMWatch matcher: decides whether a message is someone recruiting for a
-- watched dungeon or raid. No frames and no game state beyond ns.db / ns.cdb,
-- so /lfw test runs exactly the code real messages use.
--
-- Every word list entry is normalised to " word " (or " several words ") and
-- found as plain text in the normalised message, which also starts and ends
-- with a space. That gives whole-word and whole-phrase matching with no Lua
-- patterns built from user input.

local ADDON, ns = ...

local Match = {}
ns.Match = Match

local MAX_INSTANCES = 2

-- ASCII control characters, spaces and punctuation. Bytes above 127 are kept
-- so non-English letters stay part of their word.
local SEPARATORS = "[%z\1-\47\58-\64\91-\96\123-\127]+"

function Match.Normalize(text)
    if type(text) ~= "string" then return " " end
    local s = text
    s = s:gsub("|c%x%x%x%x%x%x%x%x", " ")   -- colour start
    s = s:gsub("|cn[^:|]*:", " ")           -- named colour start
    s = s:gsub("|H.-|h", " ")               -- hyperlink data
    s = s:gsub("|T.-|t", " ")               -- texture
    s = s:gsub("|A.-|a", " ")               -- atlas
    s = s:gsub("|[rRhHnN]", " ")            -- colour end, link end, newline
    s = s:gsub("{[^{}]*}", " ")             -- raid icon tokens such as {star}
    s = s:lower()
    s = s:gsub(SEPARATORS, " ")
    s = s:gsub("^ +", "")
    s = s:gsub(" +$", "")
    if s == "" then return " " end
    return " " .. s .. " "
end

-- needle: a normalised word list entry, or nil when it is empty
local function Needle(word)
    local n = Match.Normalize(word)
    if n == " " then return nil end
    return n
end

function Match.HasWord(norm, word)
    local needle = Needle(word)
    if not needle then return false end
    return norm:find(needle, 1, true) ~= nil
end

--------------------------------------------------------------------------
-- Lookup lists, rebuilt whenever settings change
--------------------------------------------------------------------------
local built = false
local instances = {}   -- { { name = "Deadmines", needles = { " deadmines ", " dm " } }, ... }
local triggers = {}    -- { " lfm ", ... }
local ignores = {}     -- { { word = "wts", needle = " wts " }, ... }
local roles = {}       -- { { role = "tank", needle = " tank " }, ... }

local function AddNeedle(list, seen, word)
    local needle = Needle(word)
    if needle and not seen[needle] then
        seen[needle] = true
        list[#list + 1] = needle
    end
end

function Match.Rebuild()
    instances, triggers, ignores, roles = {}, {}, {}, {}
    local db, cdb = ns.db, ns.cdb
    if not (db and cdb) then return end

    for key, on in pairs(cdb.watched) do
        local inst = on and db.instances[key]
        if type(inst) == "table" and type(inst.name) == "string" then
            local needles, seen = {}, {}
            AddNeedle(needles, seen, inst.name)
            -- "The Deadmines" is also written "Deadmines"
            local short = inst.name:lower():match("^the%s+(.+)$")
            if short then AddNeedle(needles, seen, short) end
            for _, alias in ipairs(inst.aliases or {}) do
                AddNeedle(needles, seen, alias)
            end
            if #needles > 0 then
                instances[#instances + 1] = {
                    name = inst.name,
                    needles = needles,
                    -- wings share the part before ": " ("Scarlet Monastery: Library")
                    group = inst.name:match("^(.-):%s") or inst.name,
                }
            end
        end
    end
    table.sort(instances, function(a, b) return a.name < b.name end)

    local seen = {}
    for _, word in ipairs(db.triggers or {}) do AddNeedle(triggers, seen, word) end
    if db.includeLFG then
        for _, word in ipairs(ns.Data.LFG_TRIGGERS) do AddNeedle(triggers, seen, word) end
    end

    for _, word in ipairs(db.ignore or {}) do
        local needle = Needle(word)
        if needle then ignores[#ignores + 1] = { word = word, needle = needle } end
    end

    for word, role in pairs(ns.Data.ROLES) do
        local needle = Needle(word)
        if needle then roles[#roles + 1] = { role = role, needle = needle } end
    end

    built = true
end

--------------------------------------------------------------------------
-- The decision
--------------------------------------------------------------------------
local function Result(matched, reason, names, roleList)
    return { matched = matched, reason = reason, instances = names or {}, roles = roleList or {} }
end

-- text: the raw message. Returns
-- { matched = boolean, reason = string, instances = { name, ... }, roles = { role, ... } }
-- reason is "ok", "no watched instance", "no trigger" or "ignore word: <word>".
function Match.Check(text)
    if not built then Match.Rebuild() end
    local norm = Match.Normalize(text)

    for _, ig in ipairs(ignores) do
        if norm:find(ig.needle, 1, true) then
            return Result(false, "ignore word: " .. ig.word)
        end
    end

    -- Each watched instance scores the length of its longest matching word.
    -- Within a group of wings only the best score counts, so "sm lib" names
    -- the Library alone, while a bare "sm" (a tie across every watched wing)
    -- is reported as "Scarlet Monastery".
    local groups, groupOrder = {}, {}
    for _, inst in ipairs(instances) do
        local best = 0
        for _, needle in ipairs(inst.needles) do
            if #needle > best and norm:find(needle, 1, true) then best = #needle end
        end
        if best > 0 then
            local g = groups[inst.group]
            if not g then
                g = { best = 0, names = {} }
                groups[inst.group] = g
                groupOrder[#groupOrder + 1] = inst.group
            end
            if best > g.best then
                g.best, g.names = best, { inst.name }
            elseif best == g.best then
                g.names[#g.names + 1] = inst.name
            end
        end
    end
    local names = {}
    for _, group in ipairs(groupOrder) do
        local g = groups[group]
        names[#names + 1] = (#g.names > 1) and group or g.names[1]
    end
    table.sort(names)
    for i = #names, MAX_INSTANCES + 1, -1 do names[i] = nil end
    if #names == 0 then return Result(false, "no watched instance") end

    local triggered = false
    for _, needle in ipairs(triggers) do
        if norm:find(needle, 1, true) then
            triggered = true
            break
        end
    end
    if not triggered then return Result(false, "no trigger", names) end

    local found, roleList = {}, {}
    for _, r in ipairs(roles) do
        if norm:find(r.needle, 1, true) then found[r.role] = true end
    end
    for _, role in ipairs(ns.Data.ROLE_ORDER) do
        if found[role] then roleList[#roleList + 1] = role end
    end

    return Result(true, "ok", names, roleList)
end

ns.OnLogin(Match.Rebuild)
