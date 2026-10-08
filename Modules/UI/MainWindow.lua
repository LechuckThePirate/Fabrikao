local ADDON, ns = ...
local L = ns.L

-- The addon's window. First page: the character's professions (the ones it has, primary first, then First Aid,
-- Cooking and Fishing), with the game's own icons. Click one for its recipes: the ones the character knows
-- (colored by difficulty, with how many it can make from the bags) and, below, the ones it doesn't know, with
-- a search box and where each is learned.

local WIDTH, HEIGHT = 560, 600
local ROW_H = 24
local PROFESSION_H = 56

local frame, overview, page
local professionButtons, headerTexts = {}, {}
local rowButtons = {}
local state = { skillLine = nil, copy = nil, known = true, unknown = true, source = nil }

---------------------------------------------------------------------------------------------------
-- Overview: the professions
---------------------------------------------------------------------------------------------------
local function openProfession(profession)
    if ns.UI_ShowRecipes then ns.UI_ShowRecipes(profession) end
end

local function showProfessionTooltip(button)
    local p = button.profession
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(p.name, 1, 1, 1)
    GameTooltip:AddLine(L["Skill: %d / %d"]:format(p.rank, p.maxRank), 1, 0.82, 0)
    if p.hasRecipes then
        GameTooltip:AddLine(L["Click to see its recipes"], 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine(L["This profession has no recipes"], 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function newProfessionButton()
    local b = CreateFrame("Button", nil, overview)
    b:SetHeight(PROFESSION_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(44, 44)
    b.icon:SetPoint("LEFT", 6, 0)
    b.name = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 10, -2)
    b.bar = CreateFrame("StatusBar", nil, b)
    b.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    b.bar:SetHeight(14)
    b.bar:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", 10, 2)
    b.bar:SetPoint("RIGHT", -12, 0)
    local back = b.bar:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.5)
    b.barText = b.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.barText:SetPoint("CENTER")
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnClick", function(self) if self.profession.hasRecipes then openProfession(self.profession) end end)
    b:SetScript("OnEnter", showProfessionTooltip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    return b
end

local function newHeader()
    local text = overview:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetJustifyH("LEFT")
    local line = overview:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -2)
    line:SetPoint("RIGHT", overview, "RIGHT", -8, 0)
    text.line = line
    return text
end

local function refreshOverview()
    if not overview then return end
    for _, b in ipairs(professionButtons) do b:Hide() end
    for _, h in ipairs(headerTexts) do h:Hide(); h.line:Hide() end

    local list = ns.Professions_List()
    local y, nButton, nHeader, lastPrimary = 0, 0, 0, nil
    for _, profession in ipairs(list) do
        if profession.primary ~= lastPrimary then
            lastPrimary = profession.primary
            nHeader = nHeader + 1
            local h = headerTexts[nHeader] or newHeader()
            headerTexts[nHeader] = h
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", overview, "TOPLEFT", 8, -y - 2)
            h:SetText(profession.primary and L["Professions"] or L["Secondary professions"])
            h:Show()
            h.line:Show()
            y = y + 24
        end
        nButton = nButton + 1
        local b = professionButtons[nButton] or newProfessionButton()
        professionButtons[nButton] = b
        b.profession = profession
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", overview, "TOPLEFT", 0, -y)
        b:SetPoint("RIGHT", overview, "RIGHT", 0, 0)
        b.icon:SetTexture(profession.icon)
        b.icon:SetDesaturated(not profession.hasRecipes)
        b.name:SetText(profession.name)
        b.bar:SetMinMaxValues(0, math.max(1, profession.maxRank))
        b.bar:SetValue(profession.rank)
        local full = profession.maxRank > 0 and profession.rank >= profession.maxRank
        b.bar:SetStatusBarColor(full and 0.2 or 0.1, full and 0.7 or 0.4, full and 0.2 or 0.9)
        b.barText:SetText(profession.rank .. " / " .. profession.maxRank)
        b:SetAlpha(profession.hasRecipes and 1 or 0.6)
        b:Show()
        y = y + PROFESSION_H + 4
    end
    overview.empty:SetShown(#list == 0)
end

---------------------------------------------------------------------------------------------------
-- Recipes of one profession
---------------------------------------------------------------------------------------------------
local function setStatus(text)
    page.status:SetText(text or "")
    page.status:SetShown(text ~= nil)
end

local function showRecipeTooltip(row)
    local data = row.data
    if not data or data.kind ~= "recipe" then return end
    local recipe = data.recipe
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    local shown = recipe.link and pcall(GameTooltip.SetHyperlink, GameTooltip, recipe.link)
    if not shown then GameTooltip:SetText(recipe.name, 1, 1, 1) end
    if not recipe.learned then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Where to learn it"], 1, 0.82, 0)
        if recipe.sourceText and recipe.sourceText ~= "" then
            GameTooltip:AddLine(recipe.sourceText, 1, 1, 1, true)
        else
            GameTooltip:AddLine(ns.Recipes_SourceLabel(recipe.sourceType), 1, 1, 1)
        end
        if recipe.trivial and recipe.trivial > 0 then
            GameTooltip:AddLine(L["Turns grey at skill %d"]:format(recipe.trivial), 0.7, 0.7, 0.7)
        end
    end
    GameTooltip:Show()
end

local function newRow()
    local b = CreateFrame("Button", nil, page.content)
    b:SetHeight(ROW_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", 6, 0)
    b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.info:SetPoint("RIGHT", -8, 0)
    b.info:SetJustifyH("RIGHT")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", b.info, "LEFT", -8, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b:SetScript("OnEnter", showRecipeTooltip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        local data = self.data
        if data and data.kind == "recipe" and data.recipe.link and IsModifiedClick and IsModifiedClick("CHATLINK") then
            ChatEdit_InsertLink(data.recipe.link)
        end
    end)
    return b
end

local function renderRow(b, data)
    b.data = data
    if data.kind == "header" then
        b.icon:Hide()
        b.info:SetText("")
        b.text:SetText(("%s (%d)"):format(data.text, data.count))
        b.text:SetTextColor(1, 0.82, 0)
        b:EnableMouse(false)
        return
    end
    local recipe = data.recipe
    b:EnableMouse(true)
    b.icon:Show()
    b.icon:SetTexture(recipe.icon)
    if recipe.learned then
        local color = ns.DIFFICULTY_COLORS[recipe.difficulty or ns.DIFFICULTY_LAST]
        b.text:SetText(data.craftable > 0 and ("%s (%d)"):format(recipe.name, data.craftable) or recipe.name)
        b.text:SetTextColor(color[1], color[2], color[3])
        b.info:SetText("")
    else
        b.text:SetText(recipe.name)
        b.text:SetTextColor(0.85, 0.85, 0.85)
        b.info:SetText(ns.Recipes_SourceLabel(recipe.sourceType))
    end
end

local function refreshRecipes()
    if not (page and state.copy) then return end
    local rows = ns.Recipes_Rows(state.copy, {
        text = page.search:GetText(), known = state.known, unknown = state.unknown, source = state.source,
    })
    for i, data in ipairs(rows) do
        local b = rowButtons[i] or newRow()
        rowButtons[i] = b
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        b:SetPoint("RIGHT", page.content, "RIGHT", 0, 0)
        renderRow(b, data)
        b:Show()
    end
    for i = #rows + 1, #rowButtons do rowButtons[i]:Hide() end
    page.content:SetHeight(math.max(1, #rows * ROW_H))
    setStatus(#rows == 0 and L["No recipes match"] or nil)
    page.count:SetText(L["%d known, %d not known"]:format(#state.copy.known, #state.copy.unknown))
end

local function updateSourceButton()
    page.sourceButton:SetText(L["Source: %s"]:format(state.source and ns.Recipes_SourceLabel(state.source) or L["All"]))
end

-- All -> each source the profession's unknown recipes come from -> All
local function cycleSource()
    if not state.copy then return end
    local sources = {}
    for sourceType in pairs(state.copy.sources) do sources[#sources + 1] = sourceType end
    table.sort(sources)
    local nextSource
    if state.source == nil then
        nextSource = sources[1]
    else
        for i, s in ipairs(sources) do
            if s == state.source then nextSource = sources[i + 1] break end
        end
    end
    state.source = nextSource
    updateSourceButton()
    refreshRecipes()
end

local function createCheck(parent, label, key)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.text = check.Text or check.text
    if check.text then check.text:SetText(label) end
    check:SetChecked(state[key])
    check:SetScript("OnClick", function(self)
        state[key] = self:GetChecked() and true or false
        refreshRecipes()
    end)
    return check
end

local function createPage(parent, top)
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 12, -top)
    page:SetPoint("BOTTOMRIGHT", -12, 12)

    local back = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    back:SetSize(90, 22)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetText(L["< Professions"])
    back:SetScript("OnClick", function() ns.UI_ShowOverview() end)

    page.icon = page:CreateTexture(nil, "ARTWORK")
    page.icon:SetSize(26, 26)
    page.icon:SetPoint("LEFT", back, "RIGHT", 12, 0)
    page.title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.title:SetPoint("LEFT", page.icon, "RIGHT", 8, 0)
    page.rank = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.rank:SetPoint("TOPRIGHT", 0, -4)

    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 6, -10)
    search:SetPoint("RIGHT", page, "RIGHT", -6, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(60)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(L["Search recipes (name or where to learn them)..."])
    page.search = search
    local function updateHint() hint:SetShown(search:GetText() == "" and not search:HasFocus()) end
    search:SetScript("OnTextChanged", function() updateHint(); refreshRecipes() end)
    search:SetScript("OnEditFocusGained", updateHint)
    search:SetScript("OnEditFocusLost", updateHint)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    page.updateHint = updateHint

    local filters = CreateFrame("Frame", nil, page)
    filters:SetHeight(26)
    filters:SetPoint("TOPLEFT", search, "BOTTOMLEFT", -6, -4)
    filters:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    local known = createCheck(filters, L["Known"], "known")
    known:SetPoint("LEFT", 0, 0)
    local unknown = createCheck(filters, L["Not known"], "unknown")
    unknown:SetPoint("LEFT", known, "RIGHT", 70, 0)
    page.knownCheck, page.unknownCheck = known, unknown
    local sourceButton = CreateFrame("Button", nil, filters, "UIPanelButtonTemplate")
    sourceButton:SetSize(170, 22)
    sourceButton:SetPoint("RIGHT", 0, 0)
    sourceButton:SetScript("OnClick", cycleSource)
    page.sourceButton = sourceButton

    page.count = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.count:SetPoint("BOTTOMLEFT", 4, 0)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", filters, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 18)
    page.content = CreateFrame("Frame", nil, scroll)
    page.content:SetSize(WIDTH - 24 - 24, 1)
    scroll:SetScrollChild(page.content)
    page.scroll = scroll

    page.status = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.status:SetPoint("CENTER", scroll, "CENTER", 0, 20)
    page:Hide()
end

function ns.UI_ShowOverview()
    if not frame then return end
    state.skillLine, state.copy = nil, nil
    page:Hide()
    overview:Show()
    refreshOverview()
end

function ns.UI_ShowRecipes(profession)
    if not frame then return end
    local skillLine = profession.skillLine
    state.skillLine, state.source = skillLine, nil
    state.copy = ns.Recipes_Cached(skillLine)
    overview:Hide()
    page:Show()
    page.icon:SetTexture(profession.icon)
    page.title:SetText(profession.name)
    page.rank:SetText(L["Skill: %d / %d"]:format(profession.rank, profession.maxRank))
    page.search:SetText("")
    page.updateHint()
    updateSourceButton()
    if state.copy then
        refreshRecipes()
    else
        for _, b in ipairs(rowButtons) do b:Hide() end
        page.count:SetText("")
        setStatus(L["Reading recipes..."])
    end
    ns.Recipes_Request(skillLine, function(copy, reason)
        if state.skillLine ~= skillLine then return end -- went back, or to another profession
        if copy then
            state.copy = copy
            refreshRecipes()
        elseif not state.copy then
            setStatus(L["Could not read this profession's recipes."] .. (reason and ("\n(" .. reason .. ")") or ""))
        end
    end)
end

---------------------------------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------------------------------
local function saveGeometry()
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.char.window = { point = point, relPoint = relPoint, x = x, y = y }
end

local function createFrame()
    -- portrait frame like the other addons; if the client lacked the template, the older basic one
    local okPortrait, portraitFrame = pcall(CreateFrame, "Frame", "FabrikaoFrame", UIParent, "PortraitFrameFlatTemplate")
    local hasPortrait = okPortrait and portraitFrame and portraitFrame.SetPortraitToAsset ~= nil
    frame = okPortrait and portraitFrame or CreateFrame("Frame", "FabrikaoFrame", UIParent, "BasicFrameTemplateWithInset")
    local top = hasPortrait and 66 or 34 -- the portrait sticks out at the top left

    frame:SetSize(WIDTH, HEIGHT)
    local saved = ns.char.window
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    else
        frame:SetPoint("CENTER")
    end
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveGeometry()
    end)
    tinsert(UISpecialFrames, "FabrikaoFrame")
    frame:Hide()

    if hasPortrait then
        frame:SetPortraitToAsset("Interface\\AddOns\\" .. ADDON .. "\\Icons\\Fabrikao.png")
    end
    local title = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
    if title then title:SetText(("Fabrikao!! v%s"):format(ns.Version())) end

    overview = CreateFrame("Frame", nil, frame)
    overview:SetPoint("TOPLEFT", 12, -top)
    overview:SetPoint("BOTTOMRIGHT", -12, 12)
    overview.empty = overview:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    overview.empty:SetPoint("TOP", 0, -40)
    overview.empty:SetText(L["No professions learned yet."])
    overview.empty:Hide()

    createPage(frame, top)

    frame:HookScript("OnShow", function()
        if state.skillLine then refreshRecipes() else refreshOverview() end
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("SKILL_LINES_CHANGED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", function(_, event)
        if not frame:IsShown() then return end
        if event == "BAG_UPDATE_DELAYED" then
            if state.skillLine then refreshRecipes() end
        elseif not state.skillLine then
            refreshOverview()
        end
    end)
end

function ns.UI_Toggle()
    if not frame then createFrame() end
    if frame:IsShown() then frame:Hide() else frame:Show() end
end

function ns.UI_Show()
    if not frame then createFrame() end
    frame:Show()
end

function ns.UI_Hide()
    if frame then frame:Hide() end
end
