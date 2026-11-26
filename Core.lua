-- LFMWatch core: saved variables, the secret-value guard, events and commands.

local ADDON, ns = ...

local LOG_SIZE = 20
local EXPIRY_MIN, EXPIRY_MAX, EXPIRY_DEFAULT = 1, 15, 5

--------------------------------------------------------------------------
-- Output
--------------------------------------------------------------------------
function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd100LFMWatch:|r " .. tostring(text))
end

-- The last few match decisions, kept in memory for /lfw debug.
local log = {}
function ns.Log(text)
    log[#log + 1] = date("%H:%M:%S") .. " " .. tostring(text)
    if #log > LOG_SIZE then table.remove(log, 1) end
end

--------------------------------------------------------------------------
-- Listeners: another addon may ask to be told about each line LFMWatch
-- judges, with LFMWatchAPI.OnLine(function(info) ... end). info holds
-- channel, author, text, outcome, reason, instances, seats and test.
-- LFMWatch itself keeps none of it.
--------------------------------------------------------------------------
local listeners = {}

function ns.Notify(info)
    for _, fn in ipairs(listeners) do pcall(fn, info) end
end

LFMWatchAPI = {
    OnLine = function(fn)
        if type(fn) == "function" then listeners[#listeners + 1] = fn end
    end,
}

--------------------------------------------------------------------------
-- Secret values: never compare, join or pattern-match a chat value before
-- this says it is readable.
--------------------------------------------------------------------------
local issecret = issecretvalue
function ns.Readable(v)
    if v == nil then return false end
    if issecret then
        local ok, secret = pcall(issecret, v)
        if not ok or secret then return false end
    end
    return true
end

--------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------
local function CopyList(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = v end
    return out
end

local function CopyMap(map)
    local out = {}
    for k, v in pairs(map or {}) do out[k] = v end
    return out
end

function ns.ClampExpiry(n)
    n = tonumber(n) or EXPIRY_DEFAULT
    n = math.floor(n + 0.5)
    if n < EXPIRY_MIN then n = EXPIRY_MIN end
    if n > EXPIRY_MAX then n = EXPIRY_MAX end
    return n
end

local function InitDB()
    if type(LFMWatchDB) ~= "table" then LFMWatchDB = {} end
    if type(LFMWatchCharDB) ~= "table" then LFMWatchCharDB = {} end
    local db, cdb = LFMWatchDB, LFMWatchCharDB

    if type(db.instances) ~= "table" then db.instances = {} end
    -- copied once, so later edits in /lfw survive addon updates
    if type(db.triggers) ~= "table" then db.triggers = CopyList(ns.Data.TRIGGERS) end
    if type(db.ignore) ~= "table" then db.ignore = CopyList(ns.Data.IGNORE) end
    if type(db.includeLFG) ~= "boolean" then db.includeLFG = false end
    db.expiryMinutes = ns.ClampExpiry(db.expiryMinutes)
    if db.timeDisplay ~= "time" and db.timeDisplay ~= "both" then db.timeDisplay = "bar" end
    if db.sort ~= "level" then db.sort = "name" end
    -- the last reading of the Legacy challenges; they are account-wide
    if type(db.legacy) ~= "table" then db.legacy = {} end
    if type(db.legacy.sets) ~= "table" then db.legacy.sets = {} end

    if type(cdb.guild) ~= "boolean" then cdb.guild = false end
    if type(cdb.channels) ~= "table" then cdb.channels = {} end
    if type(cdb.watched) ~= "table" then cdb.watched = {} end
    if type(cdb.autoShow) ~= "boolean" then cdb.autoShow = true end
    if type(cdb.autoLevel) ~= "boolean" then cdb.autoLevel = false end
    if type(cdb.autoLegacy) ~= "table" then cdb.autoLegacy = {} end
    if type(cdb.legacyIncludeDone) ~= "boolean" then cdb.legacyIncludeDone = false end

    ns.db, ns.cdb = db, cdb
end

--------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------
local loginCallbacks = {}
local loggedIn = false

-- Run fn at PLAYER_LOGIN (or now, if that has already happened).
function ns.OnLogin(fn)
    if loggedIn then
        fn()
    else
        loginCallbacks[#loginCallbacks + 1] = fn
    end
end

local function RunSafely(fn)
    local ok, err = pcall(fn)
    if not ok then
        local handler = geterrorhandler and geterrorhandler()
        if handler then handler(err) end
    end
end

local frame = CreateFrame("Frame")
pcall(frame.RegisterEvent, frame, "ADDON_LOADED")
pcall(frame.RegisterEvent, frame, "PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then InitDB() end
    elseif event == "PLAYER_LOGIN" then
        if not ns.db then InitDB() end
        loggedIn = true
        for _, fn in ipairs(loginCallbacks) do RunSafely(fn) end
        loginCallbacks = {}
    end
end)

--------------------------------------------------------------------------
-- Debug snapshot: written to saved variables so it can be read from disk
-- after /reload.
--------------------------------------------------------------------------
local function Snapshot()
    local count = 0
    for _ in pairs(ns.db.instances) do count = count + 1 end
    ns.cdb.snapshot = {
        time = date("%Y-%m-%d %H:%M:%S"),
        inCombat = InCombatLockdown() and true or false,
        guild = ns.cdb.guild,
        channels = CopyMap(ns.cdb.channels),
        watched = CopyMap(ns.cdb.watched),
        autoShow = ns.cdb.autoShow,
        includeLFG = ns.db.includeLFG,
        expiryMinutes = ns.db.expiryMinutes,
        triggers = CopyList(ns.db.triggers),
        ignore = CopyList(ns.db.ignore),
        instanceCount = count,
        rows = ns.List and ns.List.Snapshot and ns.List.Snapshot() or nil,
        auto = ns.Auto and ns.Auto.Snapshot and ns.Auto.Snapshot() or nil,
        timeDisplay = ns.db.timeDisplay,
        sort = ns.db.sort,
        chat = ns.Chat and ns.Chat.Snapshot and ns.Chat.Snapshot() or nil,
        log = CopyList(log),
    }
end

--------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------
local function Help()
    ns.Print("commands:")
    ns.Print("  /lfw - open settings")
    ns.Print("  /lfw list - show or hide the list")
    ns.Print("  /lfw test <text> - try a message against your settings")
    ns.Print("  /lfw clear - empty the list")
    ns.Print("  /lfw legacy - show what was read from your Legacy challenges")
    ns.Print("  /lfw rescan - put back any built-in dungeons and raids that are missing")
    ns.Print("  /lfw debug - save a state snapshot (then /reload)")
end

-- Call ns[module][fn](...) when it exists; say so when it does not.
local function Call(module, fn, ...)
    local m = ns[module]
    if type(m) == "table" and type(m[fn]) == "function" then
        return true, m[fn](...)
    end
    ns.Print("that part of the addon did not load.")
    return false
end

SLASH_LFMWATCH1 = "/lfw"
SLASH_LFMWATCH2 = "/lfmwatch"
SlashCmdList["LFMWATCH"] = function(text)
    if not ns.db then return end
    text = text or ""
    local cmd, rest = text:match("^%s*(%S*)%s*(.-)%s*$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        Call("Options", "Toggle")
    elseif cmd == "list" then
        Call("List", "Toggle")
    elseif cmd == "test" then
        if rest == "" then
            ns.Print("usage: /lfw test LF1M healer DM")
        else
            Call("Chat", "Test", rest)
        end
    elseif cmd == "clear" then
        if Call("List", "Clear") then ns.Print("list emptied.") end
    elseif cmd == "rescan" then
        local ok, dungeons, raids = Call("Journal", "Scan")
        if ok then
            ns.Print("list restored: " .. tostring(dungeons) .. " dungeons, " .. tostring(raids) .. " raids.")
            if ns.Auto then
                ns.Auto.Recompute()
            elseif ns.Match then
                ns.Match.Rebuild()
            end
        end
    elseif cmd == "legacy" then
        Call("Auto", "PrintLegacy")
    elseif cmd == "debug" then
        Snapshot()
        ns.Print("snapshot saved. /reload to write it to disk.")
    else
        Help()
    end
end
