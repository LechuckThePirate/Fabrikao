local _, ns = ...

-- The professions the character has, in the order the window shows them: the primary ones first (as the
-- game lists them), then First Aid, Cooking and Fishing. Forever uses the retail profession API:
-- GetProfessions() / GetProfessionInfo() for the list, C_TradeSkillUI for everything about recipes.

-- skill lines of the secondary professions, in display order
local SECONDARY = { [129] = 1, [185] = 2, [356] = 3 } -- First Aid, Cooking, Fishing
local ARCHAEOLOGY = 794 -- never has recipes

-- Colors of the difficulty of a recipe, as the game's trade skill windows draw them. The keys are
-- Enum.TradeskillRelativeDifficulty: 0 optimal (orange), 1 medium (yellow), 2 easy (green), 3 trivial (grey).
ns.DIFFICULTY_COLORS = {
    [0] = { 1, 0.5, 0.25 },
    [1] = { 1, 1, 0 },
    [2] = { 0.25, 0.75, 0.25 },
    [3] = { 0.5, 0.5, 0.5 },
}
ns.DIFFICULTY_LAST = 3

-- The four skill levels of a recipe (orange, yellow, green, grey), each in its color; "-" for a color the recipe skips.
function ns.DifficultyColorsText(colors)
    local out = {}
    for i, level in ipairs(colors) do
        local c = ns.DIFFICULTY_COLORS[i - 1]
        local shown = (level > 0 or i == 1) and tostring(level) or "-"
        out[#out + 1] = ("|cff%02x%02x%02x%s|r"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255), shown)
    end
    return table.concat(out, "  ")
end

-- GetProfessions() returns nil for the slots the character doesn't have, so the values can't go through ipairs.
local function pack(...)
    return { ... }, select("#", ...)
end

-- Whether the profession has a crafting window at all (Herbalism, Skinning and Fishing don't): the game asks
-- it with the profession's own spell, the first one of its spell book entries.
local function hasRecipes(spellOffset)
    if not (spellOffset and C_SpellBook and C_SpellBook.GetSpellBookItemInfo and C_TradeSkillUI
            and C_TradeSkillUI.CanTradeSkillShowCraftingUI and Enum and Enum.SpellBookSpellBank) then
        return true -- can't tell: let it try
    end
    local info = C_SpellBook.GetSpellBookItemInfo(spellOffset + 1, Enum.SpellBookSpellBank.Player)
    if not (info and info.spellID) then return false end
    return C_TradeSkillUI.CanTradeSkillShowCraftingUI(info.spellID) and true or false
end

-- The professions the playing character has: { { name =, icon =, rank =, maxRank =, skillLine =, primary =, hasRecipes = }, ... }
function ns.Professions_Mine()
    local list = {}
    if not (GetProfessions and GetProfessionInfo) then return list end
    local indexes, count = pack(GetProfessions())
    for i = 1, count do
        local index = indexes[i]
        if index then
            local name, icon, rank, maxRank, _, spellOffset, skillLine = GetProfessionInfo(index)
            if name and skillLine ~= ARCHAEOLOGY then
                list[#list + 1] = {
                    name = name, icon = icon, rank = rank or 0, maxRank = maxRank or 0, skillLine = skillLine,
                    primary = not SECONDARY[skillLine], hasRecipes = hasRecipes(spellOffset),
                    order = #list + 1,
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.primary ~= b.primary then return a.primary end
        if not a.primary then
            local oa, ob = SECONDARY[a.skillLine] or 99, SECONDARY[b.skillLine] or 99
            if oa ~= ob then return oa < ob end
        end
        return a.order < b.order
    end)
    return list
end

-- The professions of the character the window shows: the playing one's, or another character's saved copy (Roster.lua).
function ns.Professions_List()
    return ns.Roster_ViewedProfessions and ns.Roster_ViewedProfessions() or ns.Professions_Mine()
end

-- icons of the professions the character may not have (the game's own when any character saved one, else these)
local ICONS = {
    [171] = "Interface\\Icons\\Trade_Alchemy", [164] = "Interface\\Icons\\Trade_BlackSmithing", [333] = "Interface\\Icons\\Trade_Engraving",
    [202] = "Interface\\Icons\\Trade_Engineering", [165] = "Interface\\Icons\\INV_Misc_ArmorKit_17", [197] = "Interface\\Icons\\Trade_Tailoring",
    [186] = "Interface\\Icons\\Trade_Mining", [185] = "Interface\\Icons\\INV_Misc_Food_15", [129] = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
}
local QUESTION_MARK = 134400

-- The professions with recipes in the data that `have` (a list as ns.Professions_List returns) lacks, in the data's order:
-- { { name =, icon =, skillLine =, primary =, hasRecipes = true, learned = false }, ... } (no rank: it isn't learned).
function ns.Professions_Missing(have)
    local owned = {}
    for _, p in ipairs(have) do owned[p.skillLine] = true end
    local list = {}
    for _, skill in ipairs(ns.RecipeDB_Skills and ns.RecipeDB_Skills() or {}) do
        if not owned[skill] then
            list[#list + 1] = {
                name = ns.RecipeDB_SkillName(skill), skillLine = skill, hasRecipes = true, learned = false,
                icon = (ns.Roster_Icon and ns.Roster_Icon(skill)) or ICONS[skill] or QUESTION_MARK,
                primary = not SECONDARY[skill],
            }
        end
    end
    return list
end

function ns.Professions_Get(skillLine)
    for _, profession in ipairs(ns.Professions_List()) do
        if profession.skillLine == skillLine then return profession end
    end
end
