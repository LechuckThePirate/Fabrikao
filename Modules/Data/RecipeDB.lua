local _, ns = ...
local L = ns.L

-- Queries over ns.RECIPE_DATA (Data/Generated/Recipes.lua): what a recipe needs, at which skill it turns
-- orange, yellow, green and grey, and where it is learned (trainers, vendors, drops, quests). Works for
-- recipes of professions the character doesn't have, and for those it doesn't know yet.

local SOURCE_NAMES = {
    [1] = L["Crafted"], [2] = L["Drop"], [3] = L["PvP"], [4] = L["Quest"], [5] = L["Vendor"], [6] = L["Trainer"],
    [16] = L["Gathered"], [21] = L["Salvaged"],
}
-- the order they are shown in
local SOURCE_ORDER = { 6, 5, 4, 2, 3, 1, 16, 21 }

local function data()
    return ns.RECIPE_DATA
end

local function playerSide()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    return faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
end

-- Zones only one side can be in (its capitals and starting zones), by area id: many NPCs of the data carry no side, but a vendor
-- standing in Orgrimmar is not for an Alliance character.
local SIDE_ZONES = {
    A = { [1519] = true, [1537] = true, [1657] = true, [3557] = true, [12] = true, [1] = true, [141] = true, [3524] = true },
    H = { [1637] = true, [1497] = true, [1638] = true, [3487] = true, [14] = true, [85] = true, [215] = true, [3430] = true },
}

-- is it for the character's side (or both)? An NPC with no side of its own counts for the other one when every zone it is in is
-- one that side owns.
local function forMySide(entry)
    local mine = playerSide()
    if mine == nil then return true end
    if entry.f ~= nil then return entry.f == mine end
    local other = SIDE_ZONES[mine == "A" and "H" or "A"]
    if entry.z and #entry.z > 0 then
        for _, zone in ipairs(entry.z) do
            if not other[zone] then return true end
        end
        return false
    end
    return true
end

local function zoneName(id)
    local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
    return name
end

local function zoneList(ids)
    local names = {}
    for _, id in ipairs(ids or {}) do
        local name = zoneName(id)
        if name then names[#names + 1] = name end
    end
    return table.concat(names, ", ")
end

local function money(copper)
    if not copper or copper <= 0 then return nil end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return ("%dg %ds %dc"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

-- does the character know the recipe? (learned recipes are spells in the spell book)
function ns.RecipeDB_Known(spellID)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
        if ok and known then return true end
    end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, spellID, bank, false)
        if ok and known then return true end
    end
    return IsPlayerSpell ~= nil and IsPlayerSpell(spellID) and true or false
end

-- icon of what the recipe makes (or of the recipe itself)
function ns.RecipeDB_Icon(spellID, recipe)
    local product = recipe.p and recipe.p[1]
    local icon = product and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(product)
    if icon then return icon end
    icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    return icon or 134400 -- the question mark
end

-- Category of what a recipe makes, to filter by: the slot of armor (hands, wrist...), the kind of weapon, bags, potions, elixirs,
-- food, gems, trade goods... The game names them (in the player's language) from the item the recipe makes. An enchantment makes
-- no item: its slot comes from its name ("Enchant Bracer - ...").
local ENCHANT_SLOTS = {
    Bracer = "INVTYPE_WRIST", Chest = "INVTYPE_CHEST", Boots = "INVTYPE_FEET", Gloves = "INVTYPE_HAND", Cloak = "INVTYPE_CLOAK",
    Shield = "INVTYPE_SHIELD", Ring = "INVTYPE_FINGER", ["2H Weapon"] = "INVTYPE_2HWEAPON",
}
local BY_SUBCLASS = { [0] = true, [2] = true, [6] = true, [7] = true } -- consumables, weapons, projectiles, trade goods: named by their subclass
local categories = {}

local function categoryOf(recipe)
    local product = recipe.p and recipe.p[1]
    local info = C_Item and C_Item.GetItemInfoInstant
    if product and info then
        local _, itemType, subType, equipLoc, _, classID = info(product)
        if classID == 1 then return L["Bags"] end
        if classID == 4 and equipLoc and equipLoc ~= "" then
            if equipLoc == "INVTYPE_ROBE" then equipLoc = "INVTYPE_CHEST" end -- robes are chests
            return _G[equipLoc] or subType
        end
        if (BY_SUBCLASS[classID] or classID == 4) and subType and subType ~= "" then return subType end
        return itemType
    end
    local what = recipe.n and recipe.n:match("^Enchant (.-) %- ")
    if what == "Weapon" then return L["Weapon"] end
    return what and ENCHANT_SLOTS[what] and _G[ENCHANT_SLOTS[what]] or nil
end

function ns.RecipeDB_Category(recipe)
    local category = categories[recipe]
    if not category then
        local ok, found = pcall(categoryOf, recipe)
        category = ok and found or L["Other"]
        if category == "" then category = L["Other"] end
        categories[recipe] = category
    end
    return category
end

-- The tooltip of what the recipe makes (the item; for the ones that make none, like an enchantment, the recipe's own
-- spell) next to `owner`. False when there is nothing to show.
function ns.RecipeDB_ShowProductTooltip(owner, spellID, recipe)
    local product = recipe and recipe.p and recipe.p[1]
    if product and GameTooltip.SetItemByID then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(product)
    elseif GameTooltip.SetSpellByID then
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spellID)
    else
        return false
    end
    GameTooltip:Show()
    return true
end

-- the record of a recipe (by its spell id), or nil
function ns.RecipeDB_Get(spellID)
    local db = data()
    return db and db.recipes[spellID]
end

function ns.RecipeDB_Each()
    local db = data()
    return pairs(db and db.recipes or {})
end

function ns.RecipeDB_Item(recipe)
    local db = data()
    return recipe.i and db and db.items[recipe.i]
end

-- skill needed to learn it (the point where it turns orange: the first number of the colors)
function ns.RecipeDB_Required(recipe)
    return recipe.l or (recipe.c and recipe.c[1]) or 0
end

-- { orange, yellow, green, grey } skill levels
function ns.RecipeDB_Colors(recipe)
    local c = recipe.c
    if not c then return nil end
    return { ns.RecipeDB_Required(recipe), c[2], c[3], c[4] }
end

-- the sources of a recipe as codes, from the recipe and from the item that teaches it
function ns.RecipeDB_Sources(recipe)
    local set, list = {}, {}
    local function add(codes)
        for _, code in ipairs(codes or {}) do set[code] = true end
    end
    add(recipe.k)
    local item = ns.RecipeDB_Item(recipe)
    if item then add(item.k) end
    for _, code in ipairs(SOURCE_ORDER) do
        if set[code] then list[#list + 1] = code end
    end
    return list
end

function ns.RecipeDB_SourceName(code)
    return SOURCE_NAMES[code] or L["Other"]
end

-- short text for a list row: "Trainer", "Vendor / Quest"...
function ns.RecipeDB_ShortSource(recipe)
    local names = {}
    for i, code in ipairs(ns.RecipeDB_Sources(recipe)) do
        if i > 2 then break end
        names[#names + 1] = SOURCE_NAMES[code]
    end
    return #names > 0 and table.concat(names, " / ") or nil
end

local function named(entry, withZones)
    local zones = withZones and zoneList(entry.z)
    if zones and zones ~= "" then return ("%s (%s)"):format(entry.n, zones) end
    return entry.n
end

-- Where an NPC of the data stands: { map = map id, x =, y = } (x and y in percent of the map), or nil when it is not known.
function ns.RecipeDB_NpcLocation(id)
    local db = data()
    local spot = db and db.npcs and db.npcs[id]
    return spot and { map = spot[1], x = spot[2], y = spot[3] } or nil
end

-- a list of texts as the entries of a line of ns.RecipeDB_Where
local function asEntries(texts)
    local entries = {}
    for i, text in ipairs(texts) do entries[i] = { text = text } end
    return entries
end

-- The NPCs by how far they are from the character (a trainer next door beats one in another continent): by distance when the game
-- tells it, then the ones on the character's map, then the ones elsewhere, then the ones whose position isn't known. The order they
-- came in is kept among equals. Returns a new list, and a table of the distances there are, by NPC.
local function nearestFirst(list)
    local here = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local keyed, distances = {}, {}
    for index, npc in ipairs(list) do
        local spot = npc.id and ns.RecipeDB_NpcLocation(npc.id)
        local distance = spot and ns.Map_Distance and ns.Map_Distance(spot)
        local key
        if distance then key = distance
        elseif spot and here and spot.map == here then key = 1e7
        elseif spot then key = 2e7
        else key = 3e7 end
        distances[npc] = distance
        keyed[index] = { npc = npc, key = key, index = index }
    end
    table.sort(keyed, function(a, b)
        if a.key ~= b.key then return a.key < b.key end
        return a.index < b.index
    end)
    local sorted = {}
    for i, item in ipairs(keyed) do sorted[i] = item.npc end
    return sorted, distances
end

-- where the recipe is learned, as lines { title =, text =, entries = { { text =, id =, name = }... }, more = how many are left out }
-- for a tooltip or detail panel (`text` is the entries in one line; the panel puts each entry on its own line; id and name are
-- there for the trainers and vendors, who can be shown on the map); `full` lists far more of each (the recipe's own panel has the room)
function ns.RecipeDB_Where(recipe, full)
    local lines = {}
    local maxTrainers, maxVendors, maxQuests, maxDrops, maxObjects = 3, 5, 3, 4, 3
    if full then maxTrainers, maxVendors, maxQuests, maxDrops, maxObjects = 10, 12, 8, 30, 8 end
    local item = ns.RecipeDB_Item(recipe)
    local db = data()

    local trainable = false
    for _, code in ipairs(recipe.k or {}) do if code == 6 then trainable = true end end
    if trainable then
        local names, npcs, count = {}, {}, 0
        local mine = {}
        for _, trainer in ipairs(db and db.trainers[recipe.s] or {}) do
            if forMySide(trainer) then mine[#mine + 1] = trainer end
        end
        local ordered, distances = nearestFirst(mine)
        for _, trainer in ipairs(ordered) do
            count = count + 1
            if count <= maxTrainers then
                names[#names + 1] = named(trainer, true)
                npcs[#npcs + 1] = { id = trainer.id, name = trainer.n, text = named(trainer, true), distance = distances[trainer] }
            end
        end
        local text = table.concat(names, "; ")
        if count > #names then text = text .. "; " .. L["and %d more"]:format(count - #names) end
        local cost = money(recipe.g)
        if cost then text = (text ~= "" and (text .. " -- ") or "") .. L["costs %s"]:format(cost) end
        lines[#lines + 1] = { title = L["Trainer"], text = text, entries = npcs, more = count - #names }
    end

    if item then
        local vendors, npcs, vendorCount = {}, {}, 0
        local mine = {}
        for _, vendor in ipairs(item.v or {}) do
            if forMySide(vendor) then mine[#mine + 1] = vendor end
        end
        local ordered, distances = nearestFirst(mine)
        for _, vendor in ipairs(ordered) do
            vendorCount = vendorCount + 1
            if #vendors < maxVendors then
                local price = money(vendor.g)
                local text = named(vendor, true) .. (price and (" -- " .. price) or "")
                vendors[#vendors + 1] = text
                npcs[#npcs + 1] = { id = vendor.id, name = vendor.n, text = text, distance = distances[vendor] }
            end
        end
        if #vendors > 0 then
            local text = table.concat(vendors, "; ")
            if vendorCount > #vendors then text = text .. "; " .. L["and %d more"]:format(vendorCount - #vendors) end
            lines[#lines + 1] = { title = L["Vendor"], text = text, entries = npcs, more = vendorCount - #vendors }
        end

        if item.qs then
            local quests = {}
            for _, quest in ipairs(item.qs) do
                if forMySide(quest) and #quests < maxQuests then quests[#quests + 1] = quest.n end
            end
            if #quests > 0 then lines[#lines + 1] = { title = L["Quest"], text = table.concat(quests, "; "), entries = asEntries(quests) } end
        end

        if item.d then
            local drops, dropEntries = {}, {}
            -- (the tooltips keep the most likely drops first; the panel, with the room, puts the nearest first)
            local dropOrder, dropDistances = item.d, {}
            if full then dropOrder, dropDistances = nearestFirst(item.d) end
            for _, npc in ipairs(dropOrder) do
                if #drops < maxDrops then
                    local text = named(npc, true)
                    if npc.lo then text = text .. (npc.hi and npc.hi ~= npc.lo and (" " .. L["level %d-%d"]:format(npc.lo, npc.hi))
                        or (" " .. L["level %d"]:format(npc.lo))) end
                    if npc.pm and npc.pm > 0 then text = text .. (" -- %.2f%%"):format(npc.pm / 100) end
                    drops[#drops + 1] = text
                    dropEntries[#dropEntries + 1] = { text = text, id = npc.id, name = npc.n, distance = dropDistances[npc] }
                end
            end
            local text = table.concat(drops, "; ")
            local left = item.dn and item.dn > #drops and item.dn - #drops or 0
            if left > 0 then text = text .. "; " .. L["and %d more"]:format(left) end
            lines[#lines + 1] = { title = L["Drop"], text = text, entries = dropEntries, more = left }
        elseif item.cd then
            lines[#lines + 1] = { title = L["Drop"], text = L["World drop: any creature of about level %d"]:format(item.lv or 0) }
        end

        if item.o then
            local objects = {}
            for _, object in ipairs(item.o) do
                if #objects < maxObjects then objects[#objects + 1] = named(object, true) end
            end
            lines[#lines + 1] = { title = L["Found in"], text = table.concat(objects, "; "), entries = asEntries(objects) }
        end
    end

    if #lines == 0 then
        lines[1] = { title = L["Unknown"], text = L["No source known for this recipe"] }
    end
    return lines
end

-- Everything a search can match in a recipe, in lower case: its name, ingredients (the ones the client knows by now),
-- and who sells, drops or gives the item that teaches it, with their zones.
local function haystackOf(recipe)
    local parts = { recipe.n }
    local itemName = C_Item and C_Item.GetItemNameByID
    for _, reagent in ipairs(recipe.m or {}) do
        local name = itemName and itemName(reagent[1])
        if name then parts[#parts + 1] = name end
    end
    local item = ns.RecipeDB_Item(recipe)
    if item then
        for _, list in ipairs({ item.v or {}, item.d or {}, item.qs or {}, item.o or {} }) do
            for _, entry in ipairs(list) do
                parts[#parts + 1] = entry.n
                if entry.z then parts[#parts + 1] = zoneList(entry.z) end
            end
        end
    end
    return table.concat(parts, "\n"):lower()
end

-- the same for a recipe by its spell id (for the lists of the profession pages), "" when it isn't known
function ns.RecipeDB_SearchText(spellID)
    local recipe = ns.RecipeDB_Get(spellID)
    return recipe and haystackOf(recipe) or ""
end

-- Recipes matching a search: every word of `text` has to be in the name, an ingredient, an NPC, a quest or a
-- zone. opts: { skill = skill line to look in (nil: all) }. Returns { { id = spellID, recipe = record }, ... } by name.
function ns.RecipeDB_Search(text, opts)
    local results = {}
    local db = data()
    if not db then return results end
    text = strtrim((text or ""):lower())
    local skill = opts and opts.skill
    -- no text: nothing, unless asked for everything (of a profession, or of all of them) to browse it
    if text == "" and not (opts and opts.all) then return results end
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end

    for id, recipe in pairs(db.recipes) do
        if not skill or recipe.s == skill then
            local haystack = text ~= "" and haystackOf(recipe) or ""
            local all = true
            for _, word in ipairs(words) do
                if not haystack:find(word, 1, true) then all = false break end
            end
            if all then results[#results + 1] = { id = id, recipe = recipe } end
        end
    end
    local browsing = text == ""
    table.sort(results, function(a, b)
        if browsing then -- a whole profession: by the skill each recipe needs
            local ra, rb = ns.RecipeDB_Required(a.recipe), ns.RecipeDB_Required(b.recipe)
            if ra ~= rb then return ra < rb end
        end
        if a.recipe.n ~= b.recipe.n then return a.recipe.n < b.recipe.n end
        return a.id < b.id
    end)
    return results
end

-- 0 orange, 1 yellow, 2 green, 3 grey: how the recipe looks for a character with that skill. A level of 0 in
-- the data means the recipe skips that color (it stays orange until it turns grey, say).
function ns.RecipeDB_Difficulty(recipe, skill)
    local c = recipe.c
    if not c then return 0 end
    if c[4] > 0 and skill >= c[4] then return 3 end
    if c[3] > 0 and skill >= c[3] then return 2 end
    if c[2] > 0 and skill >= c[2] then return 1 end
    return 0
end

local SKILL_NAMES = {
    [171] = "Alchemy", [164] = "Blacksmithing", [333] = "Enchanting", [202] = "Engineering", [165] = "Leatherworking",
    [197] = "Tailoring", [186] = "Mining", [185] = "Cooking", [129] = "First Aid",
}
-- the order the professions are listed in a filter
local SKILL_ORDER = { 171, 164, 333, 202, 165, 197, 186, 185, 129 }

-- the profession's name in the player's language (from the client), or its English one
function ns.RecipeDB_SkillName(skill)
    local info = C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID
        and C_TradeSkillUI.GetProfessionInfoBySkillLineID(skill)
    local name = info and info.professionName
    if name and name ~= "" then return name end
    return SKILL_NAMES[skill] or ("#" .. skill)
end

-- the skill lines that have recipes in the data, in display order
function ns.RecipeDB_Skills()
    local db = data()
    local present, list = {}, {}
    for _, recipe in pairs(db and db.recipes or {}) do present[recipe.s] = true end
    for _, skill in ipairs(SKILL_ORDER) do
        if present[skill] then list[#list + 1] = skill; present[skill] = nil end
    end
    local extra = {}
    for skill in pairs(present) do extra[#extra + 1] = skill end
    table.sort(extra)
    for _, skill in ipairs(extra) do list[#list + 1] = skill end
    return list
end
