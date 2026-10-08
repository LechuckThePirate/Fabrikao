local _, ns = ...

-- Recipes of a profession for the window's lists. The list comes from the addon's own data (every recipe of the
-- profession) and "known" from the spell book, so it needs no trade skill window. When the player happens to
-- have that profession's window open, its live answer (C_TradeSkillUI) is used instead, which also knows what
-- the data doesn't. Everything works on plain tables: the list, the search and the "how many can I make"
-- counts (from the bags).

local BASIC_REAGENT = (Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1

local cache = {} -- skill line -> last copy

local function openSkillLine()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo) then return nil end
    local info = C_TradeSkillUI.GetBaseProfessionInfo()
    local id = info and (info.parentProfessionID or info.professionID)
    if not id or id == 0 then return nil end
    return id
end

-- is that profession's window the one open and ready? (by skill line, or by name should the game number its lines differently)
local function isReady(skillLine, name)
    if not (C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady()) then return false end
    if openSkillLine() == skillLine then return true end
    local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    return name ~= nil and info ~= nil and (info.professionName == name or info.parentProfessionName == name)
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

-- Known recipes by difficulty (orange first), then by name; the unknown ones by the skill they need (or, without
-- that, when they turn grey), then name.
local function sortKnown(a, b)
    local da, db = a.difficulty or ns.DIFFICULTY_LAST, b.difficulty or ns.DIFFICULTY_LAST
    if da ~= db then return da < db end
    return byName(a, b)
end
local function sortUnknown(a, b)
    local sa, sb = a.required or a.trivial or 0, b.required or b.trivial or 0
    if sa ~= sb then return sa < sb end
    return byName(a, b)
end

-- Copies the open profession's recipes (known and not known) into a table, or nil when `skillLine` isn't the
-- one open. { skillLine =, known = { recipe, ... }, unknown = { recipe, ... }, sources = { [sourceType] = true } }
-- recipe: { id, name, icon, link, learned, difficulty (0 orange .. 3 grey, known ones only), trivial (the skill
-- at which it turns grey), sourceType, sourceText (not known ones), reagents (known ones) }
function ns.Recipes_Read(skillLine, name)
    if not isReady(skillLine, name) then return nil end
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
                and (name or not T.IsRecipeInSkillLine or T.IsRecipeInSkillLine(id, skillLine)) then
            seen[info.recipeID or id] = true
            local recipe = {
                id = info.recipeID or id, name = info.name, icon = info.icon, link = info.hyperlink,
                learned = info.learned and true or false, trivial = info.maxTrivialLevel,
            }
            -- what the addon's own data knows about it: skill levels and where it is learned
            local db = ns.RecipeDB_Get and ns.RecipeDB_Get(recipe.id)
            if db then
                recipe.db = db
                recipe.required = ns.RecipeDB_Required(db)
                recipe.colors = ns.RecipeDB_Colors(db)
                recipe.search = ns.RecipeDB_SearchText(recipe.id)
                recipe.sourceType = ns.RecipeDB_Sources(db)[1]
            end
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

-- Name of a recipe source code (trainer, vendor, drop, quest...).
function ns.Recipes_SourceLabel(sourceType)
    return sourceType and ns.RecipeDB_SourceName(sourceType) or ns.L["Other"]
end

-- The rows of the recipe list for the current search: { kind = "header", text = } and { kind = "recipe",
-- recipe =, craftable = }. opts: { text =, known = bool, unknown = bool, source = sourceType or nil }
function ns.Recipes_Rows(copy, opts)
    local rows = {}
    local text = strtrim((opts.text or ""):lower())
    local function matches(recipe)
        if text == "" then return true end
        if recipe.name:lower():find(text, 1, true) then return true end
        if recipe.sourceText and recipe.sourceText:lower():find(text, 1, true) then return true end
        return recipe.search and recipe.search:find(text, 1, true) and true or false
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

-- A recipe of the data as the window's lists use it.
local function fromData(id, db, learned, rank)
    local recipe = {
        id = id, name = db.n, icon = ns.RecipeDB_Icon(id, db), learned = learned, db = db,
        required = ns.RecipeDB_Required(db), colors = ns.RecipeDB_Colors(db), trivial = db.c and db.c[4],
        search = ns.RecipeDB_SearchText(id), sourceType = ns.RecipeDB_Sources(db)[1],
    }
    if learned then
        recipe.difficulty = ns.RecipeDB_Difficulty(db, rank or 0)
        recipe.reagents = {}
        for _, reagent in ipairs(db.m or {}) do
            recipe.reagents[#recipe.reagents + 1] = { items = { reagent[1] }, quantity = reagent[2] }
        end
    end
    return recipe
end

-- Every recipe of the data for a profession, known ones (by the spell book) apart from the rest. `rank` is the
-- character's skill, to color the known ones.
function ns.Recipes_FromData(skillLine, rank)
    local copy = { skillLine = skillLine, known = {}, unknown = {}, sources = {} }
    for id, db in ns.RecipeDB_Each() do
        if db.s == skillLine then
            local learned = ns.RecipeDB_Known(id)
            local recipe = fromData(id, db, learned, rank)
            if learned then
                copy.known[#copy.known + 1] = recipe
            else
                if recipe.sourceType then copy.sources[recipe.sourceType] = true end
                copy.unknown[#copy.unknown + 1] = recipe
            end
        end
    end
    table.sort(copy.known, sortKnown)
    table.sort(copy.unknown, sortUnknown)
    return copy
end

-- A profession's recipes: callback(copy) at once. The live answer of the game's window if that profession's is open,
-- else the data's. opts: { name = the profession's name, rank = the character's skill }
function ns.Recipes_Request(skillLine, callback, opts)
    opts = opts or {}
    local copy = ns.Recipes_Read(skillLine, opts.name) or ns.Recipes_FromData(skillLine, opts.rank)
    cache[skillLine] = copy
    callback(copy)
end
