local _, ns = ...
local L = ns.L

-- Page of the main window that searches every recipe in the game's data (also the ones of professions the
-- character doesn't have): the matches on the left, the selected one on the right with its skill levels, what
-- it makes, its ingredients (and how many the character has) and where to learn it.

local ROW_H = 24
local MAX_RESULTS = 300
local LIST_W = 330
local CHECK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local GOLD = "|cffffd100"

local page
local rowButtons = {}
local state = { skill = nil, results = {}, selected = nil, truncated = 0, sources = {} }
local filters = {} -- the filters of the page (FilterBar.lua), kept for the next time in ns.char.searchFilters

local function colorCode(color)
    return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

local knows = ns.RecipeDB_Known

-- skill line -> { rank, maxRank } of the character's professions
local function myProfessions()
    local mine = {}
    for _, p in ipairs(ns.Professions_List()) do mine[p.skillLine] = p end
    return mine
end

local iconOf = ns.RecipeDB_Icon

-- an item's name, or a placeholder while the client loads it (GET_ITEM_INFO_RECEIVED redraws)
local function itemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
    if name then return name end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
    return L["item %d"]:format(itemID)
end

local function itemCount(itemID)
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    return count(itemID, true) or 0
end

-- The detail of a recipe as text: returns its name and the body.
function ns.SearchPage_DetailText(spellID)
    local recipe = ns.RecipeDB_Get(spellID)
    if not recipe then return "", "" end
    local mine = myProfessions()[recipe.s]
    local lines = {}

    local status
    if knows(spellID) then
        status = CHECK .. " " .. L["You know this recipe"]
    elseif mine then
        status = L["You don't know this recipe yet"]
    else
        status = L["You don't have this profession"]
    end
    lines[#lines + 1] = ("%s%s|r %s  --  %s"):format(GOLD, L["Profession:"], ns.RecipeDB_SkillName(recipe.s), status)

    local required = ns.RecipeDB_Required(recipe)
    local skillLine = ("%s%s|r %d"):format(GOLD, L["Skill needed:"], required)
    if mine then
        local ok = mine.rank >= required
        skillLine = skillLine .. ("  (%s)"):format((ok and "|cff40bf40" or "|cffff4040") .. L["you have %d"]:format(mine.rank) .. "|r")
    end
    lines[#lines + 1] = skillLine

    local colors = ns.RecipeDB_Colors(recipe)
    if colors then
        lines[#lines + 1] = ("%s%s|r %s"):format(GOLD, L["Difficulty:"], ns.DifficultyColorsText(colors))
        if mine and mine.rank >= required then
            local d = ns.RecipeDB_Difficulty(recipe, mine.rank)
            local names = { [0] = L["orange"], L["yellow"], L["green"], L["grey"] }
            lines[#lines + 1] = ("%s%s|r %s%s|r"):format(GOLD, L["For your skill:"], colorCode(ns.DIFFICULTY_COLORS[d]), names[d])
        end
    end

    if recipe.p then
        local qty = recipe.p[2] == recipe.p[3] and tostring(recipe.p[2]) or ("%d-%d"):format(recipe.p[2], recipe.p[3])
        local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(recipe.p[1])
        lines[#lines + 1] = ("%s%s|r %s%s x%s"):format(GOLD, L["Makes:"], icon and ("|T" .. icon .. ":14|t ") or "", itemName(recipe.p[1]), qty)
    end

    if recipe.m and #recipe.m > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = GOLD .. L["Ingredients:"] .. "|r"
        for _, reagent in ipairs(recipe.m) do
            local itemID, needed = reagent[1], reagent[2]
            local have = itemCount(itemID)
            local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
            local others = ns.Inventory_OthersTotal and ns.Inventory_OthersTotal(itemID) or 0
            local extra = others > 0 and (", " .. L["+%d on other characters"]:format(others)) or ""
            lines[#lines + 1] = ("  %s%s x%d  (%s%s|r)"):format(icon and ("|T" .. icon .. ":14|t ") or "", itemName(itemID), needed,
                have >= needed and "|cff40bf40" or "|cffff4040", L["you have %d"]:format(have) .. extra)
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = GOLD .. L["Where to learn it"] .. "|r"
    for _, line in ipairs(ns.RecipeDB_Where(recipe)) do
        lines[#lines + 1] = ("  |cffffffff%s:|r %s"):format(line.title, line.text)
    end
    return recipe.n, table.concat(lines, "\n")
end

---------------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------------
local function renderDetail()
    if not (page and state.selected) then
        page.detailTitle:SetText("")
        page.detailText:SetText(state.truncated >= 0 and #state.results == 0 and L["Search by recipe, ingredient, NPC or zone."] or "")
        page.detailIcon:Hide()
        return
    end
    local id = state.selected
    local name, body = ns.SearchPage_DetailText(id)
    page.detailTitle:SetText(name)
    page.detailText:SetText(body)
    page.detailIcon.texture:SetTexture(iconOf(id, ns.RecipeDB_Get(id)))
    page.detailIcon.spellID = id
    page.detailIcon:Show()
    page.detailChild:SetHeight(math.max(1, page.detailText:GetStringHeight() + 8))
end

local function showRowTooltip(row)
    local recipe = row.recipe
    if not recipe then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(recipe.n, 1, 1, 1)
    GameTooltip:AddLine(ns.RecipeDB_SkillName(recipe.s), 1, 0.82, 0)
    local short = ns.RecipeDB_ShortSource(recipe)
    if short then GameTooltip:AddLine(short, 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end

local function selectRecipe(id)
    state.selected = id
    for _, b in ipairs(rowButtons) do b.selectedTexture:SetShown(b.spellID == id and b:IsShown()) end
    renderDetail()
end

local function newRow()
    local b = CreateFrame("Button", nil, page.content)
    b:SetHeight(ROW_H)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(20, 20)
    b.icon:SetPoint("LEFT", 4, 0)
    b.info = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.info:SetPoint("RIGHT", -6, 0)
    b.info:SetJustifyH("RIGHT")
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.text:SetPoint("RIGHT", b.info, "LEFT", -6, 0)
    b.text:SetJustifyH("LEFT")
    b.text:SetWordWrap(false)
    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    b.selectedTexture = b:CreateTexture(nil, "BACKGROUND")
    b.selectedTexture:SetAllPoints()
    b.selectedTexture:SetColorTexture(1, 0.82, 0, 0.18)
    b.selectedTexture:Hide()
    b:SetScript("OnEnter", showRowTooltip)
    b:SetScript("OnLeave", GameTooltip_Hide)
    local function onClick(self)
        selectRecipe(self.spellID)
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local product = self.recipe.p and self.recipe.p[1]
            local link = product and select(2, GetItemInfo(product)) or ("|cff71d5ff|Hspell:%d|h[%s]|h|r"):format(self.spellID, self.recipe.n)
            ChatEdit_InsertLink(link)
        end
    end
    b:SetScript("OnClick", onClick)
    -- over the icon: the tooltip of what the recipe makes
    b.iconButton = CreateFrame("Button", nil, b)
    b.iconButton:SetAllPoints(b.icon)
    b.iconButton:SetScript("OnEnter", function(self)
        if not ns.RecipeDB_ShowProductTooltip(self, b.spellID, b.recipe) then showRowTooltip(b) end
    end)
    b.iconButton:SetScript("OnLeave", GameTooltip_Hide)
    b.iconButton:SetScript("OnClick", function() onClick(b) end)
    return b
end

local function saveFilters()
    ns.char.searchFilters = {
        canMake = filters.canMake, hideGrey = filters.hideGrey, alts = filters.alts,
        difficulty = filters.difficulty, skill = filters.skill, sort = filters.sort,
    }
end

local function loadFilters()
    local saved = ns.char.searchFilters or {}
    filters.canMake = saved.canMake and true or false
    filters.hideGrey = saved.hideGrey and true or false
    filters.alts = saved.alts and true or false
    filters.difficulty, filters.skill, filters.sort = saved.difficulty, saved.skill, saved.sort
    filters.source = nil
end

-- every source code of the data, for the source filter before anything is listed
local allSources
local function sourcesOfAll()
    if not allSources then
        allSources = {}
        for _, recipe in ns.RecipeDB_Each() do
            for _, code in ipairs(ns.RecipeDB_Sources(recipe)) do allSources[code] = true end
        end
    end
    return allSources
end

local function refresh()
    if not page then return end
    local text = page.search:GetText()
    -- with filters on and no text, everything that passes them is listed
    local browse = state.skill ~= nil or ns.FilterBar_Active(filters)
    local found = ns.RecipeDB_Search(text, { skill = state.skill, all = browse })

    -- the recipes as the lists see them (known or not, colored for the character's skill in each profession), so the
    -- filters of the profession's page work here too
    local mine = myProfessions()
    local objects = {}
    state.sources = {}
    for _, result in ipairs(found) do
        local profession = mine[result.recipe.s]
        local object = ns.Recipes_FromRecord(result.id, result.recipe, knows(result.id), profession and profession.rank)
        objects[#objects + 1] = object
        if object.sourceType then state.sources[object.sourceType] = true end
    end
    if not browse then state.sources = sourcesOfAll() end
    local results = ns.Recipes_Rows({ all = objects }, {
        flat = true, source = filters.source, difficulty = filters.difficulty, canMake = filters.canMake,
        hideGrey = filters.hideGrey, skill = filters.skill, sort = filters.sort,
        alts = filters.alts and ns.Inventory_Available and ns.Inventory_Available(),
    })
    local total = #results
    state.truncated = math.max(0, total - MAX_RESULTS)
    for i = total, MAX_RESULTS + 1, -1 do results[i] = nil end
    state.results = results

    for i, row in ipairs(results) do
        local b = rowButtons[i] or newRow()
        rowButtons[i] = b
        local object = row.recipe
        b.spellID, b.recipe = object.id, object.db
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        b:SetPoint("RIGHT", page.content, "RIGHT", 0, 0)
        b.icon:SetTexture(object.icon)
        b.text:SetText(object.name)
        local color = { 0.9, 0.9, 0.9 }
        if object.learned then
            color = ns.DIFFICULTY_COLORS[object.difficulty or ns.DIFFICULTY_LAST]
        elseif object.rank and object.rank >= object.required then
            color = ns.DIFFICULTY_COLORS[ns.RecipeDB_Difficulty(object.db, object.rank)]
        end
        b.text:SetTextColor(color[1], color[2], color[3])
        b.info:SetText((object.learned and (CHECK .. " ") or "") .. ("%s %d"):format(ns.RecipeDB_SkillName(object.db.s), object.required))
        b:Show()
    end
    for i = #results + 1, #rowButtons do rowButtons[i]:Hide() end
    page.content:SetHeight(math.max(1, #results * ROW_H))

    local count
    if total == 0 then
        count = (text == "" and not browse) and L["Type to search every recipe."] or L["No recipes found"]
    elseif state.truncated > 0 then
        count = L["%d recipes (showing the first %d)"]:format(total, MAX_RESULTS)
    else
        count = L["%d recipes"]:format(total)
    end
    page.count:SetText(count)
    page.filterBar.Update()

    -- keep the selection if it is still in the list, else the first result
    local keep
    for _, row in ipairs(results) do if row.recipe.id == state.selected then keep = row.recipe.id end end
    selectRecipe(keep or (results[1] and results[1].recipe.id))
end

local function cycleSkill()
    local skills = ns.RecipeDB_Skills()
    local nextSkill
    if state.skill == nil then
        nextSkill = skills[1]
    else
        for i, skill in ipairs(skills) do
            if skill == state.skill then nextSkill = skills[i + 1] break end
        end
    end
    state.skill = nextSkill
    page.skillButton:SetText(L["Profession: %s"]:format(state.skill and ns.RecipeDB_SkillName(state.skill) or L["All"]))
    refresh()
end

function ns.SearchPage_Create(parent, top)
    page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT", 12, -top)
    page:SetPoint("BOTTOMRIGHT", -12, 12)

    local back = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    back:SetSize(90, 22)
    back:SetPoint("TOPLEFT", 0, 0)
    back:SetText(L["< Professions"])
    back:SetScript("OnClick", function() ns.UI_ShowOverview() end)

    local search = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    search:SetHeight(20)
    search:SetPoint("LEFT", back, "RIGHT", 14, 0)
    search:SetPoint("RIGHT", page, "RIGHT", -6, 0)
    search:SetAutoFocus(false)
    search:SetMaxLetters(60)
    local hint = search:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", 2, 0)
    hint:SetText(L["Search any recipe: name, ingredient, vendor, drop, zone..."])
    page.search = search
    local function updateHint() hint:SetShown(search:GetText() == "" and not search:HasFocus()) end
    page.updateHint = updateHint
    search:SetScript("OnTextChanged", function() updateHint(); refresh() end)
    search:SetScript("OnEditFocusGained", updateHint)
    search:SetScript("OnEditFocusLost", updateHint)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- the same filters and sorting as a profession's page (FilterBar.lua); the profession to look in goes on the right
    loadFilters()
    page.filterBar = ns.FilterBar_Create(page, back, {
        filters = filters, x = 0,
        sources = function() return state.sources end,
        onChange = function() saveFilters(); refresh() end,
    })
    local skillButton = CreateFrame("Button", nil, page.filterBar.checks, "UIPanelButtonTemplate")
    skillButton:SetSize(190, 22)
    skillButton:SetPoint("RIGHT", 0, 0)
    skillButton:SetText(L["Profession: %s"]:format(L["All"]))
    skillButton:SetScript("OnClick", cycleSkill)
    page.skillButton = skillButton

    page.count = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.count:SetPoint("BOTTOMLEFT", 4, 0)

    -- results, on the left
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page.filterBar.buttons, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOM", page, "BOTTOM", 0, 18)
    scroll:SetWidth(LIST_W)
    page.content = CreateFrame("Frame", nil, scroll)
    page.content:SetSize(LIST_W - 4, 1)
    scroll:SetScrollChild(page.content)
    page.scroll = scroll

    -- the selected recipe, on the right
    local detail = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    detail:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 30, -48)
    detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 18)
    page.detailScroll = detail
    page.detailChild = CreateFrame("Frame", nil, detail)
    page.detailChild:SetSize(300, 1)
    detail:SetScrollChild(page.detailChild)
    page.detailText = page.detailChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    page.detailText:SetPoint("TOPLEFT", 0, 0)
    page.detailText:SetWidth(300)
    page.detailText:SetJustifyH("LEFT")
    page.detailText:SetJustifyV("TOP")

    local iconButton = CreateFrame("Button", nil, page)
    iconButton:SetSize(40, 40)
    iconButton:SetPoint("BOTTOMLEFT", detail, "TOPLEFT", 0, 6)
    iconButton.texture = iconButton:CreateTexture(nil, "ARTWORK")
    iconButton.texture:SetAllPoints()
    iconButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local recipe = ns.RecipeDB_Get(self.spellID)
        local product = recipe and recipe.p and recipe.p[1]
        if product and GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(product)
        elseif recipe then
            GameTooltip:SetText(recipe.n, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", GameTooltip_Hide)
    iconButton:Hide()
    page.detailIcon = iconButton
    page.detailTitle = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.detailTitle:SetPoint("LEFT", iconButton, "RIGHT", 8, 0)
    page.detailTitle:SetPoint("RIGHT", page, "RIGHT", -8, 0)
    page.detailTitle:SetJustifyH("LEFT")
    page.detailTitle:SetWordWrap(false)

    local events = CreateFrame("Frame")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:SetScript("OnEvent", function()
        if page:IsVisible() and state.selected then
            renderDetail()
        end
    end)

    page:Hide()
    return page
end

-- The detail text takes the width the window gives it.
function ns.SearchPage_Relayout()
    if not page then return end
    local width = math.max(120, page.detailScroll:GetWidth() - 8)
    page.detailText:SetWidth(width)
    page.detailChild:SetWidth(width)
    if page:IsVisible() then renderDetail() end
end

function ns.SearchPage_Show(text)
    if not page then return end
    page:Show()
    if text ~= nil then page.search:SetText(text) end
    page.updateHint()
    page.search:SetFocus()
    refresh()
end

function ns.SearchPage_Hide()
    if page then page:Hide() end
end

-- the filters of the page back to nothing
function ns.SearchPage_ResetFilters()
    ns.char.searchFilters = nil
    if not page then return end
    ns.FilterBar_Reset(filters)
    page.filterBar.Update()
    if page:IsVisible() then refresh() end
end

function ns.SearchPage_Results()
    return state.results
end
