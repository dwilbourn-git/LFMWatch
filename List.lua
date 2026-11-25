-- LFMWatch pop-out: one row per person currently recruiting. A plain frame
-- with no secure children, so it may show, hide and update in combat.

local ADDON, ns = ...

local List = {}
ns.List = List

local MAX_ROWS = 8
local ROW_HEIGHT = 18
local TITLE_HEIGHT = 24
local WIDTH = 400
local PAD = 8

local rows = {}            -- sender -> entry
local order = {}           -- entries, newest first
local frame, rowFrames, emptyText
local ticker
local closedByHand = false

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function Count()
    local n = 0
    for _ in pairs(rows) do n = n + 1 end
    return n
end

local function AgeText(seconds)
    if seconds < 0 then seconds = 0 end
    seconds = math.floor(seconds)
    return string.format("%d:%02d ago", math.floor(seconds / 60), seconds % 60)
end

local function ExpirySeconds()
    return ((ns.db and ns.db.expiryMinutes) or 5) * 60
end

-- Put a whisper to this player in the chat box. Never sends anything.
-- UNSETTLED: the probe could not confirm that SendTell opens a whisper on
-- this client (it was only tried against the player's own character). If
-- in-game check 4.4 shows nothing opens, this is the function to change.
-- A typed "/w name" is not used as a fallback: names here can contain a
-- space, which a slash command would cut short.
local function Whisper(name)
    local send = (ChatFrameUtil and ChatFrameUtil.SendTell) or ChatFrame_SendTell
    if type(send) ~= "function" then
        ns.Print("this client has no way to open a whisper from an addon.")
        return
    end
    local ok, err = pcall(send, name)
    if not ok then
        ns.Print("could not open a whisper to " .. name .. ".")
        ns.Log("whisper error: " .. tostring(err))
    end
end

--------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------
local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint(1)
    if point then
        ns.cdb.pos = { point = point, relPoint = relPoint or point, x = x or 0, y = y or 0 }
    end
end

local function RestorePosition()
    frame:ClearAllPoints()
    local pos = ns.cdb and ns.cdb.pos
    if type(pos) == "table" and type(pos.point) == "string" then
        frame:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 60)
    end
end

local function Edge(parent, r, g, b, a)
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(r, g, b, a)
    return t
end

local Refresh   -- defined below

local function CreateRow(index)
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_HEIGHT + (index - 1) * ROW_HEIGHT))
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_HEIGHT + (index - 1) * ROW_HEIGHT))
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.82, 0, 0.15)

    local function Column(width, justify)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetWidth(width)
        fs:SetJustifyH(justify)
        if fs.SetWordWrap then fs:SetWordWrap(false) end
        return fs
    end
    row.name = Column(104, "LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.instance = Column(136, "LEFT")
    row.instance:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.roles = Column(72, "LEFT")
    row.roles:SetPoint("LEFT", row.instance, "RIGHT", 6, 0)
    row.age = Column(56, "RIGHT")
    row.age:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.name:SetTextColor(1, 0.82, 0)
    row.age:SetTextColor(0.7, 0.7, 0.7)

    row:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(e.display)
        GameTooltip:AddLine(e.channel, 0.7, 0.7, 0.7)
        GameTooltip:AddLine(e.text, 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click: whisper   Right-click: remove", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row:SetScript("OnClick", function(self, button)
        local e = self.entry
        if not e then return end
        if button == "RightButton" then
            GameTooltip:Hide()
            List.Remove(e.sender)
        else
            Whisper(e.sender)
        end
    end)
    return row
end

local function EnsureFrame()
    if frame then return end
    frame = CreateFrame("Frame", "LFMWatchListFrame", UIParent)
    frame:SetWidth(WIDTH)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    local top, bottom = Edge(frame, 1, 0.82, 0, 0.9), Edge(frame, 1, 0.82, 0, 0.9)
    local left, right = Edge(frame, 1, 0.82, 0, 0.9), Edge(frame, 1, 0.82, 0, 0.9)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(1)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -6)
    title:SetText("Looking for group")

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(18, 18)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -3)
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    x:SetAllPoints()
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() x:SetTextColor(1, 0.82, 0) end)
    close:SetScript("OnClick", function()
        closedByHand = true
        frame:Hide()
    end)

    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TITLE_HEIGHT - 2)
    emptyText:SetText("No one is recruiting right now.")

    rowFrames = {}
    for i = 1, MAX_ROWS do rowFrames[i] = CreateRow(i) end

    RestorePosition()
    frame:Hide()
end

--------------------------------------------------------------------------
-- Drawing and expiry
--------------------------------------------------------------------------
Refresh = function()
    if not frame then return end
    order = {}
    for _, e in pairs(rows) do order[#order + 1] = e end
    table.sort(order, function(a, b) return a.time > b.time end)

    local now = GetTime()
    local shown = math.min(#order, MAX_ROWS)
    for i = 1, MAX_ROWS do
        local row, e = rowFrames[i], order[i]
        if e then
            row.entry = e
            row.name:SetText(e.display)
            row.instance:SetText(table.concat(e.instances, "/"))
            row.roles:SetText(table.concat(e.roles, ", "))
            row.age:SetText(AgeText(now - e.time))
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    emptyText:SetShown(shown == 0)
    frame:SetHeight(TITLE_HEIGHT + math.max(shown, 1) * ROW_HEIGHT + 6)
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function Tick()
    local now, limit = GetTime(), ExpirySeconds()
    local removed = false
    for sender, e in pairs(rows) do
        if now - e.time >= limit then
            rows[sender] = nil
            removed = true
        end
    end
    if Count() == 0 then
        StopTicker()
        closedByHand = false
        if frame then
            Refresh()
            frame:Hide()
        end
        return
    end
    if frame and frame:IsShown() then
        if removed then
            Refresh()
        else
            for i = 1, MAX_ROWS do
                local row = rowFrames[i]
                if row.entry then row.age:SetText(AgeText(now - row.entry.time)) end
            end
        end
    end
end

local function StartTicker()
    if not ticker then ticker = C_Timer.NewTicker(1, Tick) end
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
-- entry = { sender, display, instances = {..}, roles = {..}, text, channel, time }
function List.Add(entry)
    if type(entry) ~= "table" or type(entry.sender) ~= "string" then return end
    entry.display = entry.display or entry.sender
    entry.instances = entry.instances or {}
    entry.roles = entry.roles or {}
    entry.text = entry.text or ""
    entry.channel = entry.channel or ""
    entry.time = entry.time or GetTime()

    local isNew = rows[entry.sender] == nil
    rows[entry.sender] = entry
    EnsureFrame()
    -- a repeat from someone already listed does not re-open a closed list
    if ns.cdb.autoShow and (isNew or not closedByHand) then
        closedByHand = false
        frame:Show()
    end
    Refresh()
    StartTicker()
end

function List.Remove(sender)
    if rows[sender] == nil then return end
    rows[sender] = nil
    if Count() == 0 then
        StopTicker()
        closedByHand = false
        if frame then
            Refresh()
            frame:Hide()
        end
    else
        Refresh()
    end
end

function List.Toggle()
    EnsureFrame()
    if frame:IsShown() then
        closedByHand = true
        frame:Hide()
    else
        closedByHand = false
        Refresh()
        frame:Show()
    end
end

function List.Count()
    return Count()
end

-- For /lfw debug. Message text is left out on purpose.
function List.Snapshot()
    local out, now = {}, GetTime()
    for _, e in pairs(rows) do
        out[#out + 1] = {
            display = e.display,
            instances = table.concat(e.instances, "/"),
            roles = table.concat(e.roles, ", "),
            channel = e.channel,
            age = math.floor(now - e.time),
        }
    end
    return { shown = frame and frame:IsShown() or false, closedByHand = closedByHand, rows = out }
end
