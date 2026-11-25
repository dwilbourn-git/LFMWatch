-- LFMWatch chat filter: tags matching lines and feeds the pop-out list.
--
-- Probed on this client (2026-11-25):
--   * the filter is called once per chat window (ChatFrame1..10) per line
--   * after msg and author, the extra arguments are numbered from 3:
--       9 = channel name ("LocalDefense - Gnomeregan", "Community:<club>:<stream>")
--      11 = line ID (0 for community channels)
--      12 = sender GUID
--   * player names may contain a space and carry no realm suffix
--   * message and sender were readable in combat, but every value is still
--     guarded: an unreadable one means the line is left alone.

local ADDON, ns = ...

local Chat = {}
ns.Chat = Chat

-- Community channels (CHAT_MSG_COMMUNITIES_CHANNEL) are not watched: the
-- client hands addons a protected token ("|Kq1|k") in place of the text, so
-- there is nothing to match (probed 2026-11-25).
local EVENTS = { "CHAT_MSG_GUILD", "CHAT_MSG_CHANNEL" }

function Chat.IsCommunity(name)
    return type(name) == "string" and name:match("^[Cc]ommunity:%d+:%d+$") ~= nil
end
local TAG_COLOUR = "|cffffd100"
local TINT_COLOUR = "|cffffe680"
local CACHE_MAX = 50
local CACHE_WINDOW = 1      -- seconds; for lines with no line ID

local Readable = ns.Readable
local filterAdded = false

--------------------------------------------------------------------------
-- Channel names
--------------------------------------------------------------------------
-- The saved key for a channel: lower-cased, without the " - Zone" suffix
-- that zone channels carry, so it survives zoning and renumbering.
function Chat.ChannelKey(name)
    if type(name) ~= "string" or name == "" then return nil end
    local base = name:match("^(.-)%s+%-%s+.+$") or name
    return base:lower()
end

-- What to call a channel on screen. Community channels arrive as
-- "Community:<club>:<stream>"; show the community's own name instead.
function Chat.ChannelLabel(name)
    if type(name) ~= "string" then return "?" end
    local club, stream = name:match("^[Cc]ommunity:(%d+):(%d+)$")
    if club and C_Club then
        local label
        pcall(function()
            local info = C_Club.GetClubInfo and C_Club.GetClubInfo(club)
            if type(info) == "table" and Readable(info.name) and info.name ~= "" then
                label = info.name
                local s = C_Club.GetStreamInfo and C_Club.GetStreamInfo(club, stream)
                if type(s) == "table" and Readable(s.name) and s.name ~= "" then
                    label = label .. " - " .. s.name
                end
            end
        end)
        if label then return label end
    end
    return name:match("^(.-)%s+%-%s+.+$") or name
end

--------------------------------------------------------------------------
-- Rewrite
--------------------------------------------------------------------------
function Chat.Tag(instances)
    return TAG_COLOUR .. "[LFM " .. table.concat(instances, "/") .. "]|r "
end

-- The tag, then the original text tinted. Links end with "|r", which would
-- drop the tint, so it is put back after each one.
local function Rewrite(msg, instances)
    local tinted = msg:gsub("|r", "|r" .. TINT_COLOUR)
    return Chat.Tag(instances) .. TINT_COLOUR .. tinted .. "|r"
end

--------------------------------------------------------------------------
-- Per-line cache: every chat window asks about the same line
--------------------------------------------------------------------------
local cache, cacheOrder = {}, {}

local function CacheGet(key)
    local hit = cache[key]
    if hit and (hit.permanent or GetTime() - hit.time <= CACHE_WINDOW) then return hit end
    return nil
end

local function CachePut(key, permanent, newMsg)
    if cache[key] == nil then
        cacheOrder[#cacheOrder + 1] = key
        if #cacheOrder > CACHE_MAX then
            cache[table.remove(cacheOrder, 1)] = nil
        end
    end
    cache[key] = { time = GetTime(), permanent = permanent, newMsg = newMsg }
end

--------------------------------------------------------------------------
-- The filter
--------------------------------------------------------------------------
local function IsPlayer(author, guid)
    if Readable(guid) and type(guid) == "string" and guid ~= "" then
        local mine = UnitGUID("player")
        if Readable(mine) then return guid == mine end
    end
    local name = UnitName("player")
    if not Readable(name) then return false end
    return author == name or author:match("^[^-]+") == name
end

-- Returns the channel label when this line is on a watched channel.
local function WatchedChannel(event, channelName)
    if event == "CHAT_MSG_GUILD" then
        return ns.cdb.guild and "Guild" or nil
    end
    if not (Readable(channelName) and type(channelName) == "string") then return nil end
    local key = Chat.ChannelKey(channelName)
    if key and ns.cdb.channels[key] then return Chat.ChannelLabel(channelName) end
    return nil
end

local function Decide(event, msg, author, channelName, guid)
    local channel = WatchedChannel(event, channelName)
    if not channel then return nil end
    if IsPlayer(author, guid) then return nil end

    local result = ns.Match.Check(msg)
    ns.Log(channel .. ": " .. result.reason)
    if not result.matched then return nil end

    ns.List.Add({
        sender = author,
        display = author:match("^([^-]+)%-") or author,
        instances = result.instances,
        roles = result.roles,
        text = msg,
        channel = channel,
        time = GetTime(),
    })
    return Rewrite(msg, result.instances)
end

local function Filter(_, event, msg, author, ...)
    if not ns.cdb then return false end
    if not (Readable(msg) and Readable(author)) then return false end
    if type(msg) ~= "string" or type(author) ~= "string" then return false end

    local channelName, lineID, guid = select(7, ...), select(9, ...), select(10, ...)

    local key, permanent
    if Readable(lineID) and type(lineID) == "number" and lineID > 0 then
        key, permanent = event .. ":" .. lineID, true
    else
        key, permanent = event .. "\0" .. author .. "\0" .. msg, false
    end

    local hit = CacheGet(key)
    if not hit then
        local ok, newMsg = pcall(Decide, event, msg, author, channelName, guid)
        if not ok then
            ns.Log("error: " .. tostring(newMsg))
            newMsg = nil
        end
        CachePut(key, permanent, newMsg)
        hit = cache[key]
    end

    if hit.newMsg then
        return false, hit.newMsg, author, ...
    end
    return false
end

function Chat.Enable()
    if filterAdded then return end
    local add = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter) or ChatFrame_AddMessageEventFilter
    if type(add) ~= "function" then
        ns.Print("this client has no chat filter; lines cannot be marked.")
        return
    end
    filterAdded = true
    for _, event in ipairs(EVENTS) do
        pcall(add, event, Filter)
    end
end

--------------------------------------------------------------------------
-- /lfw test and /lfw debug
--------------------------------------------------------------------------
-- Run the matcher on text as if a guildmate had said it.
function Chat.Test(text)
    local result = ns.Match.Check(text)
    if not result.matched then
        ns.Print("no match (" .. result.reason .. ").")
        return
    end
    local roles = (#result.roles > 0) and table.concat(result.roles, ", ") or "no roles named"
    ns.Print("match: " .. table.concat(result.instances, "/") .. " (" .. roles .. ").")
    DEFAULT_CHAT_FRAME:AddMessage("[Test] TestSender: " .. Rewrite(text, result.instances))
    ns.List.Add({
        sender = "TestSender",
        display = "TestSender",
        instances = result.instances,
        roles = result.roles,
        text = text,
        channel = "test",
        time = GetTime(),
    })
end

function Chat.Snapshot()
    return { filterAdded = filterAdded, cached = #cacheOrder }
end

ns.OnLogin(function()
    -- community channels could be ticked in version 0.1.0; they never worked
    for key in pairs(ns.cdb.channels) do
        if Chat.IsCommunity(key) then ns.cdb.channels[key] = nil end
    end
    Chat.Enable()
end)
