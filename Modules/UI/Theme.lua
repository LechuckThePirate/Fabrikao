local ADDON, ns = ...

-- The look of every window ("La Forja del Maestro Artesano" - forged iron, tempered bronze and amber embers): one
-- palette, the fonts and the pieces the windows are built from (panels, bronze buttons, skill bars, the brass
-- border). The windows only ask for them by name, so a color or a texture changes here for all of them.
--
-- The style book's 9-slice frames (FrameBronze9Slice, the anvil medallion, the forge header) are not painted yet:
-- until Media\Textures holds them, panels are flat backdrops (a brass 1px border) rather than T.NineSlice, same
-- shape as Completao's Theme so swapping them in later only touches this file.
local T = {}
ns.Theme = T

T.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Textures\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function hex(s, a)
    return { tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255, a or 1 }
end

T.colors = {
    iron = hex("0E1116"),        -- window base and the recipe tables
    slate = hex("171C24"),       -- profession cards, the filter bar, the detail drawer
    card = hex("1E2430"),        -- alternate rows, nested cards
    cardHover = hex("262E3D"),
    bronze = hex("D97706"),      -- main titles, the active profession's frame, anvil icons, primary buttons
    bronzeLight = hex("F0A83E"),
    brass = hex("5C4932"),       -- 1px structural borders, section dividers, 9-slice frames
    parchment = hex("262019"),   -- warm backing of the selected recipe's detail card
    profit = hex("22C55E"),      -- positive AH profit, material in stock, known recipe
    loss = hex("EF4444"),        -- negative AH profit, missing material, not enough skill
    locked = hex("64748B"),      -- unmet requirements, disabled controls
    muted = hex("94A3B8"),       -- secondary text
    text = hex("E2E8F0"),
}

-- FRIZQT__.TTF has no Cyrillic, Korean or Chinese glyphs, and recipe and NPC names come in the client's language, so
-- the text takes the client's own standard font (FRIZQT__.TTF on the Latin clients, FRIZQT___CYR.TTF on ruRU, their
-- own file on koKR / zhCN / zhTW). The logo is Latin text, but the Asian clients may lack that file.
local STANDARD = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local ASIAN = { koKR = true, zhCN = true, zhTW = true }
local asian = GetLocale and ASIAN[GetLocale()]

T.fonts = {
    logo = { asian and STANDARD or "Fonts\\MORPHEUS.TTF", 16 },
    title = { STANDARD, 15 },
    heading = { STANDARD, 12 },
    body = { STANDARD, 11 },
    small = { STANDARD, 10 },
    data = { asian and STANDARD or "Fonts\\ARIALN.TTF", 10 },
}

-- r, g, b, a of a palette color (alpha overridden when given).
function T.rgba(name, alpha)
    local c = T.colors[name]
    return c[1], c[2], c[3], alpha or c[4]
end

-- "|cffrrggbb" for inline text.
function T.code(name)
    local c = T.colors[name]
    return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

-- A font from T.fonts on a font string (the template's font stays if the client can't load the file).
function T.Font(fs, kind, color, shadow)
    local f = T.fonts[kind] or T.fonts.body
    if fs.SetFont then fs:SetFont(f[1], f[2], "") end
    if color then fs:SetTextColor(T.rgba(color)) end
    if fs.SetShadowOffset then
        if shadow ~= false then
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 0.9)
        else
            fs:SetShadowOffset(0, 0)
        end
    end
    return fs
end

function T.Text(parent, kind, color, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
    return T.Font(fs, kind, color)
end

local BACKDROP = { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 }
T.BACKDROP = BACKDROP

-- A flat forged panel: palette background (slate by default) and a 1px brass border. On a BackdropTemplate frame.
function T.Style(f, bg, border, bgAlpha)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(T.rgba(bg or "slate", bgAlpha))
    if border == false then
        f:SetBackdropBorderColor(0, 0, 0, 0)
    else
        f:SetBackdropBorderColor(T.rgba(border or "brass"))
    end
    return f
end

function T.CreateForgedFrame(parent, kind, bg, border, name)
    local f = CreateFrame(kind or "Frame", name, parent, "BackdropTemplate")
    return T.Style(f, bg, border)
end

---------------------------------------------------------------------------------------------------------- buttons

-- Paints a button for its state: normal, hover (the mouse over it) or disabled.
local function paintButton(b)
    local style = b.themeStyle
    local enabled = b:IsEnabled()
    local hover = enabled and b.hovered
    local fs = b:GetFontString()
    if style == "bronze" then
        b.shade:SetShown(enabled)
        if enabled then
            b.fill:SetColorTexture(T.rgba(hover and "bronzeLight" or "bronze"))
            b:SetBackdropBorderColor(T.rgba("bronzeLight"))
            if fs then fs:SetTextColor(0.12, 0.07, 0.02) end
        else
            b.fill:SetColorTexture(T.rgba("brass", 0.6))
            b:SetBackdropBorderColor(T.rgba("brass"))
            if fs then fs:SetTextColor(T.rgba("locked")) end
        end
    else
        local danger = style == "danger"
        b.fill:SetColorTexture(T.rgba(hover and "cardHover" or "card"))
        local border = not enabled and "brass" or hover and (danger and "loss" or "bronze") or (danger and "loss" or "brass")
        b:SetBackdropBorderColor(T.rgba(border, not enabled and 1 or (hover and 1 or 0.8)))
        if fs then
            if not enabled then fs:SetTextColor(T.rgba("locked"))
            elseif danger then fs:SetTextColor(T.rgba("loss"))
            else fs:SetTextColor(T.rgba(hover and "bronzeLight" or "text")) end
        end
        if b.icon then b.icon:SetDesaturated(not enabled) end
    end
end
T.PaintButton = paintButton

-- style: "bronze" (the primary action, e.g. Craft), "ghost" (secondary, dark) or "danger" (dark, soft crimson).
-- icon: a texture path shown before the text.
local function makeButton(parent, text, w, h, style, icon)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 120, h or 22)
    b:SetBackdrop(BACKDROP)
    b:SetBackdropColor(0, 0, 0, 0)
    b.themeStyle = style
    b.fill = b:CreateTexture(nil, "BACKGROUND")
    b.fill:SetPoint("TOPLEFT", 1, -1)
    b.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    -- a bronze button's lower half a little darker: a soft forged bevel
    b.shade = b:CreateTexture(nil, "BORDER")
    b.shade:SetPoint("BOTTOMLEFT", b.fill, "BOTTOMLEFT")
    b.shade:SetPoint("TOPRIGHT", b.fill, "RIGHT")
    b.shade:SetColorTexture(0, 0, 0, 0.2)
    b.shade:SetShown(style == "bronze")
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    T.Font(fs, "body", nil, style ~= "bronze")
    fs:SetWordWrap(false)
    b:SetFontString(fs)
    fs:ClearAllPoints()
    if icon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize((h or 22) - 8, (h or 22) - 8)
        b.icon:SetPoint("LEFT", 6, 0)
        b.icon:SetTexture(icon)
        if icon:find("^Interface\\Icons\\") then b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        fs:SetPoint("LEFT", b.icon, "RIGHT", 5, 0)
        fs:SetPoint("RIGHT", -6, 0)
        fs:SetJustifyH("LEFT")
    else
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -6, 0)
        fs:SetJustifyH("CENTER")
    end
    if text then b:SetText(text) end
    b:HookScript("OnEnter", function(self) self.hovered = true; paintButton(self) end)
    b:HookScript("OnLeave", function(self) self.hovered = false; paintButton(self) end)
    b:HookScript("OnEnable", paintButton)
    b:HookScript("OnDisable", paintButton)
    b:HookScript("OnShow", paintButton)
    for _, method in ipairs({ "SetEnabled", "Enable", "Disable" }) do
        local original = b[method]
        b[method] = function(self, ...)
            original(self, ...)
            paintButton(self)
        end
    end
    paintButton(b)
    return b
end

function T.CreateBronzeButton(parent, text, w, h, icon) return makeButton(parent, text, w, h, "bronze", icon) end
function T.CreateGhostButton(parent, text, w, h, icon) return makeButton(parent, text, w, h, "ghost", icon) end
function T.CreateDangerButton(parent, text, w, h, icon) return makeButton(parent, text, w, h, "danger", icon) end

-- A double segmented control, e.g. [ Table | Detailed ]: two bronze-bordered halves, the selected one filled in
-- bronze. options = { { value =, text = }, { value =, text = } }. Returns { frame =, SetValue = function(value) }.
function T.CreateSegmentedToggle(parent, options, onChange)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetHeight(22)
    T.Style(frame, "iron", "brass")
    local segments, current = {}, nil
    local function paint()
        for _, seg in ipairs(segments) do
            local on = seg.value == current
            seg.fill:SetShown(on)
            seg.text:SetTextColor(T.rgba(on and "iron" or (seg.hovered and "bronzeLight" or "text")))
        end
    end
    for i, option in ipairs(options) do
        local seg = CreateFrame("Button", nil, frame)
        seg.fill = seg:CreateTexture(nil, "ARTWORK")
        seg.fill:SetAllPoints()
        seg.fill:SetColorTexture(T.rgba("bronze"))
        seg.text = T.Text(seg, "body")
        seg.text:SetPoint("CENTER")
        seg.text:SetText(option.text)
        seg.value = option.value
        seg:SetScript("OnEnter", function(self) self.hovered = true; paint() end)
        seg:SetScript("OnLeave", function(self) self.hovered = false; paint() end)
        seg:SetScript("OnClick", function(self)
            if current == self.value then return end
            current = self.value
            paint()
            if onChange then onChange(current) end
        end)
        segments[i] = seg
    end
    -- lay the segments side by side, an even share each, with a thin divider between them
    for i, seg in ipairs(segments) do
        seg:ClearAllPoints()
        if i == 1 then
            seg:SetPoint("TOPLEFT", 1, -1)
        else
            seg:SetPoint("TOPLEFT", segments[i - 1], "TOPRIGHT", 1, 0)
        end
        seg:SetPoint("BOTTOM", 0, 1)
    end
    function frame.SetRelativeWidth(_, total)
        local each = (total - 2 - (#segments - 1)) / #segments
        for _, seg in ipairs(segments) do seg:SetWidth(each) end
    end
    frame:HookScript("OnSizeChanged", function(self) self:SetRelativeWidth(self:GetWidth()) end)
    function frame.SetValue(_, value)
        current = value
        paint()
    end
    paint()
    return frame
end

---------------------------------------------------------------------------------------------------------- bars

-- A metallic skill bar: a dark track and a beveled fill (tinted by SetVertexColor so one texture serves blue,
-- bronze/amber and emerald). :SetProgress(value, max) sets the fill and, with text = true, a centered label.
function T.CreateSkillBar(parent, h, withText)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetHeight(h or 13)
    T.Style(bar, "iron", "brass")
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("TOPLEFT", 1, -1)
    bar.fill:SetPoint("BOTTOMLEFT", 1, 1)
    bar.fill:SetColorTexture(1, 1, 1, 1) -- tinted by SetFillColor
    bar.fill:SetWidth(0.001)
    bar.value, bar.max = 0, 1
    function bar:SetFillColor(name, alpha)
        self.fill:SetColorTexture(T.rgba(name, alpha))
    end
    function bar:SetProgress(value, max)
        self.value, self.max = value or 0, (max and max > 0) and max or 1
        local share = math.max(0, math.min(1, self.value / self.max))
        local w = (self:GetWidth() or 0) - 2
        self.fill:SetWidth(math.max(0.001, w * share))
    end
    bar:SetScript("OnSizeChanged", function(self) self:SetProgress(self.value, self.max) end)
    bar:SetFillColor("bronze")
    if withText then
        bar.label = T.Text(bar, "small", "text")
        bar.label:SetPoint("CENTER")
        function bar:SetLabel(s) self.label:SetText(s) end
    end
    return bar
end

---------------------------------------------------------------------------------------------------------- misc

-- A left accent bar (3px, emerald by default): the "You can craft now" / in-stock treatment of the style book.
function T.CreateAccentBar(parent, color, w)
    local bar = parent:CreateTexture(nil, "ARTWORK")
    bar:SetColorTexture(T.rgba(color or "profit"))
    bar:SetWidth(w or 3)
    return bar
end

-- A small border around an ingredient/component icon: emerald when `have`, dim crimson otherwise (material
-- availability, section 4.3 of the style book). Expects a BackdropTemplate frame around the icon.
function T.SetStockBorder(f, have)
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(T.rgba(have and "profit" or "loss", have and 1 or 0.6))
end
