-- LFMWatch look: palette, fonts and the few widgets the windows are built
-- from. It follows the way FlareUI (MIT, see LICENSES) draws its settings
-- window: the game's own font in white and yellow, a rock background in a
-- heavy bronze frame, dark boxes with a thin bronze edge, and Blizzard's own
-- button and checkbox art. The border file is LFMWatch's own copy, so
-- nothing here needs FlareUI.
--
-- Every font, texture and atlas is checked before use. A missing one gives a
-- plainer look, never an error.

local ADDON, ns = ...

local Style = {}
ns.Style = Style

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local THIN = MEDIA .. "Border.tga"

Style.MEDIA = MEDIA
Style.COLORS = {
    text = { 1, 1, 1 },
    dim = { 0.5, 0.5, 0.5 },
    title = { 1, 0.82, 0 },             -- WoW's own yellow
    highlight = { 1, 0.84, 0.50 },
    border = { 0.65, 0.49, 0.27 },      -- bronze, #A67D45
    role = {
        tank = { 0.25, 0.55, 1.00 },
        healer = { 0.30, 0.85, 0.30 },
        dps = { 0.90, 0.25, 0.20 },
        none = { 0.65, 0.49, 0.27 },    -- role not stated
    },
}
local C = Style.COLORS

-- The game's standard face (Friz Quadrata on a Latin client).
local UI_FONT = (type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
-- A condensed face for the list's rows, as FlareUI uses in its meters.
local DATA_FONT = MEDIA .. "RobotoCondensed-Regular.ttf"

--------------------------------------------------------------------------
-- Atlases
--------------------------------------------------------------------------
local atlasKnown = {}
local function HasAtlas(name)
    if type(name) ~= "string" or name == "" then return false end
    if atlasKnown[name] == nil then
        local found = false
        if C_Texture and C_Texture.GetAtlasInfo then
            local ok, info = pcall(C_Texture.GetAtlasInfo, name)
            found = ok and info ~= nil
        end
        atlasKnown[name] = found
    end
    return atlasKnown[name]
end

--------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------
local function ApplyFont(fs, file, size)
    local ok, set = pcall(fs.SetFont, fs, file, size, "")
    return ok and set ~= false and fs:GetFont() ~= nil
end

local function Shade(fs)
    if fs.SetShadowColor then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
end

-- The window font at this size. (The third argument is kept for callers
-- that pass a weight; the game's face has only one.)
function Style.SetFont(fs, size)
    if not ApplyFont(fs, UI_FONT, size) then
        local stock = GameFontHighlight and GameFontHighlight:GetFont()
        if stock then pcall(fs.SetFont, fs, stock, size, "") end
    end
    Shade(fs)
end

function Style.Text(parent, size, _, colour, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
    Style.SetFont(fs, size or 13)
    colour = colour or C.text
    fs:SetTextColor(colour[1], colour[2], colour[3])
    return fs
end

-- Condensed text for rows of data; the window font when the file is missing.
-- A font file the client cannot load is accepted without complaint and then
-- draws nothing, so the condensed face is tried once on a scratch string and
-- measured before any row relies on it.
local dataFontWorks
local function DataFontWorks()
    if dataFontWorks == nil then
        dataFontWorks = false
        local ok = pcall(function()
            local probe = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontHighlight")
            probe:Hide()
            if ApplyFont(probe, DATA_FONT, 13) then
                probe:SetText("Ag")
                local width = probe:GetStringWidth()
                dataFontWorks = type(width) == "number" and width > 1
            end
            probe:SetText("")
        end)
        if not ok then dataFontWorks = false end
    end
    return dataFontWorks
end

-- "condensed" or "standard": which face the rows are drawn in. For /lfw debug.
function Style.DataFontSource()
    return DataFontWorks() and "condensed" or "standard"
end

function Style.DataText(parent, size, colour, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
    if not (DataFontWorks() and ApplyFont(fs, DATA_FONT, size or 13)) then
        Style.SetFont(fs, size or 13)
    end
    Shade(fs)
    colour = colour or C.text
    fs:SetTextColor(colour[1], colour[2], colour[3])
    return fs
end

function Style.Heading(parent, text, size)
    local fs = Style.Text(parent, size or 17, false, C.title)
    fs:SetText(text or "")
    return fs
end

--------------------------------------------------------------------------
-- Outlines and fills
--------------------------------------------------------------------------
-- A 1 px outline made of four textures; returns them for recolouring.
local function Outline(frame, colour, alpha)
    local edges = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(colour[1], colour[2], colour[3], alpha or 1)
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
    edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
    edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
    edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
    return edges
end

local function Fill(frame, r, g, b, a)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(r, g, b, a)
    return t
end

-- The thin bronze edge with rounded corners, over a flat fill. The frame
-- should be created with "BackdropTemplate"; without it, a square outline.
local function ThinBackdrop(frame, r, g, b, a)
    local done = false
    if frame.SetBackdrop then
        done = pcall(function()
            frame:SetBackdrop({
                bgFile = WHITE,
                edgeFile = THIN,
                edgeSize = 8,
                insets = { left = 4, right = 4, top = 4, bottom = 4 },
            })
            frame:SetBackdropColor(r, g, b, a)
            frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
    end
    if not done then
        Fill(frame, r, g, b, a)
        Outline(frame, C.border)
    end
end

-- A small free-standing window (the list).
function Style.Panel(frame)
    ThinBackdrop(frame, 0.06, 0.05, 0.04, 0.85)
end

-- A box inside a window: a section of settings.
function Style.Box(frame)
    ThinBackdrop(frame, 0, 0, 0, 0.28)
end

-- A large window (settings): rock, tinted bronze and darkened towards the
-- bottom, in the heavy bronze frame the character list uses.
function Style.Window(frame)
    local art = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    art:SetPoint("TOPLEFT", 0, 0)
    art:SetPoint("BOTTOMRIGHT", 0, 0)
    local rock = pcall(function()
        art:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        art:SetHorizTile(true)
        art:SetVertTile(true)
        art:SetDesaturated(true)
        art:SetVertexColor(0.85, 0.68, 0.47)
    end)
    if not rock then art:SetColorTexture(0.10, 0.08, 0.06, 1) end

    -- a dark ground under the rock, in case the rock art is not there
    local ground = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    ground:SetAllPoints(art)
    ground:SetColorTexture(0.07, 0.055, 0.04, 1)

    local wash = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    wash:SetAllPoints(art)
    wash:SetColorTexture(0.05, 0.038, 0.026, 0.3)

    pcall(function()
        local glow = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
        glow:SetPoint("TOPLEFT", art)
        glow:SetPoint("TOPRIGHT", art)
        glow:SetHeight(200)
        glow:SetColorTexture(1, 1, 1)
        glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.20))
        local shade = frame:CreateTexture(nil, "BACKGROUND", nil, 3)
        shade:SetPoint("BOTTOMLEFT", art)
        shade:SetPoint("BOTTOMRIGHT", art)
        shade:SetHeight(260)
        shade:SetColorTexture(1, 1, 1)
        shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.5), CreateColor(0, 0, 0, 0))
    end)

    if HasAtlas("heavybronze-frame-basic") then
        local bronze = CreateFrame("Frame", nil, frame)
        bronze:SetAllPoints()
        bronze:SetFrameLevel(frame:GetFrameLevel() + 30)
        local edge = bronze:CreateTexture(nil, "BORDER")
        edge:SetAtlas("heavybronze-frame-basic")
        edge:SetPoint("TOPLEFT", -9, 15)
        edge:SetPoint("BOTTOMRIGHT", 9, -15)
        for _, c in ipairs({ { "TL", "TOPLEFT" }, { "BR", "BOTTOMRIGHT" } }) do
            local name = "heavybronze-horz-cornerbracket-" .. c[1]
            if HasAtlas(name) then
                local t = bronze:CreateTexture(nil, "ARTWORK")
                t:SetAtlas(name, true)
                t:SetPoint(c[2], edge, c[2])
            end
        end
    else
        local holder = CreateFrame("Frame", nil, frame, frame.SetBackdrop and "BackdropTemplate" or nil)
        holder:SetAllPoints()
        if holder.SetBackdrop then
            pcall(function()
                holder:SetBackdrop({ edgeFile = THIN, edgeSize = 8 })
                holder:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            end)
        else
            Outline(holder, C.border)
        end
    end
end

-- Blizzard's red close button; a plain "x" where the template is missing.
function Style.CloseButton(parent, onClick)
    local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelCloseButton")
    if not (ok and b) then
        b = CreateFrame("Button", nil, parent)
        b:SetSize(20, 20)
        local x = Style.Text(b, 15, false, C.border)
        x:SetAllPoints()
        x:SetText("x")
        b:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function() x:SetTextColor(C.border[1], C.border[2], C.border[3]) end)
    end
    b:SetScript("OnClick", onClick)
    return b
end

-- Mouse wheel scrolling for a plain ScrollFrame, with Blizzard's thin scroll
-- bar (MinimalScrollBar, drawn at 70% as FlareUI does) in the gutter to its
-- right. The bar shows only when there is something to scroll. Where the
-- client lacks that bar, the wheel still works.
local SCROLL_SCALE = 0.7

function Style.AttachScroll(scroll, parent, step)
    local line
    local ok, made = pcall(CreateFrame, "EventFrame", nil, parent, "MinimalScrollBar")
    if ok and made and made.SetScrollPercentage and made.SetVisibleExtentPercentage and made.RegisterCallback then
        line = made
        line:SetScale(SCROLL_SCALE)
        line:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6 / SCROLL_SCALE, 0)
        line:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6 / SCROLL_SCALE, 0)
    elseif ok and made then
        made:Hide()
    end

    local setting = false
    local function Update()
        if not line then return end
        local range = scroll:GetVerticalScrollRange() or 0
        local height = scroll:GetHeight() or 0
        if not scroll:IsShown() or range <= 0.5 or height <= 0 then
            line:Hide()
            return
        end
        local visible = height / (height + range)
        local position = math.max(0, math.min(1, (scroll:GetVerticalScroll() or 0) / range))
        line:Show()
        setting = true
        pcall(function()
            line:SetVisibleExtentPercentage(visible)
            if line.SetPanExtentPercentage then
                line:SetPanExtentPercentage(math.max(0.01, visible * 0.25))
            end
            line:SetScrollPercentage(position, true)
        end)
        setting = false
    end

    if line then
        pcall(line.RegisterCallback, line, "OnScroll", function(_, position)
            if setting then return end
            position = math.max(0, math.min(1, position or 0))
            scroll:SetVerticalScroll(position * (scroll:GetVerticalScrollRange() or 0))
        end, line)
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local target = (self:GetVerticalScroll() or 0) - delta * (step or 40)
        self:SetVerticalScroll(math.max(0, math.min(range, target)))
    end)
    scroll:HookScript("OnVerticalScroll", Update)
    scroll:HookScript("OnScrollRangeChanged", Update)
    scroll:HookScript("OnSizeChanged", Update)
    scroll:HookScript("OnShow", Update)
    Update()
    return Update
end

function Style.EditBackdrop(edit)
    -- InputBoxTemplate draws its own three-piece border; hide it when present
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local piece = edit[key]
        if piece and piece.Hide then piece:Hide() end
    end
    if not edit.lfwStyled then
        edit.lfwStyled = true
        local bg = edit:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", -5, 1)
        bg:SetPoint("BOTTOMRIGHT", 3, -1)
        bg:SetColorTexture(0, 0, 0, 0.45)
        local holder = CreateFrame("Frame", nil, edit)
        holder:SetPoint("TOPLEFT", -5, 1)
        holder:SetPoint("BOTTOMRIGHT", 3, -1)
        Outline(holder, C.border, 0.8)
    end
    if edit.SetFont then pcall(edit.SetFont, edit, UI_FONT, 12, "") end
    edit:SetTextColor(1, 1, 1)
end

--------------------------------------------------------------------------
-- Button and checkbox: Blizzard's own art, as FlareUI's window uses
--------------------------------------------------------------------------
local FACE = "common-dropdown-c-button"

function Style.Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 80, height or 22)

    local art = HasAtlas(FACE)
    local face, edges
    if art then
        face = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        face:SetPoint("TOPLEFT", -7, 7)
        face:SetPoint("BOTTOMRIGHT", 7, -7)
    else
        Fill(b, 0.12, 0.10, 0.08, 0.9)
        edges = Outline(b, C.border, 0.9)
    end

    local fs = Style.Text(b, 12, false, C.title)
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text or "")

    local function Paint(self)
        local enabled = self:IsEnabled()
        if face then
            local atlas = FACE
            if not enabled then
                atlas = FACE .. "-disabled"
            elseif self.lfwDown and self.lfwOver then
                atlas = FACE .. "-pressedhover-1"
            elseif self.lfwDown then
                atlas = FACE .. "-pressed-1"
            elseif self.lfwOver then
                atlas = FACE .. "-hover-1"
            end
            face:SetAtlas(HasAtlas(atlas) and atlas or FACE)
        else
            local edge = (self.lfwOver and enabled) and C.highlight or C.border
            for _, t in ipairs(edges) do t:SetColorTexture(edge[1], edge[2], edge[3], 0.9) end
        end
        if not enabled then
            fs:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        elseif self.lfwOver then
            fs:SetTextColor(1, 1, 1)
        else
            fs:SetTextColor(C.title[1], C.title[2], C.title[3])
        end
    end
    b:SetScript("OnEnter", function(self) self.lfwOver = true; Paint(self) end)
    b:SetScript("OnLeave", function(self) self.lfwOver = nil; Paint(self) end)
    b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.lfwDown = true; Paint(self) end end)
    b:SetScript("OnMouseUp", function(self) self.lfwDown = nil; Paint(self) end)
    b:SetScript("OnEnable", Paint)
    b:SetScript("OnDisable", function(self) self.lfwDown, self.lfwOver = nil, nil; Paint(self) end)
    b:SetScript("OnShow", Paint)
    b:SetScript("OnHide", function(self) self.lfwDown, self.lfwOver = nil, nil end)
    Paint(b)
    return b
end

-- A tick box with a label to its right (cb.label). Blizzard's settings
-- checkbox art; a flat box where that is missing.
function Style.Check(parent)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(24, 23)

    if HasAtlas("checkbox-minimal") and HasAtlas("checkmark-minimal") then
        cb:SetNormalAtlas("checkbox-minimal")
        cb:SetPushedAtlas("checkbox-minimal")
        local tick = cb:CreateTexture(nil, "ARTWORK")
        tick:SetAtlas("checkmark-minimal")
        tick:SetPoint("TOPLEFT", 1, -1)
        tick:SetPoint("BOTTOMRIGHT", -1, 1)
        cb:SetCheckedTexture(tick)
        if HasAtlas("checkmark-minimal-disabled") and cb.SetDisabledCheckedTexture then
            local grey = cb:CreateTexture(nil, "ARTWORK")
            grey:SetAtlas("checkmark-minimal-disabled")
            grey:SetPoint("TOPLEFT", 1, -1)
            grey:SetPoint("BOTTOMRIGHT", -1, 1)
            cb:SetDisabledCheckedTexture(grey)
        end
    else
        local box = cb:CreateTexture(nil, "BACKGROUND")
        box:SetPoint("TOPLEFT", 4, -4)
        box:SetPoint("BOTTOMRIGHT", -4, 4)
        box:SetColorTexture(0, 0, 0, 0.5)
        local tick = cb:CreateTexture(nil, "ARTWORK")
        tick:SetPoint("TOPLEFT", 7, -7)
        tick:SetPoint("BOTTOMRIGHT", -7, 7)
        tick:SetColorTexture(C.title[1], C.title[2], C.title[3], 1)
        cb:SetCheckedTexture(tick)
        local rim = CreateFrame("Frame", nil, cb)
        rim:SetPoint("TOPLEFT", 4, -4)
        rim:SetPoint("BOTTOMRIGHT", -4, 4)
        Outline(rim, C.border, 0.9)
    end

    cb.label = Style.Text(cb, 13, false, C.text)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.label:SetJustifyH("LEFT")

    -- Set the label and make it clickable along with the box.
    function cb:SetLabel(text, maxWidth)
        self.label:SetWidth(maxWidth)
        self.label:SetText(text)
        local width = math.min(self.label:GetStringWidth() or maxWidth, maxWidth)
        self:SetHitRectInsets(0, -(width + 6), 0, 0)
    end

    cb:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    cb:SetScript("OnDisable", function(self) self:SetAlpha(0.45) end)
    return cb
end

--------------------------------------------------------------------------
-- Seat icons
--------------------------------------------------------------------------
local ROLE_ATLAS = {
    tank = "UI-LFG-RoleIcon-Tank-Micro-GroupFinder",
    healer = "UI-LFG-RoleIcon-Healer-Micro-GroupFinder",
    dps = "UI-LFG-RoleIcon-DPS-Micro-GroupFinder",
}
local ROLE_LETTER = { tank = "T", healer = "H", dps = "D" }
local CLASS_LETTERS = {
    WARRIOR = "Wr", PALADIN = "Pa", HUNTER = "Hu", ROGUE = "Ro", PRIEST = "Pr",
    SHAMAN = "Sh", MAGE = "Ma", WARLOCK = "Wl", DRUID = "Dr",
}

local function ClassAtlas(class)
    local name
    if type(GetClassAtlas) == "function" then
        local ok, result = pcall(GetClassAtlas, class)
        if ok and type(result) == "string" then name = result end
    end
    name = name or ("classicon-" .. class:lower())
    return HasAtlas(name) and name or nil
end

function Style.ClassColor(class)
    local c
    if type(class) == "string" then
        if C_ClassColor and C_ClassColor.GetClassColor then
            local ok, colour = pcall(C_ClassColor.GetClassColor, class)
            if ok and type(colour) == "table" then c = colour end
        end
        if not c and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[class] end
    end
    if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
    return nil
end

-- Which drawing the class seats use here: "atlas" or "letters". For /lfw debug.
function Style.ClassIconSource()
    return ClassAtlas("MAGE") and "atlas" or "letters"
end

-- A seat icon. icon:SetSeat(seat, forceDim); seat is
-- { state = "open"|"filled"|"unknown", role = ..., class = ... } or nil.
function Style.SeatIcon(parent, size)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)

    local disc = f:CreateTexture(nil, "ARTWORK", nil, 0)
    disc:SetTexture(MEDIA .. "Circle.tga")
    disc:SetPoint("CENTER")

    -- class pictures are square: clipped round, inside the ring
    local classIcon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    classIcon:SetPoint("CENTER")
    classIcon:SetSize(size - 4, size - 4)
    pcall(function()
        local mask = f:CreateMaskTexture()
        mask:SetTexture(MEDIA .. "Circle.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(classIcon)
        classIcon:AddMaskTexture(mask)
    end)

    -- role pictures are drawn as they come
    local roleIcon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    roleIcon:SetPoint("CENTER")
    roleIcon:SetSize(size, size)

    local letters = Style.DataText(f, math.max(9, size - 5), C.text)
    letters:SetPoint("CENTER", 0, 0)

    function f:SetSeat(seat, forceDim)
        if type(seat) ~= "table" then
            self:Hide()
            return
        end
        disc:Hide(); classIcon:Hide(); roleIcon:Hide(); letters:Hide()
        local dim = forceDim or seat.state == "filled"

        if seat.state == "unknown" then
            -- drawn with the font, so it needs no art file
            letters:SetText("?")
            letters:SetTextColor(C.title[1], C.title[2], C.title[3])
            letters:Show()
        elseif seat.class then
            local ring = C.role[seat.role or "none"] or C.role.none
            disc:SetSize(size, size)
            disc:SetVertexColor(ring[1], ring[2], ring[3])
            disc:Show()
            local atlas = ClassAtlas(seat.class)
            if atlas then
                classIcon:SetAtlas(atlas)
                classIcon:SetSize(size - 4, size - 4)
                classIcon:SetDesaturated(dim and true or false)
                classIcon:Show()
            else
                disc:SetVertexColor(ring[1] * 0.45, ring[2] * 0.45, ring[3] * 0.45)
                letters:SetText(CLASS_LETTERS[seat.class] or "?")
                local r, g, b = Style.ClassColor(seat.class)
                letters:SetTextColor(r or 1, g or 1, b or 1)
                letters:Show()
            end
        elseif seat.role then
            local atlas = ROLE_ATLAS[seat.role]
            if HasAtlas(atlas) then
                roleIcon:SetAtlas(atlas)
                roleIcon:SetSize(size, size)
                roleIcon:SetDesaturated(dim and true or false)
                roleIcon:Show()
            else
                local ring = C.role[seat.role] or C.role.none
                disc:SetSize(size, size)
                disc:SetVertexColor(ring[1] * 0.45, ring[2] * 0.45, ring[3] * 0.45)
                disc:Show()
                letters:SetText(ROLE_LETTER[seat.role] or "?")
                letters:SetTextColor(ring[1], ring[2], ring[3])
                letters:Show()
            end
        else
            -- a filled seat whose role is not known: a small plain dot
            disc:SetSize(size * 0.4, size * 0.4)
            disc:SetVertexColor(C.dim[1], C.dim[2], C.dim[3])
            disc:Show()
        end

        self:SetAlpha(dim and 0.35 or 1)
        self:Show()
    end

    return f
end
