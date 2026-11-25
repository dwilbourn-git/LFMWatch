-- LFMWatch settings window. Opened with /lfw. Plain frames only.

local ADDON, ns = ...

local Options = {}
ns.Options = Options

local WIDTH, HEIGHT = 560, 600
local CONTENT_WIDTH = 500
local ROW = 24
local NAME_WIDTH = 210
local ALIAS_WIDTH = 220

local Style = ns.Style
local C = Style.COLORS

local frame, scroll, content
local Build   -- defined below

--------------------------------------------------------------------------
-- Widget pools: the window is rebuilt from scratch each time it changes
--------------------------------------------------------------------------
local pools = { check = {}, label = {}, edit = {}, button = {} }
local used = { check = 0, label = 0, edit = 0, button = 0 }

local creators = {}

function creators.check()
    local cb = Style.Check(content)
    if cb.label.SetWordWrap then cb.label:SetWordWrap(false) end
    cb:SetScript("OnClick", function(self)
        if self.onChange then self.onChange(self:GetChecked() and true or false) end
    end)
    return cb
end

function creators.label()
    return Style.Text(content, 12, false, C.text)
end

function creators.edit()
    local eb = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetHeight(20)
    eb:SetMaxLetters(600)
    Style.EditBackdrop(eb)
    local function Save(self)
        local text = self:GetText() or ""
        if text ~= self.saved then
            self.saved = text
            if self.onSave then self.onSave(text, self) end
        end
    end
    eb:SetScript("OnEnterPressed", function(self)
        Save(self)
        self:ClearFocus()
    end)
    eb:SetScript("OnEditFocusLost", Save)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(self.saved or "")
        self:ClearFocus()
    end)
    return eb
end

function creators.button()
    local b = Style.Button(content, "", 80, 20)
    b:SetScript("OnClick", function(self)
        if self.onClick then self.onClick(self) end
    end)
    return b
end

local function Acquire(kind)
    used[kind] = used[kind] + 1
    local w = pools[kind][used[kind]]
    if not w then
        w = creators[kind]()
        pools[kind][used[kind]] = w
    end
    w:ClearAllPoints()
    w:Show()
    return w
end

local function ReleaseAll()
    for kind, list in pairs(pools) do
        for _, w in ipairs(list) do
            if kind == "edit" then
                w:ClearFocus()      -- saves anything typed, through its current row
                w.onSave = nil
            end
            w:Hide()
        end
        used[kind] = 0
    end
end

--------------------------------------------------------------------------
-- Layout helpers; y is the running offset from the top of the content
--------------------------------------------------------------------------
local y

local function Header(text)
    y = y + 8
    local fs = Acquire("label")
    Style.SetFont(fs, 13, true)
    fs:SetTextColor(C.title[1], C.title[2], C.title[3])
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
    fs:SetWidth(CONTENT_WIDTH)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    y = y + 20
end

local function Note(text)
    local fs = Acquire("label")
    Style.SetFont(fs, 11, false)
    fs:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -y)
    fs:SetWidth(CONTENT_WIDTH)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    y = y + 16
end

local function Check(x, text, checked, onChange, greyed, labelWidth)
    local cb = Acquire("check")
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", x + 2, -y - 4)
    cb:Enable()
    cb:SetChecked(checked and true or false)
    cb:SetLabel(text, labelWidth or (CONTENT_WIDTH - 40))
    local colour = greyed and C.dim or C.text
    cb.label:SetTextColor(colour[1], colour[2], colour[3])
    cb.onChange = onChange
    return cb
end

local function Edit(x, width, text, onSave)
    local eb = Acquire("edit")
    eb:SetPoint("TOPLEFT", content, "TOPLEFT", x + 6, -y - 1)
    eb:SetWidth(width)
    eb.saved = text or ""
    eb:SetText(eb.saved)
    eb:SetCursorPosition(0)
    eb.onSave = onSave
    return eb
end

local function Button(x, width, text, onClick)
    local b = Acquire("button")
    b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y)
    b:SetWidth(width)
    b:SetText(text)
    b.onClick = onClick
    return b
end

local function Changed()
    if ns.Match then ns.Match.Rebuild() end
end

--------------------------------------------------------------------------
-- Sections
--------------------------------------------------------------------------
-- { { key = "localdefense", label = "LocalDefense", joined = true }, ... }
local function Channels()
    local list, seen = {}, {}
    if type(GetChannelList) == "function" then
        local r = { pcall(GetChannelList) }
        if r[1] then
            -- triples: number, name, disabled
            for i = 3, #r, 3 do
                local name = r[i]
                if ns.Readable(name) and type(name) == "string" then
                    local key = ns.Chat.ChannelKey(name)
                    if key and not seen[key] then
                        seen[key] = true
                        local label = ns.Chat.ChannelLabel(name)
                        if ns.Chat.IsCommunity(name) then
                            -- the client hides community chat text from addons
                            list[#list + 1] = { key = key, label = label .. " (community chat is hidden from addons)", blocked = true }
                        else
                            list[#list + 1] = { key = key, label = label, joined = true }
                        end
                    end
                end
            end
        end
    end
    -- ticked earlier but not joined now: still listed so it can be unticked
    for key, on in pairs(ns.cdb.channels) do
        if on and not seen[key] then
            seen[key] = true
            list[#list + 1] = { key = key, label = ns.Chat.ChannelLabel(key) .. " (not joined)", joined = false }
        end
    end
    return list
end

local function ChannelSection()
    Header("Channels to watch")
    Check(4, "Guild chat", ns.cdb.guild, function(on) ns.cdb.guild = on end)
    y = y + ROW
    for _, ch in ipairs(Channels()) do
        local key = ch.key
        local cb = Check(4, ch.label, (not ch.blocked) and ns.cdb.channels[key], function(on)
            ns.cdb.channels[key] = on or nil
        end, ch.blocked or not ch.joined)
        if ch.blocked then cb:Disable() end
        y = y + ROW
    end
end

local function InstanceSection(title, kind)
    Header(title)
    local keys = ns.Journal.Sorted(kind)
    if #keys == 0 then
        Note("None yet. Add one below.")
        return
    end
    for _, key in ipairs(keys) do
        local inst = ns.db.instances[key]
        Check(4, inst.name, ns.cdb.watched[key], function(on)
            ns.cdb.watched[key] = on or nil
            Changed()
        end, false, NAME_WIDTH - 28)
        Edit(NAME_WIDTH, ALIAS_WIDTH, table.concat(inst.aliases or {}, ", "), function(text, box)
            -- the row may have just been removed with text still typed in it
            if not ns.db.instances[key] then return end
            ns.Journal.SetAliases(key, text)
            -- show the cleaned-up list (lower case, no duplicates)
            box.saved = table.concat(ns.db.instances[key].aliases, ", ")
            box:SetText(box.saved)
            Changed()
        end)
        if inst.custom then
            Button(NAME_WIDTH + ALIAS_WIDTH + 14, 24, "x", function()
                ns.Journal.Remove(key)
                Changed()
                Build()
            end)
        end
        y = y + ROW
    end
end

local addName, addAliases = "", ""

local function AddSection()
    Header("Add a dungeon or raid")
    Note("Name, then its abbreviations separated by commas.")
    local nameBox = Edit(0, NAME_WIDTH - 12, addName, function(text) addName = text end)
    local aliasBox = Edit(NAME_WIDTH, ALIAS_WIDTH, addAliases, function(text) addAliases = text end)
    y = y + ROW + 2
    local function Add(kind)
        nameBox:ClearFocus()
        aliasBox:ClearFocus()
        local key, reason = ns.Journal.Add(nameBox:GetText(), kind, aliasBox:GetText())
        if not key then
            ns.Print(reason)
            return
        end
        ns.cdb.watched[key] = true
        addName, addAliases = "", ""
        Changed()
        Build()
    end
    Button(4, 110, "Add dungeon", function() Add("dungeon") end)
    Button(120, 110, "Add raid", function() Add("raid") end)
    y = y + ROW + 2
end

local function WordsSection()
    Header("Words")
    Note("A message must name a ticked dungeon or raid and contain one of these:")
    Edit(0, CONTENT_WIDTH - 20, table.concat(ns.db.triggers, ", "), function(text, box)
        ns.db.triggers = ns.Journal.ParseList(text)
        box.saved = table.concat(ns.db.triggers, ", ")
        box:SetText(box.saved)
        Changed()
    end)
    y = y + ROW + 2
    Note("A message containing any of these is never marked:")
    Edit(0, CONTENT_WIDTH - 20, table.concat(ns.db.ignore, ", "), function(text, box)
        ns.db.ignore = ns.Journal.ParseList(text)
        box.saved = table.concat(ns.db.ignore, ", ")
        box:SetText(box.saved)
        Changed()
    end)
    y = y + ROW + 4

    Check(4, "Include LFG posts (people looking for a group to join)", ns.db.includeLFG, function(on)
        ns.db.includeLFG = on
        Changed()
    end)
    y = y + ROW
    Check(4, "Show the list automatically when someone recruits", ns.cdb.autoShow, function(on)
        ns.cdb.autoShow = on
    end)
    y = y + ROW + 2

    local fs = Acquire("label")
    Style.SetFont(fs, 12, false)
    fs:SetTextColor(C.text[1], C.text[2], C.text[3])
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 6, -y - 4)
    fs:SetWidth(260)
    fs:SetJustifyH("LEFT")
    fs:SetText("Minutes a person stays on the list (1-15):")
    Edit(270, 40, tostring(ns.db.expiryMinutes), function(text, box)
        ns.db.expiryMinutes = ns.ClampExpiry(text)
        box.saved = tostring(ns.db.expiryMinutes)
        box:SetText(box.saved)
    end)
    y = y + ROW + 8
end

Build = function()
    if not frame then return end
    ReleaseAll()
    y = 0
    ChannelSection()
    InstanceSection("Dungeons", "dungeon")
    InstanceSection("Raids", "raid")
    AddSection()
    WordsSection()
    content:SetHeight(y + 10)
end

--------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------
local function EnsureFrame()
    if frame then return end
    local ok, made = pcall(CreateFrame, "Frame", "LFMWatchOptionsFrame", UIParent, "BackdropTemplate")
    frame = (ok and made) or CreateFrame("Frame", "LFMWatchOptionsFrame", UIParent)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Style.Panel(frame)

    local title = Style.Heading(frame, "LFM Watch")
    Style.SetFont(title, 16, true)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)

    local hint = Style.Text(frame, 11, false, C.dim)
    hint:SetPoint("LEFT", title, "RIGHT", 10, -1)
    hint:SetText("Try a message with /lfw test LF1M healer DM")

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    local x = Style.Text(close, 15, true, C.border)
    x:SetAllPoints()
    x:SetText("x")
    close:SetScript("OnEnter", function() x:SetTextColor(C.highlight[1], C.highlight[2], C.highlight[3]) end)
    close:SetScript("OnLeave", function() x:SetTextColor(C.border[1], C.border[2], C.border[3]) end)
    close:SetScript("OnClick", function() frame:Hide() end)

    scroll = CreateFrame("ScrollFrame", "LFMWatchOptionsScroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -40)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 12)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(CONTENT_WIDTH, 10)
    scroll:SetScrollChild(content)

    -- closes with Escape
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "LFMWatchOptionsFrame")
    end
    frame:Hide()
end

function Options.Toggle()
    EnsureFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        Build()
        frame:Show()
    end
end

--------------------------------------------------------------------------
-- First-run hint
--------------------------------------------------------------------------
ns.OnLogin(function()
    local anyChannel = ns.cdb.guild or next(ns.cdb.channels) ~= nil
    local anyInstance = next(ns.cdb.watched) ~= nil
    if not (anyChannel and anyInstance) then
        ns.Print("nothing is being watched yet. Type /lfw to choose channels and dungeons.")
    end
end)
