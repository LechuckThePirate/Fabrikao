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

-- { { name =, icon =, rank =, maxRank =, skillLine =, primary =, hasRecipes = }, ... }
function ns.Professions_List()
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

function ns.Professions_Get(skillLine)
    for _, profession in ipairs(ns.Professions_List()) do
        if profession.skillLine == skillLine then return profession end
    end
end
