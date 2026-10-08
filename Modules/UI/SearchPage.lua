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
local state = { skill = nil, results = {}, selected = nil, truncated = 0 }

local function colorCode(color)
    return ("|cff%02x%02x%02x"):format(math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255))
end

-- the skill levels, each in its color ("-" for a color the recipe skips)
local function colorsText(colors)
    local out = {}
    for i, level in ipairs(colors) do
        local shown = (level > 0 or i == 1) and tostring(level) or "-"
        out[#out + 1] = colorCode(ns.DIFFICULTY_COLORS[i - 1]) .. shown .. "|r"
    end
    return table.concat(out, "  ")
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
        lines[#lines + 1] = ("%s%s|r %s"):format(GOLD, L["Difficulty:"], colorsText(colors))
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
            lines[#lines + 1] = ("  %s%s x%d  (%s%s|r)"):format(icon and ("|T" .. icon .. ":14|t ") or "", itemName(itemID), needed,
                have >= needed and "|cff40bf40" or "|cffff4040", L["you have %d"]:format(have))
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
    b:SetScript("OnClick", function(self)
        selectRecipe(self.spellID)
        if IsModifiedClick and IsModifiedClick("CHATLINK") then
            local product = self.recipe.p and self.recipe.p[1]
            local link = product and select(2, GetItemInfo(product)) or ("|cff71d5ff|Hspell:%d|h[%s]|h|r"):format(self.spellID, self.recipe.n)
            ChatEdit_InsertLink(link)
        end
    end)
    return b
end

local function refresh()
    if not page then return end
    local text = page.search:GetText()
    local results = ns.RecipeDB_Search(text, { skill = state.skill, all = true })
    state.truncated = math.max(0, #results - MAX_RESULTS)
    for i = #results, MAX_RESULTS + 1, -1 do results[i] = nil end
    state.results = results

    local mine = myProfessions()
    for i, result in ipairs(results) do
        local b = rowButtons[i] or newRow()
        rowButtons[i] = b
        local recipe = result.recipe
        b.spellID, b.recipe = result.id, recipe
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", page.content, "TOPLEFT", 0, -(i - 1) * ROW_H)
        b:SetPoint("RIGHT", page.content, "RIGHT", 0, 0)
        b.icon:SetTexture(iconOf(result.id, recipe))
        b.text:SetText(recipe.n)
        local mineHere = mine[recipe.s]
        local color = { 0.9, 0.9, 0.9 }
        if mineHere and mineHere.rank >= ns.RecipeDB_Required(recipe) then
            color = ns.DIFFICULTY_COLORS[ns.RecipeDB_Difficulty(recipe, mineHere.rank)]
        end
        b.text:SetTextColor(color[1], color[2], color[3])
        b.info:SetText((knows(result.id) and (CHECK .. " ") or "") .. ("%s %d"):format(ns.RecipeDB_SkillName(recipe.s), ns.RecipeDB_Required(recipe)))
        b:Show()
    end
    for i = #results + 1, #rowButtons do rowButtons[i]:Hide() end
    page.content:SetHeight(math.max(1, #results * ROW_H))

    local count
    if #results == 0 then
        count = (text == "" and not state.skill) and L["Type to search every recipe."] or L["No recipes found"]
    elseif state.truncated > 0 then
        count = L["%d recipes (showing the first %d)"]:format(#results + state.truncated, MAX_RESULTS)
    else
        count = L["%d recipes"]:format(#results)
    end
    page.count:SetText(count)

    -- keep the selection if it is still in the list, else the first result
    local keep
    for _, result in ipairs(results) do if result.id == state.selected then keep = result.id end end
    selectRecipe(keep or (results[1] and results[1].id))
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

    local skillButton = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    skillButton:SetSize(190, 22)
    skillButton:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -8)
    skillButton:SetText(L["Profession: %s"]:format(L["All"]))
    skillButton:SetScript("OnClick", cycleSkill)
    page.skillButton = skillButton

    page.count = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    page.count:SetPoint("LEFT", skillButton, "RIGHT", 10, 0)

    -- results, on the left
    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", skillButton, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOM", page, "BOTTOM", 0, 0)
    scroll:SetWidth(LIST_W)
    page.content = CreateFrame("Frame", nil, scroll)
    page.content:SetSize(LIST_W - 4, 1)
    scroll:SetScrollChild(page.content)
    page.scroll = scroll

    -- the selected recipe, on the right
    local detail = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    detail:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 30, -48)
    detail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -24, 0)
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

function ns.SearchPage_Results()
    return state.results
end
