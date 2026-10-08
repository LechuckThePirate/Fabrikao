local _, ns = ...
local L = ns.L

-- Preferences window (opened with the main window's gear). Basic settings, in ns.char: per character or shared by
-- the account, depending on the first checkbox, as in the other addons.
local WIDTH, HEIGHT = 360, 470
local LABEL_W = WIDTH - 48 - 16 -- a checkbox's text: from after the box (x = 48) to the window's right margin
local prefs

local VIEWS = {
    { key = "list", text = "List (one line per recipe)" },
    { key = "table", text = "Table (columns: components, cost, value, level)" },
    { key = "detailed", text = "Detailed (big icon, three lines)" },
}

local function makeCheck(parent, y, text, getValue, setValue)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", 20, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    -- a long text (or a longer translation) wraps to a second line instead of running out of the window
    label:SetWidth(LABEL_W)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(true)
    label:SetText(text)
    check:SetScript("OnClick", function(self) setValue(self:GetChecked() and true or false) end)
    function check.Refresh() check:SetChecked(getValue() and true or false) end
    return check
end

local function makeSlider(parent, y, getValue, setValue, labelFor)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("TOPLEFT", 24, y)

    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(300, 16)
    slider:SetPoint("TOPLEFT", 28, y - 24)
    slider:SetMinMaxValues(0.7, 1.3)
    slider:SetValueStep(0.05)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    local bar = slider:CreateTexture(nil, "BACKGROUND")
    bar:SetPoint("LEFT", 0, 0)
    bar:SetPoint("RIGHT", 0, 0)
    bar:SetHeight(4)
    bar:SetColorTexture(1, 1, 1, 0.25)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(20, 20)

    local refreshing = false
    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value * 20 + 0.5) / 20 -- in 5 % steps
        label:SetText(labelFor(value))
        if not refreshing then setValue(value) end
    end)
    function slider.Refresh()
        refreshing = true
        local value = getValue()
        slider:SetValue(value)
        label:SetText(labelFor(value))
        refreshing = false
    end
    return slider
end

local function makeButton(parent, y, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(WIDTH - 48, 24)
    button:SetPoint("TOPLEFT", 24, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function create()
    prefs = CreateFrame("Frame", "FabrikaoPreferencesFrame", UIParent, "BackdropTemplate")
    prefs:SetSize(WIDTH, HEIGHT)
    prefs:SetPoint("CENTER")
    prefs:SetFrameStrata("DIALOG")
    prefs:SetClampedToScreen(true)
    prefs:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    prefs:SetBackdropColor(0, 0, 0, 0.9)
    prefs:SetMovable(true)
    prefs:EnableMouse(true)
    prefs:RegisterForDrag("LeftButton")
    prefs:SetScript("OnDragStart", prefs.StartMoving)
    prefs:SetScript("OnDragStop", prefs.StopMovingOrSizing)
    tinsert(UISpecialFrames, "FabrikaoPreferencesFrame")

    local okClose, close = pcall(CreateFrame, "Button", nil, prefs, "UIPanelCloseButtonDefaultAnchors")
    if not okClose or not close then
        close = CreateFrame("Button", nil, prefs, "UIPanelCloseButton")
    end
    close:SetPoint("TOPRIGHT", -2, -2)

    local title = prefs:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText(L["Fabrikao!! Preferences"])

    local widgets = {}
    local note = prefs:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    note:SetPoint("BOTTOM", 0, 16)
    local function refreshAll()
        for _, widget in ipairs(widgets) do widget.Refresh() end
        note:SetText(ns.IsPerCharacter() and L["Settings are saved for this character only."]
            or L["Settings are shared by all your characters."])
    end
    prefs.refreshAll = refreshAll

    -- decides where everything below is kept (Modules/Settings, ns.SetPerCharacter)
    widgets[#widgets + 1] = makeCheck(prefs, -48, L["Character specific preferences"],
        function() return ns.IsPerCharacter() end,
        function(value)
            ns.SetPerCharacter(value)
            if ns.UI_ApplySettings then ns.UI_ApplySettings() end
            refreshAll()
        end)

    -- the view of the recipe lists: one checkbox per view, always exactly one on
    local heading = prefs:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", 24, -84)
    heading:SetText(L["View of the recipes"])
    prefs.viewChecks = {}
    for i, view in ipairs(VIEWS) do
        local check = makeCheck(prefs, -84 - i * 28, L[view.text],
            function() return (ns.char.view or "list") == view.key end,
            function()
                ns.char.view = view.key
                if ns.UI_ApplySettings then ns.UI_ApplySettings() end
                refreshAll()
            end)
        widgets[#widgets + 1] = check
        prefs.viewChecks[view.key] = check
    end

    widgets[#widgets + 1] = makeSlider(prefs, -204,
        function() return ns.char.scale or 1 end,
        function(value)
            ns.char.scale = value
            if ns.UI_ApplySettings then ns.UI_ApplySettings() end
        end,
        function(value) return L["Window scale: %d%%"]:format(math.floor(value * 100 + 0.5)) end)
    prefs.scaleSlider = widgets[#widgets]

    widgets[#widgets + 1] = makeCheck(prefs, -256, L["Show the minimap button"],
        function() return ns.Minimap_IsShown() end,
        function(value) ns.Minimap_SetShown(value) end)

    widgets[#widgets + 1] = makeCheck(prefs, -284, L["Show chat messages at startup"],
        function() return not ns.char.quiet end,
        function(value) ns.char.quiet = (not value) or nil end)

    local prices = prefs:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    prices:SetPoint("TOPLEFT", 24, -320)
    prices:SetWidth(WIDTH - 48)
    prices:SetJustifyH("LEFT")
    prefs.prices = prices

    makeButton(prefs, -358, L["Reset window position and size"], function() ns.UI_ResetWindow() end)
    makeButton(prefs, -388, L["Reset filters"], function() ns.UI_ResetFilters() end)
    makeButton(prefs, -418, L["Restore default preferences"], function()
        ns.ResetSettings()
        refreshAll()
    end)

    prefs:SetScript("OnShow", function()
        refreshAll()
        prices:SetText(ns.Prices_HasAuctionData() and L["Prices: Auctionator found (auction prices are used)."]
            or L["Prices: Auctionator not found (costs use what vendors pay, there is no auction value)."])
    end)
    prefs:Hide() -- frames are born shown: hidden until the first Prefs_Toggle (which would close it otherwise)
end

function ns.Prefs_Toggle()
    if not prefs then create() end
    prefs:SetShown(not prefs:IsShown())
end
