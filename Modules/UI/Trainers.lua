local _, ns = ...
local L = ns.L

-- The trainers of a profession, nearest first, in a panel next to the main window (the same place as a recipe's panel, which it
-- replaces). Each one has the buttons that show it on the map and set a TomTom waypoint, as the trainers in a recipe's panel do.
--   ns.Trainers_Toggle(skillLine, professionName)   opens the panel for the profession, or closes it when it is that one's already
--   ns.Trainers_Show(skillLine, professionName)     opens it (or fills it again: the distances are read each time)
--   ns.Trainers_Hide(), ns.Trainers_Current()       closes it; the skill line it shows, nil when closed

local WIDTH = 440
local MARGIN = 22
local SCROLL_W = 28
local TEXT_W = WIDTH - MARGIN - SCROLL_W - 6
local MAX_TRAINERS = 40
local DIM, GOLD = "|cff9a9a9a", "|cffffd100"

local panel
local current -- { skillLine =, name = }
local rows = {}

local function newRow()
    local row = CreateFrame("Frame", nil, panel.child)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.text:SetPoint("TOPLEFT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetJustifyV("TOP")
    row.text:SetWordWrap(true)
    local function button(text, width, tooltip, action)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetText(text)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:AddLine(self.npc.name, 1, 0.82, 0)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        b:SetScript("OnClick", function(self) action(self.npc) end)
        return b
    end
    -- (the same actions as the trainers of a recipe's panel)
    row.tomButton = button("TomTom", 66, L["Set a TomTom waypoint"], function(npc) return ns.RecipeDetail_Waypoint(npc) end)
    row.tomButton:SetPoint("TOPRIGHT", 0, 0)
    row.mapButton = button(L["Map"], 52, L["View on map"], function(npc) return ns.RecipeDetail_ViewOnMap(npc) end)
    return row
end

local function render()
    if not (panel and current) then return end
    for _, row in ipairs(rows) do row:Hide() end
    panel.title:SetText(L["%s trainers"]:format(current.name or ""))

    local trainers, total = ns.RecipeDB_Trainers(current.skillLine, MAX_TRAINERS)
    panel.empty:SetShown(#trainers == 0)
    panel.subtitle:SetText(#trainers > 0 and L["Nearest first"] or "")

    local withTomTom = ns.Map_HasTomTom and ns.Map_HasTomTom()
    local y = 4
    for i, trainer in ipairs(trainers) do
        local row = rows[i] or newRow()
        rows[i] = row
        local spot = trainer.id and ns.RecipeDB_NpcLocation(trainer.id)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
        row:SetWidth(TEXT_W)
        row.text:SetWidth(TEXT_W - (spot and (withTomTom and 130 or 64) or 0))
        local lines = { GOLD .. trainer.name .. "|r" }
        if trainer.title and trainer.title ~= "" then lines[1] = lines[1] .. " " .. DIM .. "<" .. trainer.title .. ">|r" end
        local where = {}
        if trainer.zones and trainer.zones ~= "" then where[#where + 1] = trainer.zones end
        local distance = trainer.distance and ns.Map_FormatDistance and ns.Map_FormatDistance(trainer.distance)
        if distance and distance ~= "" then where[#where + 1] = distance end
        if #where > 0 then lines[#lines + 1] = DIM .. table.concat(where, "  -  ") .. "|r" end
        row.text:SetText(table.concat(lines, "\n"))
        row.tomButton.npc, row.mapButton.npc = trainer, trainer
        row.tomButton:SetShown(spot ~= nil and withTomTom and true or false)
        row.mapButton:ClearAllPoints()
        row.mapButton:SetPoint("TOPRIGHT", withTomTom and -72 or 0, 0)
        row.mapButton:SetShown(spot ~= nil)
        local height = math.max(row.text:GetStringHeight(), spot and 22 or 0)
        row:SetHeight(height)
        row:Show()
        y = y + height + 10
    end
    if total > #trainers then
        panel.more:SetText(L["and %d more"]:format(total - #trainers))
        panel.more:ClearAllPoints()
        panel.more:SetPoint("TOPLEFT", panel.child, "TOPLEFT", 0, -y)
        panel.more:Show()
        y = y + 20
    else
        panel.more:Hide()
    end
    panel.child:SetHeight(math.max(1, y + 8))
    panel.scroll:SetVerticalScroll(0)
end

local function create(parent)
    panel = CreateFrame("Frame", "FabrikaoTrainersFrame", UIParent, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetFrameStrata(parent:GetFrameStrata())
    parent:HookScript("OnHide", function() ns.Trainers_Hide() end) -- it goes away with the window
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    panel:SetBackdropColor(0.05, 0.05, 0.07, 1)
    panel:SetToplevel(true)
    panel:EnableMouse(true) -- clicks must not fall through to what is behind it

    local okClose, close = pcall(CreateFrame, "Button", nil, panel, "UIPanelCloseButtonDefaultAnchors")
    if not okClose or not close then close = CreateFrame("Button", nil, panel, "UIPanelCloseButton") end
    close:SetPoint("TOPRIGHT", -6, -6)

    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", MARGIN, -MARGIN)
    panel.title:SetPoint("RIGHT", panel, "RIGHT", -MARGIN - 24, 0)
    panel.title:SetJustifyH("LEFT")
    panel.subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -6)
    panel.subtitle:SetTextColor(0.7, 0.7, 0.7)

    local separator = panel:CreateTexture(nil, "ARTWORK")
    separator:SetPoint("TOPLEFT", panel, "TOPLEFT", MARGIN, -(MARGIN + 52))
    separator:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
    separator:SetHeight(1)
    separator:SetColorTexture(1, 0.82, 0, 0.5)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    panel.scroll:SetPoint("TOPLEFT", MARGIN, -(MARGIN + 62))
    panel.scroll:SetPoint("BOTTOMRIGHT", -SCROLL_W, MARGIN)
    panel.child = CreateFrame("Frame", nil, panel.scroll)
    panel.child:SetSize(TEXT_W, 1)
    panel.scroll:SetScrollChild(panel.child)

    panel.empty = panel.child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.empty:SetPoint("TOPLEFT", 0, -8)
    panel.empty:SetText(L["No trainers known for this profession."])
    panel.empty:Hide()
    panel.more = panel.child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.more:Hide()

    panel:SetScript("OnHide", function() current = nil end)
    tinsert(UISpecialFrames, "FabrikaoTrainersFrame")
    panel:Hide()
end

-- Docks the panel to the window's right side, or to its left when there is no room on the right (as a recipe's panel).
local function dock(window)
    panel:ClearAllPoints()
    local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local room = (UIParent:GetRight() or 0) - (window:GetRight() or 0) * scale
    if room >= WIDTH * scale or (window:GetLeft() or 0) * scale < WIDTH * scale then
        panel:SetPoint("TOPLEFT", window, "TOPRIGHT", -4, 0)
        panel:SetPoint("BOTTOMLEFT", window, "BOTTOMRIGHT", -4, 0)
    else
        panel:SetPoint("TOPRIGHT", window, "TOPLEFT", 4, 0)
        panel:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 4, 0)
    end
end

function ns.Trainers_Show(skillLine, name)
    local window = _G.FabrikaoFrame
    if not (window and skillLine) then return end
    if not panel then create(window) end
    -- it takes the place of a recipe's panel
    if ns.RecipeDetail_Hide then ns.RecipeDetail_Hide() end
    if ns.RecipeList_Select then ns.RecipeList_Select(nil) end
    panel:SetScale(window:GetScale())
    dock(window)
    current = { skillLine = skillLine, name = name }
    render()
    panel:Show()
end

function ns.Trainers_Hide()
    if panel and panel:IsShown() then panel:Hide() end
    current = nil
end

function ns.Trainers_Current()
    return panel and panel:IsShown() and current and current.skillLine or nil
end

function ns.Trainers_Toggle(skillLine, name)
    if ns.Trainers_Current() == skillLine then
        ns.Trainers_Hide()
    else
        ns.Trainers_Show(skillLine, name)
    end
end
