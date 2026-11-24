local ADDON, ns = ...
local L = ns.L
local T = ns.Theme

-- The addon's window. First page: the start screen in four quadrants (Overview.lua): the character's professions, what it can learn,
-- what it can craft now and the trainers close by, under a search box and a button that lists the professions that are not learned
-- too. Click a profession for its recipes: the ones the character knows (colored by difficulty, with how many it can make from the bags)
-- and, below, the ones it doesn't know, with a search box, filters, sorting and two views to choose from (RecipeList.lua). The gear opens the preferences.
-- "Consolidate alts", the switch in the title bar, looks at every character of the account as one (Roster.lua).

local WIDTH, HEIGHT = 760, 620
local MIN_WIDTH, MIN_HEIGHT = 640, 420
local MAX_WIDTH, MAX_HEIGHT = 1600, 1200

local frame, overview, page
local state = { skillLine = nil, copy = nil, professionName = nil }

-- what the page filters by: kept for the next time (ns.char.filters)
local filters = {}
local collapsed = {} -- the groups of the list folded: { known = bool, unknown = bool }

local VIEW_NAMES = { "table", "detailed" }

---------------------------------------------------------------------------------------------------
-- Recipes of one profession
---------------------------------------------------------------------------------------------------
local function setStatus(text)
    page.status:SetText(text or "")
    page.status:SetShown(text ~= nil)
end

local function saveFilters()
    ns.char.filters = {
        canMake = filters.canMake, hideGrey = filters.hideGrey, alts = filters.alts,
        difficulty = filters.difficulty, skill = filters.skill, sort = filters.sort,
    }
end

local function loadFilters()
    local saved = ns.char.filters or {}
    local fold = ns.char.collapsed or {}
    collapsed.known, collapsed.unknown = fold.known and true or false, fold.unknown and true or false
    filters.canMake = saved.canMake and true or false
    filters.hideGrey = saved.hideGrey and true or false
    filters.alts = saved.alts and true or false
    filters.difficulty, filters.skill, filters.sort = saved.difficulty, saved.skill, saved.sort
    filters.source, filters.category = nil, nil -- depend on the profession: not kept
end

local function viewName()
    local view = ns.char.view
    for _, name in ipairs(VIEW_NAMES) do if name == view then return view end end
    return "table" -- also what an older version's "list" becomes
end

local function updateControls()
    page.filterBar.Update()
    page.viewToggle:SetValue(viewName())
end

local function refreshRecipes()
    if not (page and state.copy) then return end
    local rows = ns.Recipes_Rows(state.copy, {
        text = page.search:GetText(), known = true, unknown = true, source = filters.source, category = filters.category,
        difficulty = filters.difficulty, canMake = filters.canMake, hideGrey = filters.hideGrey, skill = filters.skill,
        sort = filters.sort, collapsed = collapsed, alts = filters.alts and ns.Inventory_Available and ns.Inventory_Available(),
    })
    ns.RecipeList_Set(rows, viewName(), filters.sort, state.copy.rank)
    local shown = 0
    for _, row in ipairs(rows) do if row.kind == "recipe" then shown = shown + 1 end end
    local none = #state.copy.known + #state.copy.unknown == 0
    setStatus(shown == 0 and (none and L["This profession has no recipes"] or L["No recipes match"]) or nil)
    page.count:SetText(L["%d shown, %d known, %d not known"]:format(shown, #state.copy.known, #state.copy.unknown))
    updateControls()
end

local function changed()
    saveFilters()
    refreshRecipes()
end

-- a click on the title of a group: folds or unfolds it, and remembers it
local function toggleGroup(group)
    collapsed[group] = not collapsed[group]
    ns.char.collapsed = { known = collapsed.known, unknown = collapsed.unknown }
    refreshRecipes()
end

-- a click on a column title of the table
local function sortBy(key)
    ns.FilterBar_SortBy(filters, key)
    changed()
end

-- a click on a recipe: its panel opens next to the window
local function selectRecipe(data)
    local profession = state.skillLine and ns.Professions_Get(state.skillLine)
    ns.RecipeDetail_Show(data.recipe, {
        parent = frame, alts = data.alts, rank = state.copy and state.copy.rank,
        owner = profession and profession.owner, -- (the skill is an alt's: a profession only alts have, "Consolidate alts")
        onClose = function() ns.RecipeList_Select(nil) end,
    })
    ns.RecipeList_Select(data.recipe.id)
end

-- The list of recipes is shared with the search page: this page takes it back (at creation, and whenever it shows).
function ns.MainWindow_TakeList()
    local list = ns.RecipeList_Attach(page, sortBy, toggleGroup, selectRecipe)
    ns.RecipeList_Place(function(withBar)
        local right = withBar and -24 or -4 -- (the room of the bar goes to the rows when it is not there)
        list.header:ClearAllPoints()
        list.header:SetPoint("TOPLEFT", page.filterBar.buttons, "BOTTOMLEFT", 0, -4)
        list.header:SetPoint("RIGHT", page, "RIGHT", right, 0)
        list.scroll:ClearAllPoints()
        list.scroll:SetPoint("TOPLEFT", list.header, "BOTTOMLEFT", 0, -2)
        list.scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", right, 18)
    end)
end

local function createPage(parent, top)
    loadFilters()
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 12, -top)
    page:SetPoint("BOTTOMRIGHT", -12, 12)

    -- the style book's per-profession backdrop, faint behind the recipe list (ns.UI_ShowRecipes sets it)
    page.background = page:CreateTexture(nil, "BACKGROUND")
    page.background:SetAllPoints()
    page.background:SetAlpha(0.16)

    local back = T.CreateGhostButton(page, L["< Professions"], 90, 22)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetScript("OnClick", function() ns.UI_ShowOverview() end)

    page.icon = page:CreateTexture(nil, "ARTWORK")
    page.icon:SetSize(26, 26)
    page.icon:SetPoint("LEFT", back, "RIGHT", 12, 0)
    page.title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.title:SetPoint("LEFT", page.icon, "RIGHT", 8, 0)
    T.Font(page.title, "title", "bronze")
    page.rank = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.rank:SetPoint("TOPRIGHT", 0, -4)
    T.Font(page.rank, "body", "text")
    -- said on the page itself when the recipes are the whole account's ("Consolidate alts")
    page.accountBanner = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.accountBanner:SetPoint("TOPRIGHT", page.rank, "BOTTOMRIGHT", 0, -2)
    T.Font(page.accountBanner, "small", "profit")
    page.accountBanner:Hide()

    -- the profession's trainers, nearest first, in a panel next to the window (Trainers.lua)
    page.trainersButton = T.CreateGhostButton(page, L["Trainers"], 96, 22)
    page.trainersButton:SetPoint("RIGHT", page.rank, "LEFT", -14, 0)
    page.trainersButton:SetScript("OnClick", function()
        if state.skillLine then ns.Trainers_Toggle(state.skillLine, state.professionName, state.nextRank) end
    end)
    page.trainersButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["Trainers"], 1, 1, 1)
        GameTooltip:AddLine(L["The trainers of this profession, nearest first, with the map and a waypoint."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    page.trainersButton:SetScript("OnLeave", GameTooltip_Hide)

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

    -- the filters and sorting (FilterBar.lua), with the view on the right of the first row
    page.filterBar = ns.FilterBar_Create(page, search, {
        filters = filters,
        sources = function() return state.copy and state.copy.sources or {} end,
        categories = function() return state.copy and state.copy.categories or {} end,
        onChange = function() saveFilters(); refreshRecipes() end,
        onClear = function()
            page.search:SetText("")
            page.updateHint()
        end,
    })
    -- the segmented [ Table | Detailed ] switch, replacing the style book's flagged "View: Table" red button
    page.viewToggle = T.CreateSegmentedToggle(page.filterBar.checks, { { value = "table", text = L["Table"] },
        { value = "detailed", text = L["Detailed"] } }, function(view)
        ns.char.view = view
        refreshRecipes()
    end)
    page.viewToggle:SetSize(130, 22)
    page.viewToggle:SetPoint("RIGHT", page.filterBar.clearButton, "LEFT", -6, 0)

    page.count = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.count:SetPoint("BOTTOMLEFT", 4, 0)

    local list = ns.RecipeList_Create(page, sortBy, toggleGroup, selectRecipe)
    page.scroll, page.content = list.scroll, list.content
    ns.MainWindow_TakeList()

    page.status = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.status:SetPoint("CENTER", list.scroll, "CENTER", 0, 20)
    page:Hide()
end

function ns.UI_ShowOverview()
    if not frame then return end
    ns.RecipeDetail_Hide()
    ns.Trainers_Hide()
    state.skillLine, state.copy, state.professionName, state.nextRank = nil, nil, nil, nil
    page:Hide()
    ns.SearchPage_Hide()
    overview:Show()
    ns.Overview_Refresh()
end

function ns.UI_ShowRecipes(profession)
    if not frame then return end
    local skillLine = profession.skillLine
    ns.RecipeDetail_Hide()
    if ns.Trainers_Current() ~= skillLine then ns.Trainers_Hide() end -- (its panel is of the profession before)
    state.skillLine, state.professionName, filters.source, filters.category = skillLine, profession.name, nil, nil
    state.copy = ns.Recipes_Cached(skillLine)
    overview:Hide()
    ns.SearchPage_Hide()
    ns.MainWindow_TakeList()
    page:Show()
    page.icon:SetTexture(profession.icon)
    page.title:SetText(profession.name)
    page.background:SetTexture(T.ProfessionBackground(skillLine))
    state.nextRank = ns.Professions_NextRank(profession)
    if profession.learned == false then
        page.rank:SetText(L["Not learned"])
    else
        local text = L["Skill: %d / %d"]:format(profession.rank, profession.maxRank)
        local notice = ns.Professions_Notice(profession)
        if notice then text = text .. "  |cff40ff40" .. notice .. "|r" end
        page.rank:SetText(text)
    end
    -- the whole account: the recipes any character knows are known, the skill is the one of the character named
    if ns.Consolidated() then
        page.accountBanner:SetText(profession.owner and L["All your characters (skill of %s)"]:format(ns.Roster_NameOf(profession.owner))
            or L["All your characters"])
    end
    page.accountBanner:SetShown(ns.Consolidated())
    page.search:SetText("")
    page.updateHint()
    updateControls()
    ns.Recipes_Request(skillLine, function(copy, reason)
        if state.skillLine ~= skillLine then return end -- went back, or to another profession
        if copy then
            state.copy = copy
            refreshRecipes()
        elseif not state.copy then
            setStatus(L["Could not read this profession's recipes."] .. (reason and ("\n(" .. reason .. ")") or ""))
        end
    end, { rank = profession.learned ~= false and profession.rank or nil, name = profession.name })
end

---------------------------------------------------------------------------------------------------
-- Consolidate alts
---------------------------------------------------------------------------------------------------
-- The switch was flipped: whatever page is open is drawn again for the whole account, or for the playing character again (a
-- profession only an alt has goes back to the start screen).
function ns.UI_ConsolidatedChanged()
    if not frame then return end
    frame.consolidateSwitch.Update()
    ns.RecipeDetail_Hide()
    if state.skillLine then
        local profession = ns.Professions_Get(state.skillLine)
        if profession then ns.UI_ShowRecipes(profession) else ns.UI_ShowOverview() end
    elseif overview:IsShown() then
        ns.Overview_Refresh()
    else
        ns.SearchPage_Refresh()
    end
end

---------------------------------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------------------------------
local function saveGeometry()
    local point, _, relPoint, x, y = frame:GetPoint()
    ns.char.window = { point = point, relPoint = relPoint, x = x, y = y, w = frame:GetWidth(), h = frame:GetHeight() }
end

local function relayout()
    ns.RecipeList_Relayout()
end

local function createFrame()
    -- portrait frame like the other addons; if the client lacked the template, the older basic one
    local okPortrait, portraitFrame = pcall(CreateFrame, "Frame", "FabrikaoFrame", UIParent, "PortraitFrameFlatTemplate")
    local hasPortrait = okPortrait and portraitFrame and portraitFrame.SetPortraitToAsset ~= nil
    frame = okPortrait and portraitFrame or CreateFrame("Frame", "FabrikaoFrame", UIParent, "BasicFrameTemplateWithInset")
    local top = hasPortrait and 66 or 34 -- the portrait sticks out at the top left

    local saved = ns.char.window
    frame:SetSize(saved and saved.w and math.max(MIN_WIDTH, saved.w) or WIDTH, saved and saved.h and math.max(MIN_HEIGHT, saved.h) or HEIGHT)
    if saved then
        frame:SetPoint(saved.point, UIParent, saved.relPoint, saved.x, saved.y)
    else
        frame:SetPoint("CENTER")
    end
    -- DIALOG (as Preferences.lua and Welcome.lua already use): "HIGH" let nameplates and world text show through
    -- the window and its children (the recipe panel, the trainers panel), since the game draws those above it
    frame:SetFrameStrata("DIALOG")
    -- raised above the other addons' windows when shown or clicked, with all its children: otherwise another
    -- window of the same strata draws its contents over this one's background
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT) end
    frame:SetScale(ns.char.scale or 1)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        saveGeometry()
    end)
    frame:HookScript("OnSizeChanged", relayout)
    tinsert(UISpecialFrames, "FabrikaoFrame")
    frame:Hide()

    -- the corner to resize from: Blizzard's own resize button where the client has it (as Embolsao's window), else a grip of ours
    local okResize, resizer = pcall(CreateFrame, "Button", nil, frame, "PanelResizeButtonTemplate")
    if okResize and resizer and resizer.Init then
        resizer:SetPoint("BOTTOMRIGHT", -4, 4)
        resizer:Init(frame, MIN_WIDTH, MIN_HEIGHT, MAX_WIDTH, MAX_HEIGHT)
        resizer:HookScript("OnMouseUp", function()
            saveGeometry()
            relayout()
        end)
        frame.grip = resizer
    else
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(16, 16)
        grip:SetPoint("BOTTOMRIGHT", -3, 3)
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
        grip:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            saveGeometry()
            relayout()
        end)
        frame.grip = grip
    end

    if hasPortrait then
        -- the style book's anvil medallion, replacing the plain circular icon
        frame:SetPortraitToAsset(T.MEDIA .. "FabrikaoMedallion.png")
    end
    -- the title plate (griffin wings on a bronze bar, as Completao!!'s own header): drawn over whatever Blizzard's
    -- own title text would say, since it carries the name and version itself
    local titleText = (frame.TitleContainer and frame.TitleContainer.TitleText) or frame.TitleText
    if titleText then titleText:SetText("") end
    local PLATE_H = 40
    local plate = frame:CreateTexture(nil, "ARTWORK")
    plate:SetTexture(T.MEDIA .. "TitlePlate.tga")
    plate:SetTexCoord(0, 1, 0, 106 / 128) -- the asset's own lower rim (meant for a parchment panel below it) is cropped off
    plate:SetSize(PLATE_H * 512 / 106, PLATE_H)
    plate:SetPoint("TOP", frame, "TOP", 0, -2)
    local title = T.Text(frame, "title", "bronzeLight")
    title:SetPoint("CENTER", plate, "CENTER", 0, 1)
    title:SetText(("Fabrikao!! v%s"):format(ns.Version()))

    -- the gear next to the X opens the preferences: our own icon, tinted gold
    local gear = CreateFrame("Button", nil, frame)
    gear:SetSize(20, 20)
    local closeButton = frame.CloseButton
    local level = frame:GetFrameLevel() + 10
    if frame.NineSlice then level = math.max(level, frame.NineSlice:GetFrameLevel() + 10) end -- Blizzard's border would cover it
    if closeButton then level = math.max(level, closeButton:GetFrameLevel()) end
    gear:SetFrameLevel(level)
    if closeButton then
        gear:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    else
        gear:SetPoint("TOPRIGHT", -32, -5)
    end
    local gearTexture = "Interface\\AddOns\\" .. ADDON .. "\\Icons\\Gear.png"
    gear:SetNormalTexture(gearTexture)
    gear:GetNormalTexture():SetVertexColor(0.95, 0.82, 0.3)
    gear:SetHighlightTexture(gearTexture, "ADD")
    gear:SetScript("OnClick", function() ns.Prefs_Toggle() end)
    gear:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["Preferences"])
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", GameTooltip_Hide)
    frame.gear = gear

    -- "Consolidate alts", left of the gear, as in Completao!!: an on/off switch (a track and a knob that slides to the right when on),
    -- for the whole addon, so it sits in the title bar
    local switch = CreateFrame("Button", nil, frame)
    switch:SetSize(30, 14)
    switch:SetFrameLevel(level)
    switch:SetPoint("RIGHT", gear, "LEFT", -8, 0)
    local track = switch:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    local knob = switch:CreateTexture(nil, "ARTWORK")
    knob:SetSize(12, 12)
    knob:SetColorTexture(0.95, 0.95, 0.95, 1)
    local switchLabel = switch:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    switchLabel:SetPoint("RIGHT", switch, "LEFT", -5, 0)
    switchLabel:SetText(L["Consolidate alts"])
    function switch.Update()
        local on = ns.Consolidated()
        switch.on = on
        track:SetColorTexture(T.rgba(on and "bronze" or "iron"))
        knob:ClearAllPoints()
        knob:SetPoint(on and "RIGHT" or "LEFT", on and -1 or 1, 0)
        switchLabel:SetTextColor(T.rgba(on and "bronzeLight" or "muted"))
    end
    switch:SetScript("OnClick", function()
        ns.SetConsolidated(not ns.Consolidated())
    end)
    switch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(L["Consolidate alts"])
        for _, line in ipairs({
            L["Looks at all your characters as one: a recipe any of them knows counts as known, and the professions of all of them are listed."],
            L["The start screen shows what each of them can learn and craft now (with their bags, from Embolsao!!); only the character you play crafts."],
            L["Only the characters of the same realm go together. Each one is remembered once it logs in."],
        }) do
            GameTooltip:AddLine(line, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    switch:SetScript("OnLeave", GameTooltip_Hide)
    switch.Update()
    frame.consolidateSwitch = switch

    overview = ns.Overview_Create(frame, top)

    createPage(frame, top)
    ns.SearchPage_Create(frame, top)

    frame:HookScript("OnShow", function()
        if state.skillLine then refreshRecipes() else ns.Overview_Refresh() end
    end)
    local events = CreateFrame("Frame")
    events:RegisterEvent("SKILL_LINES_CHANGED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", function(_, event)
        if not frame:IsShown() then return end
        if event == "BAG_UPDATE_DELAYED" then
            if state.skillLine then refreshRecipes() elseif overview:IsShown() then ns.Overview_LayoutCraft() end
        elseif not state.skillLine then
            ns.Overview_Refresh()
        end
    end)
end

-- the search page of every recipe in the data, optionally starting with a text, or with the recipes that use an item
-- (ingredient) or make one (product)
function ns.UI_ShowSearch(text, ingredient, product)
    ns.UI_Show()
    ns.RecipeDetail_Hide()
    ns.Trainers_Hide()
    state.skillLine, state.copy, state.professionName = nil, nil, nil
    overview:Hide()
    page:Hide()
    ns.SearchPage_Show(text, ingredient, product)
end

-- Draws again what the window shows, from the data as it is now (a recipe was learned, the skill went up...): the recipes of the open
-- profession are asked for again, keeping its filters and search.
function ns.UI_Refresh()
    if not (frame and frame:IsShown()) then return end
    local skillLine = state.skillLine
    if not skillLine then
        ns.Overview_Refresh()
        return
    end
    local profession = ns.Professions_Get(skillLine)
    ns.Recipes_Request(skillLine, function(copy)
        if state.skillLine == skillLine and copy then
            state.copy = copy
            refreshRecipes()
        end
    end, { rank = profession and profession.learned ~= false and profession.rank or nil, name = profession and profession.name })
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

-- After a preference changed (scale, view) or the settings were reset: the window follows.
function ns.UI_ApplySettings()
    if not frame then return end
    frame:SetScale(ns.char.scale or 1)
    loadFilters()
    if state.skillLine then
        updateControls()
        refreshRecipes()
    else
        ns.Overview_Refresh() -- what it shows depends on settings too (the groups folded, the professions not learned)
    end
end

-- Window back to its default place and size.
function ns.UI_ResetWindow()
    ns.char.window = nil
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    frame:SetSize(WIDTH, HEIGHT)
    relayout()
end

-- Filters back to nothing filtered.
function ns.UI_ResetFilters()
    ns.char.filters, ns.char.searchFilters = nil, nil
    loadFilters()
    if page and state.skillLine then
        page.search:SetText("")
        page.updateHint()
        refreshRecipes()
    end
    ns.SearchPage_ResetFilters()
end
