-- LFMWatch seats: reads which places in a group a recruiting line is asking
-- for. No frames and no game state, so /lfw test runs the same code as chat.
--
-- A seat is { state = "open" | "filled" | "unknown", role = "tank" | "healer"
-- | "dps" | nil, class = "MAGE" | nil }.
--   open     the line asks for it
--   filled   deduced: the line asked for other things, not this
--   unknown  nothing to go on
--
-- Input is always Match.Normalize output: lower case, single spaces, no
-- punctuation. Words are compared whole against the fixed tables in Data.

local ADDON, ns = ...

local Seats = {}
ns.Seats = Seats

local MAX_COUNT = 5          -- a number above this is not a seat count
local MAX_RAID_ICONS = 6
local DUNGEON_SLOTS = { "tank", "healer", "dps", "dps", "dps" }
-- where a seat of unknown role is drawn first
local FILL_ORDER = { "dps", "tank", "healer" }
-- words a count may skip over on its way to a role: "2 more dps"
local FILLER = { more = true, a = true, an = true, x = true, good = true, of = true }

--------------------------------------------------------------------------
-- Reading the line into requests
--------------------------------------------------------------------------
-- Returns requests = { { role, class, count, filled }, ... } and total (the
-- number of places said to be open, from "LF2M" or "last spot"), or nil.
local function Read(norm)
    local D = ns.Data
    local words = {}
    for w in norm:gmatch("%S+") do words[#words + 1] = w end

    local function RoleOf(i)
        local w = words[i]
        return w and (D.ROLES[w] or D.SPEC_HINTS[w]) or nil
    end

    -- pair each class word with a neighbouring role word it can fill
    local pairedRole, taken = {}, {}
    for i, w in ipairs(words) do
        local class = D.CLASSES[w]
        if class then
            local can = D.CLASS_ROLES[class] or {}
            local nextRole, prevRole = RoleOf(i + 1), RoleOf(i - 1)
            if nextRole and can[nextRole] and not taken[i + 1] then
                pairedRole[i], taken[i + 1] = nextRole, true
            elseif prevRole and can[prevRole] and not taken[i - 1] then
                pairedRole[i], taken[i - 1] = prevRole, true
            end
        end
    end

    local requests, total = {}, nil
    local have, pending = false, nil
    for i, w in ipairs(words) do
        local lfCount = w:match("^lf(%d+)m$")
        local number = w:match("^(%d+)x?$")
        if lfCount then
            have, pending = false, nil
            local n = tonumber(lfCount)
            if n and n >= 1 and n <= MAX_COUNT then total = n end
        elseif D.HAVE_WORDS[w] then
            have, pending = true, nil
        elseif D.NEED_WORDS[w] then
            have, pending = false, nil
        elseif w == "last" and words[i + 1] == "spot" then
            have, pending, total = false, nil, 1
        elseif number then
            local n = tonumber(number)
            pending = (n and n >= 1 and n <= MAX_COUNT) and n or nil
            if pending and words[i + 1] == "more" and not have then total = pending end
        elseif D.CLASSES[w] then
            local class = D.CLASSES[w]
            local role = pairedRole[i]
            if not role and D.CLASS_ROLES[class] then
                -- a class with one possible job needs no role word
                local only, n = nil, 0
                for r in pairs(D.CLASS_ROLES[class]) do only, n = r, n + 1 end
                if n == 1 then role = only end
            end
            requests[#requests + 1] = { role = role, class = class, count = pending or 1, filled = have }
            pending = nil
        elseif D.ROLES[w] and not taken[i] then
            local full = D.FULL_WORDS[words[i + 1] or ""] and true or false
            requests[#requests + 1] = { role = D.ROLES[w], count = pending or 1, filled = have or full }
            pending = nil
        elseif not FILLER[w] and not taken[i] then
            pending = nil
        end
    end
    return requests, total
end

--------------------------------------------------------------------------
-- Building the seats
--------------------------------------------------------------------------
local function Dungeon(requests, total)
    local slots = {}                 -- index 1..5 -> seat
    local filledRole = {}            -- role -> true: the line says the group has it
    local namedOpen = {}             -- role -> true: the line asks for it
    local placed, anyFilled = 0, false

    local function FreeSlot(role)
        for i, slotRole in ipairs(DUNGEON_SLOTS) do
            if slotRole == role and not slots[i] and not filledRole[role] then return i end
        end
        return nil
    end

    for _, req in ipairs(requests) do
        if req.filled and req.role then
            filledRole[req.role], anyFilled = true, true
        elseif req.filled then
            anyFilled = true
        end
    end

    for _, req in ipairs(requests) do
        if not req.filled then
            for _ = 1, req.count do
                local slot
                if req.role then
                    slot = FreeSlot(req.role)
                else
                    for _, role in ipairs(FILL_ORDER) do
                        slot = slot or FreeSlot(role)
                    end
                end
                if not slot then break end
                slots[slot] = { state = "open", role = req.role, class = req.class }
                placed = placed + 1
            end
            if req.role then namedOpen[req.role] = true end
        end
    end

    if total and total > placed then
        local remainder = total - placed
        -- first to roles the line named that still have room
        for _, role in ipairs(FILL_ORDER) do
            while remainder > 0 and namedOpen[role] do
                local slot = FreeSlot(role)
                if not slot then break end
                slots[slot] = { state = "open", role = role }
                placed, remainder = placed + 1, remainder - 1
            end
        end
        -- then places whose role nobody stated
        for _, role in ipairs(FILL_ORDER) do
            while remainder > 0 do
                local slot = FreeSlot(role)
                if not slot then break end
                slots[slot] = { state = "unknown" }
                remainder = remainder - 1
            end
        end
    end

    local list = {}
    if #requests == 0 and not total then
        for i = 1, #DUNGEON_SLOTS do list[i] = { state = "unknown" } end
    elseif placed == 0 and total and not anyFilled then
        -- a count and nothing else: we do not know which roles are filled
        for i = 1, #DUNGEON_SLOTS do
            list[i] = (i <= total) and { state = "unknown" } or { state = "filled" }
        end
    else
        -- with only "have ..." to go on, the seats not mentioned are unknown
        local rest = (placed == 0 and not total) and "unknown" or "filled"
        for i, slotRole in ipairs(DUNGEON_SLOTS) do
            if slots[i] then
                list[i] = slots[i]
            elseif filledRole[slotRole] or rest == "filled" then
                list[i] = { state = "filled", role = slotRole }
            else
                list[i] = { state = "unknown" }
            end
        end
    end
    return list, false
end

local function Raid(requests)
    local list, more = {}, false
    local function Push(req)
        for _ = 1, req.count do
            if #list >= MAX_RAID_ICONS then
                more = true
                return
            end
            list[#list + 1] = { state = "open", role = req.role, class = req.class }
        end
    end
    for _, role in ipairs(ns.Data.ROLE_ORDER) do
        for _, req in ipairs(requests) do
            if not req.filled and not req.class and req.role == role then Push(req) end
        end
    end
    for _, req in ipairs(requests) do
        if not req.filled and req.class then Push(req) end
    end
    if #list == 0 then list[1] = { state = "unknown" } end
    return list, more
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
-- norm: Match.Normalize output. kind: "raid" or anything else for a dungeon.
-- Returns { mode, list = { seat, ... }, more = boolean, info = boolean };
-- info is true when the line named any role, class or count.
function Seats.Parse(norm, kind)
    local requests, total = {}, nil
    if type(norm) == "string" then requests, total = Read(norm) end
    local list, more
    if kind == "raid" then
        list, more = Raid(requests)
    else
        list, more = Dungeon(requests, total)
    end
    return {
        mode = (kind == "raid") and "raid" or "dungeon",
        list = list,
        more = more,
        info = (#requests > 0) or (total ~= nil),
    }
end

function Seats.Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    if a.mode ~= b.mode or a.more ~= b.more or #a.list ~= #b.list then return false end
    for i, seat in ipairs(a.list) do
        local other = b.list[i]
        if seat.state ~= other.state or seat.role ~= other.role or seat.class ~= other.class then
            return false
        end
    end
    return true
end

-- The seats in words, for /lfw test: "tank:filled healer:open mage(dps):open".
function Seats.Describe(seats)
    if type(seats) ~= "table" or type(seats.list) ~= "table" then return "none" end
    local parts = {}
    for i, seat in ipairs(seats.list) do
        local text
        if seat.state == "unknown" then
            text = "?"
        elseif seat.class then
            text = seat.class:lower() .. "(" .. (seat.role or "any") .. "):" .. seat.state
        elseif seat.role then
            text = seat.role .. ":" .. seat.state
        else
            text = "dot"
        end
        parts[i] = text
    end
    if seats.more then parts[#parts + 1] = "+" end
    return table.concat(parts, " ")
end
