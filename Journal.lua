-- LFMWatch instance list: the dungeons and raids that can be watched.
--
-- This client has no Encounter Journal to read (see Data.lua), so the list
-- is the built-in one in Data.INSTANCES plus entries added by hand in /lfw.

local ADDON, ns = ...

local Journal = {}
ns.Journal = Journal

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Key(name)
    return Trim(name):lower()
end

-- "dm, VC ,, dm" -> { "dm", "vc" }
function Journal.ParseList(text)
    local out, seen = {}, {}
    if type(text) ~= "string" then return out end
    for part in text:gmatch("[^,]+") do
        local word = Trim(part):lower()
        if word ~= "" and not seen[word] then
            seen[word] = true
            out[#out + 1] = word
        end
    end
    return out
end

local function Counts()
    local dungeons, raids = 0, 0
    for _, inst in pairs(ns.db.instances) do
        if inst.kind == "raid" then raids = raids + 1 else dungeons = dungeons + 1 end
    end
    return dungeons, raids
end

-- Add built-in entries that are missing. Existing entries keep their
-- aliases, so edits made in /lfw are never overwritten. Returns the totals.
function Journal.Scan()
    local instances = ns.db.instances
    local builtin = {}
    for _, def in ipairs(ns.Data.INSTANCES) do
        local name, kind, aliases = def[1], def[2], def[3]
        local key = Key(name)
        builtin[key] = true
        if instances[key] == nil then
            local copy = {}
            for i, a in ipairs(aliases) do copy[i] = a end
            instances[key] = { name = name, kind = kind, aliases = copy, custom = false }
        end
    end

    -- Anything that is neither built in nor hand-added is left over from
    -- version 0.1.0, which copied names from the ForeverDungeonJournal addon
    -- and picked up entries that are not dungeons ("Cozy Sleeping Bag",
    -- "Tier 0.5"). Remove them.
    for key, inst in pairs(instances) do
        if not builtin[key] and not (type(inst) == "table" and inst.custom) then
            instances[key] = nil
            ns.cdb.watched[key] = nil
        end
    end

    return Counts()
end

-- Add an instance by hand. Returns its key, or nil and the reason.
function Journal.Add(name, kind, aliasText)
    if type(name) ~= "string" or Trim(name) == "" then return nil, "Type a name first." end
    name = Trim(name)
    local key = Key(name)
    if ns.db.instances[key] then return nil, name .. " is already in the list." end
    ns.db.instances[key] = {
        name = name,
        kind = (kind == "raid") and "raid" or "dungeon",
        aliases = Journal.ParseList(aliasText),
        custom = true,
    }
    return key
end

-- Remove a hand-added instance. Built-in ones cannot be removed.
function Journal.Remove(key)
    local inst = ns.db.instances[key]
    if not inst or not inst.custom then return false end
    ns.db.instances[key] = nil
    ns.cdb.watched[key] = nil
    return true
end

function Journal.SetAliases(key, text)
    local inst = ns.db.instances[key]
    if not inst then return end
    inst.aliases = Journal.ParseList(text)
end

-- Keys of one kind ("dungeon" or "raid"), sorted by name.
function Journal.Sorted(kind)
    local keys = {}
    for key, inst in pairs(ns.db.instances) do
        if (inst.kind == "raid") == (kind == "raid") then keys[#keys + 1] = key end
    end
    table.sort(keys, function(a, b)
        return ns.db.instances[a].name < ns.db.instances[b].name
    end)
    return keys
end

ns.OnLogin(function()
    Journal.Scan()
    if ns.Match then ns.Match.Rebuild() end
end)
