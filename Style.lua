-- LFMWatch look: palette, fonts and the few widgets the windows are built
-- from. The colours, border and font follow FlareUI (MIT, see LICENSES);
-- the files are LFMWatch's own copies, so nothing here needs FlareUI.
--
-- Every font, texture and atlas is checked before use. A missing one gives a
-- plainer look, never an error.

local ADDON, ns = ...

local Style = {}
ns.Style = Style

local MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"

Style.MEDIA = MEDIA
Style.COLORS = {
    bg = { 0.05, 0.05, 0.05, 0.95 },
    border = { 0.65, 0.49, 0.27 },      -- bronze, #A67D45
    title = { 1, 0.82, 0 },
    highlight = { 1, 0.84, 0.50 },
    text = { 0.92, 0.90, 0.86 },
    dim = { 0.55, 0.52, 0.47 },
    role = {
        tank = { 0.25, 0.55, 1.00 },
        healer = { 0.30, 0.85, 0.30 },
        dps = { 0.90, 0.25, 0.20 },
        none = { 0.65, 0.49, 0.27 },    -- role not stated
    },
}
local C = Style.COLORS

local FONT = MEDIA .. "RobotoCondensed-Regular.ttf"
local FONT_BOLD = MEDIA .. "RobotoCondensed-Bold.ttf"

--------------------------------------------------------------------------
-- Fonts
--------------------------------------------------------------------------
function Style.SetFont(fs, size, bold)
    local ok = pcall(fs.SetFont, fs, bold and FONT_BOLD or FONT, size, "")
    local current = ok and fs:GetFont() or nil
    if not current then
        local stock = GameFontHighlightSmall and GameFontHighlightSmall:GetFont()
        if stock then pcall(fs.SetFont, fs, stock, size, "") end
    end
end

function Style.Text(parent, size, bold, colour, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlightSmall")
    Style.SetFont(fs, size or 12, bold)
    colour = colour or C.text
    fs:SetTextColor(colour[1], colour[2], colour[3])
    return fs
end

function Style.Heading(parent, text)
    local fs = Style.Text(parent, 13, true, C.title)
    fs:SetText(text or "")
    return fs
end

--------------------------------------------------------------------------
-- Panels and outlines
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

local function Fill(frame, colour, alpha)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(colour[1], colour[2], colour[3], alpha or colour[4] or 1)
    return t
end

-- Dark panel with the bronze frame border. The frame should be created with
-- "BackdropTemplate"; without it the panel gets a flat fill and a thin line.
function Style.Panel(frame)
    local done = false
    if frame.SetBackdrop then
        done = pcall(function()
            frame:SetBackdrop({
                bgFile = WHITE,
                edgeFile = MEDIA .. "Border.tga",
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            frame:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], C.bg[4])
            frame:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
    end
    if not done then
        Fill(frame, C.bg)
        Outline(frame, C.border)
    end
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
        bg:SetPoint("TOPLEFT", -4, 0)
        bg:SetPoint("BOTTOMRIGHT", 2, 0)
        bg:SetColorTexture(0, 0, 0, 0.5)
        local holder = CreateFrame("Frame", nil, edit)
        holder:SetPoint("TOPLEFT", -4, 0)
        holder:SetPoint("BOTTOMRIGHT", 2, 0)
        Outline(holder, C.border, 0.7)
    end
    local font = edit.GetFontObject and edit:GetFontObject()
    if edit.SetFont then
        local ok = pcall(edit.SetFont, edit, FONT, 12, "")
        if (not ok or not edit:GetFont()) and font then pcall(edit.SetFontObject, edit, font) end
    end
    edit:SetTextColor(C.text[1], C.text[2], C.text[3])
end

--------------------------------------------------------------------------
-- Flat button and checkbox
--------------------------------------------------------------------------
function Style.Button(parent, text, width, height)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width or 80, height or 20)
    Fill(b, { 0.12, 0.11, 0.10 }, 0.9)
    local edges = Outline(b, C.border, 0.9)
    local fs = Style.Text(b, 12, false, C.text)
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text or "")

    local function Paint(self)
        local colour = C.text
        if not self:IsEnabled() then
            colour = C.dim
        elseif self.lfwHover then
            colour = C.highlight
        end
        fs:SetTextColor(colour[1], colour[2], colour[3])
        local edge = (self.lfwHover and self:IsEnabled()) and C.highlight or C.border
        for _, t in ipairs(edges) do t:SetColorTexture(edge[1], edge[2], edge[3], 0.9) end
    end
    b:SetScript("OnEnter", function(self) self.lfwHover = true; Paint(self) end)
    b:SetScript("OnLeave", function(self) self.lfwHover = false; Paint(self) end)
    b:SetScript("OnEnable", Paint)
    b:SetScript("OnDisable", Paint)
    return b
end

-- A flat tick box with a label to its right (cb.label).
function Style.Check(parent)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(14, 14)
    Fill(cb, { 0, 0, 0 }, 0.5)
    Outline(cb, C.border, 0.9)

    local tick = cb:CreateTexture(nil, "ARTWORK")
    tick:SetPoint("TOPLEFT", 3, -3)
    tick:SetPoint("BOTTOMRIGHT", -3, 3)
    tick:SetColorTexture(C.title[1], C.title[2], C.title[3], 1)
    cb:SetCheckedTexture(tick)

    local hover = cb:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(C.highlight[1], C.highlight[2], C.highlight[3], 0.2)

    cb.label = Style.Text(cb, 12, false, C.text)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cb.label:SetJustifyH("LEFT")

    cb:SetScript("OnEnable", function(self)
        self.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        tick:SetDesaturated(false)
        tick:SetAlpha(1)
    end)
    cb:SetScript("OnDisable", function(self)
        self.label:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
        tick:SetAlpha(0.4)
    end)
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

    local icon = f:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetPoint("CENTER")

    pcall(function()
        local mask = f:CreateMaskTexture()
        mask:SetTexture(MEDIA .. "Circle.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end)

    local letters = Style.Text(f, math.max(8, size - 6), true, C.text)
    letters:SetPoint("CENTER", 0, 0)

    function f:SetSeat(seat, forceDim)
        if type(seat) ~= "table" then
            self:Hide()
            return
        end
        disc:Hide(); icon:Hide(); letters:Hide()
        icon:SetDesaturated(false)
        icon:SetVertexColor(1, 1, 1)
        icon:SetTexCoord(0, 1, 0, 1)
        local dim = forceDim or seat.state == "filled"

        if seat.state == "unknown" then
            icon:SetTexture(MEDIA .. "Question.tga")
            icon:SetSize(size, size)
            icon:SetVertexColor(C.title[1], C.title[2], C.title[3])
            icon:Show()
        elseif seat.class then
            local ring = C.role[seat.role or "none"] or C.role.none
            disc:SetSize(size, size)
            disc:SetVertexColor(ring[1], ring[2], ring[3])
            disc:Show()
            local atlas = ClassAtlas(seat.class)
            if atlas then
                icon:SetAtlas(atlas)
                icon:SetSize(size - 4, size - 4)
                icon:Show()
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
                icon:SetAtlas(atlas)
                icon:SetSize(size, size)
                icon:Show()
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

        icon:SetDesaturated(dim and true or false)
        self:SetAlpha(dim and 0.35 or 1)
        self:Show()
    end

    return f
end
