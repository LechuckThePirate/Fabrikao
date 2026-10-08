local _, ns = ...

-- Recipes of a profession, read from the game's trade skill API (C_TradeSkillUI). The game only answers
-- while that profession's window is open, so ns.Recipes_Request opens it (out of sight when it wasn't open
-- already), copies what the window needs into plain tables and closes it again. Everything after that works
-- on the copy: the list, the search and the "how many can I make" counts (from the bags, not the game).

local BASIC_REAGENT = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1
local REQUEST_TIMEOUT = 5 -- seconds before giving up on a profession that never answers

local cache = {} -- skill line -> last copy

local function openSkillLine()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo) then return nil end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    local id = info and (info.parentProfessionID or info.professionID)
    if not id or id == 0 then return nil end
    return id
end

local function isReady(skillLine)
    return C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady()
        and openSkillLine() == skillLine
end

-- What a recipe needs of each basic ingredient: { { items = { itemID, ... }, quantity = n }, ... }. Several
-- items in one slot are alternatives (the same ingredient in other qualities).
local function readReagents(recipeID)
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not ok or type(schematic) ~= "table" then return nil end
    local reagents = {}
    for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
        if slot.reagentType == BASIC_REAGENT and (slot.quantityRequired or 0) > 0 then
            local items = {}
            for _, reagent in ipairs(slot.reagents or {}) do
                if reagent.itemID then items[#items + 1] = reagent.itemID end
            end
            if #items > 0 then reagents[#reagents + 1] = { items = items, quantity = slot.quantityRequired } end
        end
    end
    return reagents
end

local function byName(a, b) return a.name < b.name end

-- Known recipes by difficulty (orange first), then by name; the unknown ones by when they turn grey, then name.
local function sortKnown(a, b)
    local da, db = a.difficulty or ns.DIFFICULTY_LAST, b.difficulty or ns.DIFFICULTY_LAST
    if da ~= db then return da < db end
    return byName(a, b)
end
local function sortUnknown(a, b)
    if (a.trivial or 0) ~= (b.trivial or 0) then return (a.trivial or 0) < (b.trivial or 0) end
    return byName(a, b)
end

-- Copies the open profession's recipes (known and not known) into a table, or nil when `skillLine` isn't the
-- one open. { skillLine =, known = { recipe, ... }, unknown = { recipe, ... }, sources = { [sourceType] = true } }
-- recipe: { id, name, icon, link, learned, difficulty (0 orange .. 3 grey, known ones only), trivial (the skill
-- at which it turns grey), sourceType, sourceText (not known ones), reagents (known ones) }
function ns.Recipes_Read(skillLine)
    if not isReady(skillLine) then return nil end
    local T = C_TradeSkillUI
    -- the lists in the game's window are filtered: ask for everything, and give its filters back
    local wasLearned = T.GetShowLearned and T.GetShowLearned()
    local wasUnlearned = T.GetShowUnlearned and T.GetShowUnlearned()
    if T.SetShowLearned then T.SetShowLearned(true) end
    if T.SetShowUnlearned then T.SetShowUnlearned(true) end

    local copy = { skillLine = skillLine, known = {}, unknown = {}, sources = {} }
    local seen = {}
    for _, id in ipairs(T.GetFilteredRecipeIDs and T.GetFilteredRecipeIDs() or {}) do
        local info = T.GetRecipeInfo(id)
        -- a recipe with several ranks is one entry: the first rank
        if info and info.name and not info.previousRecipeID and not seen[info.recipeID or id]
                and (not T.IsRecipeInSkillLine or T.IsRecipeInSkillLine(id, skillLine)) then
            seen[info.recipeID or id] = true
            local recipe = {
                id = info.recipeID or id, name = info.name, icon = info.icon, link = info.hyperlink,
                learned = info.learned and true or false, trivial = info.maxTrivialLevel,
                sourceType = info.sourceType,
            }
            if recipe.learned then
                recipe.difficulty = info.relativeDifficulty
                recipe.reagents = readReagents(recipe.id)
                copy.known[#copy.known + 1] = recipe
            else
                if T.GetRecipeSourceText then recipe.sourceText = T.GetRecipeSourceText(recipe.id) end
                if recipe.sourceType then copy.sources[recipe.sourceType] = true end
                copy.unknown[#copy.unknown + 1] = recipe
            end
        end
    end
    table.sort(copy.known, sortKnown)
    table.sort(copy.unknown, sortUnknown)

    if wasLearned ~= nil and T.SetShowLearned then T.SetShowLearned(wasLearned) end
    if wasUnlearned ~= nil and T.SetShowUnlearned then T.SetShowUnlearned(wasUnlearned) end
    cache[skillLine] = copy
    return copy
end

-- The last copy read of a profession (this session), whether its window is open or not.
function ns.Recipes_Cached(skillLine)
    return cache[skillLine]
end

-- How many times the character can craft the recipe with what is in the bags.
function ns.Recipes_Craftable(recipe)
    if not recipe.reagents or #recipe.reagents == 0 then return 0 end
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    local most
    for _, reagent in ipairs(recipe.reagents) do
        local have = 0
        for _, itemID in ipairs(reagent.items) do have = have + (count(itemID) or 0) end
        local times = math.floor(have / reagent.quantity)
        most = most and math.min(most, times) or times
    end
    return most or 0
end

-- Name of a recipe source (the game numbers them as the pet sources: drop, quest, vendor, profession...).
function ns.Recipes_SourceLabel(sourceType)
    return sourceType and _G["BATTLE_PET_SOURCE_" .. (sourceType + 1)] or ns.L["Other"]
end

-- The rows of the recipe list for the current search: { kind = "header", text = } and { kind = "recipe",
-- recipe =, craftable = }. opts: { text =, known = bool, unknown = bool, source = sourceType or nil }
function ns.Recipes_Rows(copy, opts)
    local rows = {}
    local text = strtrim((opts.text or ""):lower())
    local function matches(recipe)
        if text == "" then return true end
        if recipe.name:lower():find(text, 1, true) then return true end
        return recipe.sourceText and recipe.sourceText:lower():find(text, 1, true) and true or false
    end

    if opts.known then
        local group = {}
        for _, recipe in ipairs(copy.known) do
            if matches(recipe) then group[#group + 1] = { kind = "recipe", recipe = recipe, craftable = ns.Recipes_Craftable(recipe) } end
        end
        if #group > 0 then
            rows[#rows + 1] = { kind = "header", text = ns.L["Known recipes"], count = #group }
            for _, row in ipairs(group) do rows[#rows + 1] = row end
        end
    end
    if opts.unknown then
        local group = {}
        for _, recipe in ipairs(copy.unknown) do
            if (opts.source == nil or recipe.sourceType == opts.source) and matches(recipe) then
                group[#group + 1] = { kind = "recipe", recipe = recipe }
            end
        end
        if #group > 0 then
            rows[#rows + 1] = { kind = "header", text = ns.L["Not known"], count = #group }
            for _, row in ipairs(group) do rows[#rows + 1] = row end
        end
    end
    return rows
end

-- Asks for a profession's recipes: callback(copy) when read, callback(nil, reason) when it can't be.
-- Opens the profession's window if it isn't, hidden while the copy is made, and closes it afterwards; a
-- window the player had open is left as the player has it (showing the profession asked for).
local pending
local frame = CreateFrame("Frame")

local function hideGameWindow(hide)
    if ProfessionsFrame and ProfessionsFrame.SetAlpha then ProfessionsFrame:SetAlpha(hide and 0 or 1) end
end

local function finish(copy, reason)
    local request = pending
    pending = nil
    frame:UnregisterAllEvents()
    if request.openedByUs then
        C_TradeSkillUI.CloseTradeSkill()
        hideGameWindow(false)
    end
    request.callback(copy, reason)
end

local function check()
    if not pending or not isReady(pending.skillLine) then return end
    if pending.openedByUs then hideGameWindow(true) end
    local copy = ns.Recipes_Read(pending.skillLine)
    -- the list can arrive empty and fill in a moment later
    if copy and (#copy.known + #copy.unknown > 0 or pending.expired) then finish(copy) end
end

frame:SetScript("OnEvent", check)

function ns.Recipes_Request(skillLine, callback)
    if not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then callback(nil, "no-api") return end
    if pending then finish(nil, "superseded") end
    local alreadyOpen = openSkillLine() ~= nil
    pending = { skillLine = skillLine, callback = callback, openedByUs = not alreadyOpen }
    if isReady(skillLine) then check() return end
    for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_DETAILS_UPDATE" }) do
        frame:RegisterEvent(event)
    end
    local request = pending
    if C_TradeSkillUI.OpenTradeSkill(skillLine) == false then finish(nil, "not-opened") return end
    if request.openedByUs then C_Timer.After(0, function() if pending == request then hideGameWindow(true) end end) end
    C_Timer.After(REQUEST_TIMEOUT, function()
        if pending ~= request then return end
        request.expired = true
        check()
        if pending == request then finish(nil, "timeout") end
    end)
end
