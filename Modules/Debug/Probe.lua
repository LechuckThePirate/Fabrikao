local _, ns = ...

-- /fabrikao probe: a diagnostic for development. It checks, for each profession of the character, how many of
-- the data's recipes the client says are known (by each way of asking), and, when that profession's window is
-- open (the K window), compares the data with the window's own list. The result is printed and kept in the saved
-- variable FabrikaoDB.probe, to be read from the file after /reload.

local function bankPlayer()
    return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
end

local function viaIsSpellKnown(id)
    if not (C_SpellBook and C_SpellBook.IsSpellKnown) then return false end
    local ok, result = pcall(C_SpellBook.IsSpellKnown, id, bankPlayer())
    return ok and result and true or false
end

local function viaInSpellBook(id)
    if not (C_SpellBook and C_SpellBook.IsSpellInSpellBook) then return false end
    local ok, result = pcall(C_SpellBook.IsSpellInSpellBook, id, bankPlayer(), false)
    return ok and result and true or false
end

local function viaIsPlayerSpell(id)
    return IsPlayerSpell ~= nil and IsPlayerSpell(id) and true or false
end

function ns.Probe()
    local probe = {
        build = { GetBuildInfo() }, project = WOW_PROJECT_ID,
        api = {
            IsSpellKnown = C_SpellBook ~= nil and C_SpellBook.IsSpellKnown ~= nil,
            IsSpellInSpellBook = C_SpellBook ~= nil and C_SpellBook.IsSpellInSpellBook ~= nil,
            IsPlayerSpell = IsPlayerSpell ~= nil,
            GetSpellTexture = C_Spell ~= nil and C_Spell.GetSpellTexture ~= nil,
            GetItemNameByID = C_Item ~= nil and C_Item.GetItemNameByID ~= nil,
            GetAreaInfo = C_Map ~= nil and C_Map.GetAreaInfo ~= nil,
        },
        recipesInData = 0, professions = {},
    }
    for _ in ns.RecipeDB_Each() do probe.recipesInData = probe.recipesInData + 1 end

    local open = C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
    probe.openWindow = open and { id = open.professionID, name = open.professionName, parent = open.parentProfessionID } or false
    probe.ready = C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady() or false

    local list = ns.Professions_Mine()
    ns.Print(("%d professions, %d recipes in the data"):format(#list, probe.recipesInData))
    for _, profession in ipairs(list) do
        local entry = { name = profession.name, skillLine = profession.skillLine, rank = profession.rank, total = 0,
            isSpellKnown = 0, inSpellBook = 0, isPlayerSpell = 0, union = 0, sample = {} }
        for id, recipe in ns.RecipeDB_Each() do
            if recipe.s == profession.skillLine then
                entry.total = entry.total + 1
                local a, b, c = viaIsSpellKnown(id), viaInSpellBook(id), viaIsPlayerSpell(id)
                if a then entry.isSpellKnown = entry.isSpellKnown + 1 end
                if b then entry.inSpellBook = entry.inSpellBook + 1 end
                if c then entry.isPlayerSpell = entry.isPlayerSpell + 1 end
                if a or b or c then
                    entry.union = entry.union + 1
                    if #entry.sample < 5 then entry.sample[#entry.sample + 1] = recipe.n end
                end
            end
        end
        -- the game's own window, when it is open on this profession
        local live = ns.Recipes_Read(profession.skillLine, profession.name)
        if live then
            entry.live = { known = #live.known, unknown = #live.unknown, differences = {} }
            local fromData = ns.Recipes_FromData(profession.skillLine, profession.rank)
            local dataKnown = {}
            for _, r in ipairs(fromData.known) do dataKnown[r.id] = true end
            for _, r in ipairs(live.known) do
                if not dataKnown[r.id] and #entry.live.differences < 10 then
                    entry.live.differences[#entry.live.differences + 1] = r.name .. " (" .. r.id .. ") known in the window, not by the spell book"
                end
            end
        end
        probe.professions[#probe.professions + 1] = entry
        ns.Print(("%s: %d in the data; known by IsSpellKnown %d, InSpellBook %d, IsPlayerSpell %d%s"):format(
            entry.name, entry.total, entry.isSpellKnown, entry.inSpellBook, entry.isPlayerSpell,
            entry.live and (("; the window lists %d known"):format(entry.live.known)) or ""))
    end
    FabrikaoDB.probe = probe
    ns.Print(ns.L["Probe finished. Type /reload to save it."])
end

-- /fabrikao learn: why "You can learn" lists what it lists first. Where the character is and, for the first recipes of each
-- profession, the key the order uses and every vendor that teaches it with where it stands, how far and in which world position
-- (the same numbers ns.Map_Distance gives the order). Printed and kept in FabrikaoDB.learnProbe, to be read after /reload.
function ns.ProbeLearn()
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local position = map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
    local px, py
    if position then px, py = position:GetXY() end
    local function world(mapID, x, y)
        if not (mapID and x and y and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
        local continent, at = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        if continent and at then return { continent = continent, x = at.x, y = at.y } end
    end
    local info = map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
    local result = {
        player = {
            map = map, mapName = info and info.name, x = px and px * 100, y = py and py * 100, world = world(map, px, py),
            zone = GetZoneText and GetZoneText(), subzone = GetSubZoneText and GetSubZoneText(),
            side = UnitFactionGroup and UnitFactionGroup("player"),
        },
        groups = {},
    }
    ns.Print(("You are in %s (%s) on map %s at %s, %s"):format(tostring(result.player.zone), tostring(result.player.subzone),
        tostring(map), px and ("%.1f"):format(px * 100) or "?", py and ("%.1f"):format(py * 100) or "?"))
    for _, group in ipairs(ns.Recipes_LearnableNow(ns.Professions_List(), 6, "near")) do
        local entry = { profession = group.profession.name, total = group.total, recipes = {} }
        local trainerKey = ns.RecipeDB_TrainerKey(group.profession.skillLine)
        for _, recipe in ipairs(group.recipes) do
            local item = ns.RecipeDB_Item(recipe.db)
            local line = { name = recipe.name, required = recipe.required, key = ns.RecipeDB_TeacherKey(recipe.db, trainerKey), vendors = {} }
            for _, vendor in ipairs(item and item.v or {}) do
                local spot = vendor.id and ns.RecipeDB_NpcLocation(vendor.id)
                line.vendors[#line.vendors + 1] = {
                    name = vendor.n, side = vendor.f, map = spot and spot.map, x = spot and spot.x, y = spot and spot.y,
                    distance = spot and ns.Map_Distance and ns.Map_Distance(spot), world = spot and world(spot.map, spot.x / 100, spot.y / 100),
                }
            end
            entry.recipes[#entry.recipes + 1] = line
            local near
            for _, v in ipairs(line.vendors) do
                if v.distance and (not near or v.distance < near.distance) then near = v end
            end
            ns.Print(("%s: %s (%d), key %s%s"):format(entry.profession, line.name, line.required or 0, tostring(line.key),
                near and (", nearest vendor %s %.0f yd"):format(near.name or "?", near.distance) or ""))
        end
        result.groups[#result.groups + 1] = entry
    end
    FabrikaoDB.learnProbe = result
    ns.Print(ns.L["Probe finished. Type /reload to save it."])
end
