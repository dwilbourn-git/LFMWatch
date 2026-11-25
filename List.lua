-- LFMWatch pop-out: one row per person currently recruiting. A plain frame
-- with no secure children, so it may show, hide and update in combat.
--
-- A request is identified by who sent it (entry.key: the sender's GUID, or
-- the name when there is none), never by channel. A later line from the same
-- person updates their row in place. Rows stay in the order they first
-- appeared, so a row never moves under the mouse.

local ADDON, ns = ...

local List = {}
ns.List = List

local Style = ns.Style
local C = Style.COLORS

local MAX_ROWS = 8
local ROW_HEIGHT = 22
local TITLE_HEIGHT = 30
local WIDTH = 380
local PAD = 10
local NAME_WIDTH = 96
local SEAT_SIZE = 16
local SEAT_STEP = 18
local MAX_SEATS = 6
local SEAT_COLUMN = MAX_SEATS * SEAT_STEP + 10   -- room for the "+"
local ROW_WIDTH = WIDTH - 2 * PAD
local FULL_SECONDS = 60       -- how long a "Group Full" row stays
local FLASH_SECONDS = 0.6
local FLASH_ALPHA = 0.35

local rows = {}            -- key -> entry
local order = {}           -- keys, oldest first
local offset = 0           -- rows scrolled past
local frame, rowFrames, emptyText, moreText, titleCount
local ticker
local closedByHand = false

--------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------
local function ExpirySeconds()
    return ((ns.db and ns.db.expiryMinutes) or 5) * 60
end

local function Lifetime(e)
    return e.full and FULL_SECONDS or ExpirySeconds()
end

local function StartedAt(e)
    return e.full and (e.fullAt or e.time) or e.time
end

local function SameNames(a, b)
    if #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- The sender's class colour, when the client will say what class they are.
local function ClassColour(guid)
    if not (ns.Readable(guid) and type(guid) == "string" and guid ~= "") then return nil end
    if type(GetPlayerInfoByGUID) ~= "function" then return nil end
    local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
    if not ok or not ns.Readable(class) or type(class) ~= "string" then return nil end
    local r, g, b = Style.ClassColor(class)
    if r then return { r, g, b } end
    return nil
end

-- Put a whisper to this player in the chat box. Never sends anything.
-- UNSETTLED: the probe could not confirm that SendTell opens a whisper on
-- this client (it was only tried against the player's own character). If
-- an in-game check shows nothing opens, this is the function to change.
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

local Refresh   -- defined below

local function FlashUpdate(self)
    local e = self.entry
    local age = e and e.flashAt and (GetTime() - e.flashAt) or FLASH_SECONDS
    if age >= FLASH_SECONDS then
        self.flash:SetAlpha(0)
        self:SetScript("OnUpdate", nil)
    else
        self.flash:SetAlpha(FLASH_ALPHA * (1 - age / FLASH_SECONDS))
    end
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, frame)
    row:SetHeight(ROW_HEIGHT)
    local top = -(TITLE_HEIGHT + (index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, top)
    row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, top)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], 0.10)

    row.flash = row:CreateTexture(nil, "BACKGROUND")
    row.flash:SetAllPoints()
    row.flash:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], 1)
    row.flash:SetAlpha(0)

    row.name = Style.DataText(row, 14, C.text)
    row.name:SetPoint("LEFT", row, "LEFT", 2, 1)
    row.name:SetWidth(NAME_WIDTH)
    row.name:SetJustifyH("LEFT")
    if row.name.SetWordWrap then row.name:SetWordWrap(false) end

    row.instance = Style.DataText(row, 13, C.text)
    row.instance:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.instance:SetPoint("RIGHT", row, "RIGHT", -(SEAT_COLUMN + 6), 1)
    row.instance:SetJustifyH("LEFT")
    if row.instance.SetWordWrap then row.instance:SetWordWrap(false) end

    row.seats = {}
    for i = 1, MAX_SEATS do
        local icon = Style.SeatIcon(row, SEAT_SIZE)
        icon:SetPoint("LEFT", row, "RIGHT", -SEAT_COLUMN + (i - 1) * SEAT_STEP, 1)
        row.seats[i] = icon
    end
    row.more = Style.DataText(row, 13, C.dim)
    row.more:SetPoint("LEFT", row, "RIGHT", -SEAT_COLUMN + MAX_SEATS * SEAT_STEP, 1)
    row.more:SetText("+")

    -- time left: a thin bar that drains to nothing
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 1)
    row.bar:SetHeight(2)
    row.bar:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.9)

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
            List.Remove(e.key)
        else
            Whisper(e.sender)
        end
    end)
    return row
end

local function MaxOffset()
    return math.max(0, #order - MAX_ROWS)
end

local function EnsureFrame()
    if frame then return end
    local ok, made = pcall(CreateFrame, "Frame", "LFMWatchListFrame", UIParent, "BackdropTemplate")
    frame = (ok and made) or CreateFrame("Frame", "LFMWatchListFrame", UIParent)
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
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local target = offset - (delta > 0 and 1 or -1)
        target = math.max(0, math.min(target, MaxOffset()))
        if target ~= offset then
            offset = target
            GameTooltip:Hide()
            Refresh()
        end
    end)
    Style.Panel(frame)

    local title = Style.Heading(frame, "LFM Watch", 13)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -9)
    titleCount = Style.Text(frame, 12, false, C.dim)
    titleCount:SetPoint("LEFT", title, "RIGHT", 6, 0)

    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(TITLE_HEIGHT - 3))
    rule:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -(TITLE_HEIGHT - 3))
    rule:SetHeight(1)
    rule:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)

    local close = Style.CloseButton(frame, function()
        closedByHand = true
        frame:Hide()
    end)
    close:SetScale(0.75)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)

    emptyText = Style.Text(frame, 12, false, C.dim)
    emptyText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -TITLE_HEIGHT - 4)
    emptyText:SetText("Nobody recruiting")

    moreText = Style.Text(frame, 12, false, C.dim)
    moreText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD + 2, 10)

    rowFrames = {}
    for i = 1, MAX_ROWS do rowFrames[i] = CreateRow(i) end

    RestorePosition()
    frame:Hide()
end

--------------------------------------------------------------------------
-- Drawing and expiry
--------------------------------------------------------------------------
local function DrawBar(row, now)
    local e = row.entry
    if not e then return end
    local life = Lifetime(e)
    local left = 1 - (now - StartedAt(e)) / life
    if left < 0 then left = 0 elseif left > 1 then left = 1 end
    row.bar:SetWidth(math.max(0.001, ROW_WIDTH * left))
    row.bar:SetShown(left > 0)
end

local function DrawRow(row, e, now)
    row.entry = e
    row.name:SetText(e.display)
    local colour = e.classColour or C.text
    row.name:SetTextColor(colour[1], colour[2], colour[3])

    local names = table.concat(e.instances, ", ")
    if e.full then
        names = names .. "  |cff8c8578Group Full|r"
        row.instance:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    else
        row.instance:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    row.instance:SetText(names)

    local list = (type(e.seats) == "table" and e.seats.list) or {}
    for i = 1, MAX_SEATS do
        row.seats[i]:SetSeat(list[i], e.full)
    end
    row.more:SetShown(type(e.seats) == "table" and e.seats.more == true)

    DrawBar(row, now)
    if e.flashAt and now - e.flashAt < FLASH_SECONDS then
        row:SetScript("OnUpdate", FlashUpdate)
    else
        row.flash:SetAlpha(0)
        row:SetScript("OnUpdate", nil)
    end
    row:Show()
end

Refresh = function()
    if not frame then return end
    if offset > MaxOffset() then offset = MaxOffset() end

    local total = #order
    local below = total - offset
    local visible, hidden = math.min(below, MAX_ROWS), 0
    if below > MAX_ROWS then
        -- the last line gives way to "+N more"
        visible = MAX_ROWS - 1
        hidden = below - visible
    end

    local now = GetTime()
    for i = 1, MAX_ROWS do
        local row = rowFrames[i]
        local e = (i <= visible) and rows[order[offset + i]] or nil
        if e then
            DrawRow(row, e, now)
        else
            row.entry = nil
            row:SetScript("OnUpdate", nil)
            row:Hide()
        end
    end

    titleCount:SetText(total > 0 and tostring(total) or "")
    emptyText:SetShown(total == 0)
    moreText:SetShown(hidden > 0)
    if hidden > 0 then moreText:SetText("+" .. hidden .. " more") end

    local lines = visible + (hidden > 0 and 1 or 0)
    frame:SetHeight(TITLE_HEIGHT + math.max(lines, 1) * ROW_HEIGHT + 8)
end

local function Forget(key)
    if rows[key] == nil then return false end
    rows[key] = nil
    for i = #order, 1, -1 do
        if order[i] == key then table.remove(order, i) end
    end
    return true
end

local function StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function HideIfEmpty()
    if #order > 0 then return false end
    StopTicker()
    closedByHand = false
    offset = 0
    if frame then
        Refresh()
        frame:Hide()
    end
    return true
end

local function Tick()
    local now = GetTime()
    local removed = false
    for i = #order, 1, -1 do
        local e = rows[order[i]]
        if not e or now - StartedAt(e) >= Lifetime(e) then
            if e then rows[order[i]] = nil end
            table.remove(order, i)
            removed = true
        end
    end
    if HideIfEmpty() then return end
    if frame and frame:IsShown() then
        if removed then
            Refresh()
        else
            for i = 1, MAX_ROWS do DrawBar(rowFrames[i], now) end
        end
    end
end

local function StartTicker()
    if not ticker then ticker = C_Timer.NewTicker(1, Tick) end
end

-- Show the window for a new or changed row, unless the player closed it and
-- this is only a repeat from someone already listed.
local function Announce(isNew)
    EnsureFrame()
    if ns.cdb.autoShow and (isNew or not closedByHand) then
        closedByHand = false
        frame:Show()
    end
    Refresh()
    StartTicker()
end

--------------------------------------------------------------------------
-- Public
--------------------------------------------------------------------------
function List.Get(key)
    return rows[key]
end

-- entry = { key, sender, display, guid, instances = {..}, kind, seats, text,
--           channel, time }. A second Add for the same key updates the row.
function List.Add(entry)
    if type(entry) ~= "table" or type(entry.sender) ~= "string" then return end
    local key = entry.key or entry.sender
    local now = entry.time or GetTime()
    local instances = entry.instances or {}

    local e = rows[key]
    local isNew = e == nil
    if isNew then
        e = { key = key }
        rows[key] = e
        order[#order + 1] = key
    elseif e.full or not SameNames(e.instances, instances) or not ns.Seats.Same(e.seats, entry.seats) then
        e.flashAt = now
    end
    -- the client may not have known the sender's class the first time
    if not e.classColour then e.classColour = ClassColour(entry.guid) end

    e.sender = entry.sender
    e.display = entry.display or entry.sender
    e.guid = entry.guid
    e.instances = instances
    e.kind = entry.kind or "dungeon"
    e.seats = entry.seats
    e.text = entry.text or ""
    e.channel = entry.channel or ""
    e.time = now
    e.full, e.fullAt = false, nil

    Announce(isNew)
end

-- The same group, asking for different places. Keeps the row's instance.
function List.UpdateSeats(key, seats, text, channel)
    local e = rows[key]
    if not e then return end
    local now = GetTime()
    if e.full or not ns.Seats.Same(e.seats, seats) then e.flashAt = now end
    e.seats = seats
    e.text = text or e.text
    e.channel = channel or e.channel
    e.time = now
    e.full, e.fullAt = false, nil
    Announce(false)
end

-- The recruiter says the group is full: the row stays for a minute, dimmed.
function List.MarkFull(key)
    local e = rows[key]
    if not e or e.full then return end
    e.full, e.fullAt = true, GetTime()
    Refresh()
end

function List.Remove(key)
    if not Forget(key) then return end
    if not HideIfEmpty() then Refresh() end
end

function List.Clear()
    rows, order = {}, {}
    HideIfEmpty()
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
    return #order
end

-- For /lfw debug. Message text is left out on purpose.
function List.Snapshot()
    local out, now = {}, GetTime()
    for _, key in ipairs(order) do
        local e = rows[key]
        if e then
            out[#out + 1] = {
                display = e.display,
                instances = table.concat(e.instances, "/"),
                seats = ns.Seats.Describe(e.seats),
                channel = e.channel,
                age = math.floor(now - e.time),
                full = e.full or false,
                keyedByGuid = e.guid ~= nil and e.key == e.guid,
            }
        end
    end
    return {
        shown = frame and frame:IsShown() or false,
        closedByHand = closedByHand,
        offset = offset,
        classIcons = Style.ClassIconSource(),
        rows = out,
    }
end
