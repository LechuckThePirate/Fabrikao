local _, ns = ...

-- /fabrikao probe: a diagnostic for development. It writes what the client's profession API really answers
-- (which functions exist, what each profession and a sample of its recipes look like) into the saved variable
-- FabrikaoDB.probe, so it can be read from the file after /reload instead of being copied from the game.

local function plain(value, depth)
    local kind = type(value)
    if kind == "number" or kind == "boolean" then return value end
    if kind == "string" then return (value:gsub("|", "||")) end
    if kind ~= "table" then return tostring(value) end
    if depth <= 0 then return "<table>" end
    local copy = {}
    for k, v in pairs(value) do copy[tostring(k)] = plain(v, depth - 1) end
    return copy
end

local function try(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then return { error = tostring(a) } end
    return plain({ a, b, c }, 5)
end

local FUNCTIONS = {
    "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo",
}
local TRADESKILL_FUNCTIONS = {
    "OpenTradeSkill", "CloseTradeSkill", "GetBaseProfessionInfo", "GetProfessionInfoBySkillLineID", "IsTradeSkillReady",
    "GetFilteredRecipeIDs", "GetAllRecipeIDs", "GetRecipeInfo", "GetRecipeSchematic", "GetRecipeSourceText",
    "GetRecipeRequirements", "GetCraftableCount", "GetShowLearned", "GetShowUnlearned", "SetShowLearned",
    "SetShowUnlearned", "IsRecipeInSkillLine", "CanTradeSkillShowCraftingUI", "GetCategories", "GetCategoryInfo",
    "GetTradeSkillDisplayName", "IsAnyRecipeFromSource", "GetSourceTypeFilter", "GetRecipeOutputItemData",
}

local function dumpRecipe(T, id)
    local entry = { info = try(T.GetRecipeInfo, id) }
    entry.source = try(T.GetRecipeSourceText, id)
    entry.requirements = try(T.GetRecipeRequirements, id)
    entry.craftable = try(T.GetCraftableCount, id)
    local ok, schematic = pcall(T.GetRecipeSchematic, id, false)
    entry.schematic = ok and plain(schematic, 4) or { error = tostring(schematic) }
    return entry
end

local function dumpProfession(profession, done)
    local T = C_TradeSkillUI
    ns.Recipes_Request(profession.skillLine, function(copy, reason)
        local out = { reason = reason }
        if copy then
            out.knownCount, out.unknownCount, out.sources = #copy.known, #copy.unknown, plain(copy.sources, 2)
            out.base = try(T.GetBaseProfessionInfo)
        end
        -- raw API results, read while the profession is open again (the copy is closed by now)
        done(out)
    end)
end

local function rawSample(skillLine, out)
    local T = C_TradeSkillUI
    out.rawOpenSkillLine = try(T.GetBaseProfessionInfo)
    local ids = T.GetFilteredRecipeIDs and T.GetFilteredRecipeIDs() or {}
    out.filteredCount = #ids
    out.known, out.unknown = {}, {}
    for _, id in ipairs(ids) do
        local info = T.GetRecipeInfo(id)
        if info then
            local bucket = info.learned and out.known or out.unknown
            if #bucket < 3 then bucket[#bucket + 1] = dumpRecipe(T, id) end
        end
        if #out.known >= 3 and #out.unknown >= 3 then break end
    end
    out.skillLine = skillLine
end

function ns.Probe()
    local probe = { build = { GetBuildInfo() }, project = WOW_PROJECT_ID, api = {}, tradeSkillApi = {}, professions = {} }
    for _, name in ipairs(FUNCTIONS) do probe.api[name] = _G[name] ~= nil end
    for _, name in ipairs(TRADESKILL_FUNCTIONS) do probe.tradeSkillApi[name] = C_TradeSkillUI ~= nil and C_TradeSkillUI[name] ~= nil end
    probe.sourceNames = {}
    for i = 1, 12 do probe.sourceNames[i] = _G["BATTLE_PET_SOURCE_" .. i] end
    probe.numPetSources = C_PetJournal and C_PetJournal.GetNumPetSources and C_PetJournal.GetNumPetSources()
    probe.rawProfessions = try(GetProfessions)
    probe.professions = {}

    local list = ns.Professions_List()
    for _, p in ipairs(list) do
        probe.professions[#probe.professions + 1] = {
            name = p.name, skillLine = p.skillLine, rank = p.rank, maxRank = p.maxRank, primary = p.primary,
            hasRecipes = p.hasRecipes,
            bySkillLine = try(C_TradeSkillUI.GetProfessionInfoBySkillLineID, p.skillLine),
        }
    end
    FabrikaoDB.probe = probe

    -- one profession after the other: open it, sample its raw recipe data, close it
    local index = 0
    local function nextProfession()
        index = index + 1
        local p = list[index]
        if not p then
            ns.Print(ns.L["Probe finished. Type /reload to save it."])
            return
        end
        if not p.hasRecipes then return nextProfession() end
        local entry = probe.professions[index]
        local previousRead = ns.Recipes_Read
        -- read the raw sample inside the request, while the profession is open
        ns.Recipes_Read = function(skillLine)
            local copy = previousRead(skillLine)
            if copy and not entry.sample then
                entry.sample = {}
                rawSample(skillLine, entry.sample)
            end
            return copy
        end
        dumpProfession(p, function(out)
            ns.Recipes_Read = previousRead
            entry.result = out
            nextProfession()
        end)
    end
    nextProfession()
end
