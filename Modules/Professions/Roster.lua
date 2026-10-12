local _, ns = ...

-- The professions and known recipes of every character that has logged in with the addon, kept account-wide, so the window can show
-- an alt's professions as if that character were playing (read only: no crafting). The game cannot tell what another character
-- knows, so each character saves a copy of its own:
--   FabrikaoDB.characters[key] = { name =, realm =, class = "MAGE", time =, professions = { { skillLine =, name =, icon =, rank =,
--     maxRank =, primary =, hasRecipes =, known = { spellID, ... } }, ... } }   (the professions in the window's order)
-- `known` holds the spells of the addon's data the character knows, per profession. Which character the window shows is the
-- "view": the playing one by default (nil), or another one's key (ns.Roster_SetView).

local viewKey, viewRecord, viewKnown -- the character shown, its saved copy and the set of the spells it knows

local function characters()
    return ns.db and ns.db.characters or {}
end

local function myKey()
    local name = UnitName and UnitName("player")
    if not name then return nil end
    return name .. "-" .. ((GetRealmName and GetRealmName()) or "")
end

local function classOf()
    return UnitClass and select(2, UnitClass("player")) or nil
end

---------------------------------------------------------------------------------------------------
-- Saving the playing character
---------------------------------------------------------------------------------------------------
-- Saves what the playing character has: its professions and, for each, the recipes of the data it knows. `allowEmpty` accepts a
-- character with no professions at all (it dropped them); otherwise an empty answer is taken for the game not being ready yet.
-- A profession whose recipes come back as none keeps the copy it had (the spell book may not be loaded yet).
function ns.Roster_Snapshot(allowEmpty)
    local key = myKey()
    if not (ns.db and key and ns.Professions_Mine) then return false end
    local list = ns.Professions_Mine()
    local old = ns.db.characters and ns.db.characters[key]
    if #list == 0 and not allowEmpty and old and #(old.professions or {}) > 0 then return false end

    local known = {}
    for _, p in ipairs(list) do
        if p.hasRecipes then known[p.skillLine] = {} end
    end
    if next(known) and ns.RecipeDB_Each and ns.RecipeDB_Known then
        for id, recipe in ns.RecipeDB_Each() do
            local ids = known[recipe.s]
            if ids and ns.RecipeDB_Known(id) then ids[#ids + 1] = id end
        end
    end

    local before = {}
    for _, p in ipairs(old and old.professions or {}) do before[p.skillLine] = p end
    local professions = {}
    for _, p in ipairs(list) do
        local ids = known[p.skillLine] or {}
        if #ids == 0 and before[p.skillLine] then ids = before[p.skillLine].known or ids end
        table.sort(ids)
        professions[#professions + 1] = {
            skillLine = p.skillLine, name = p.name, icon = p.icon, rank = p.rank, maxRank = p.maxRank,
            primary = p.primary, hasRecipes = p.hasRecipes, known = ids,
        }
    end

    ns.db.characters = ns.db.characters or {}
    ns.db.characters[key] = {
        name = UnitName("player"), realm = GetRealmName and GetRealmName() or "", class = classOf(),
        level = UnitLevel and UnitLevel("player") or nil, time = time and time() or 0, professions = professions,
    }
    return true
end

---------------------------------------------------------------------------------------------------
-- The other characters
---------------------------------------------------------------------------------------------------
-- The name to list a character by: its name, with the realm when two of them share the name.
local function label(record, key, taken)
    local name = record.name or key
    if taken[name] > 1 and record.realm and record.realm ~= "" then return name .. "-" .. record.realm end
    return name
end

-- The characters other than the playing one that have a saved copy, by name: { { key =, name =, label =, class =, time = }, ... }
function ns.Roster_Others()
    local mine = myKey()
    local taken = {}
    for key, record in pairs(characters()) do
        if type(record) == "table" then
            local name = record.name or key
            taken[name] = (taken[name] or 0) + 1
        end
    end
    local list = {}
    for key, record in pairs(characters()) do
        if key ~= mine and type(record) == "table" then
            list[#list + 1] = { key = key, name = record.name or key, label = label(record, key, taken), class = record.class, time = record.time }
        end
    end
    table.sort(list, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.key < b.key
    end)
    return list
end

-- A character's name in its class color (the plain name when the class is unknown).
function ns.Roster_ColoredName(info)
    local color = info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
    local text = info.label or info.name
    if color then return "|c" .. (color.colorStr or "ffffffff") .. text .. "|r" end
    return text
end

---------------------------------------------------------------------------------------------------
-- The view
---------------------------------------------------------------------------------------------------
-- Shows another character's professions from now on (a key of ns.Roster_Others), or the playing character's with nil. A key that
-- isn't there goes back to the playing one. Returns the key now in use.
function ns.Roster_SetView(key)
    local record = key ~= nil and key ~= myKey() and characters()[key] or nil
    if type(record) ~= "table" then record = nil end
    viewKey, viewRecord, viewKnown = nil, nil, nil
    if record then
        viewKey, viewRecord, viewKnown = key, record, {}
        for _, p in ipairs(record.professions or {}) do
            for _, id in ipairs(p.known or {}) do viewKnown[id] = true end
        end
    end
    return viewKey
end

function ns.Roster_ViewKey()
    return viewKey
end

-- The character being shown when it is not the playing one: { key =, name =, label =, class = }; nil for the playing character.
function ns.Roster_Viewed()
    if not viewKey then return nil end
    for _, info in ipairs(ns.Roster_Others()) do
        if info.key == viewKey then return info end
    end
    ns.Roster_SetView(nil) -- its copy is gone
    return nil
end

-- Does the character shown know the spell? (the playing character: the spell book; another one: what it saved)
function ns.Roster_Knows(spellID)
    if viewKnown then return viewKnown[spellID] == true end
    return ns.RecipeDB_Known(spellID)
end

-- The professions of the character shown when it is another one, in the shape of ns.Professions_Mine; nil for the playing one.
function ns.Roster_ViewedProfessions()
    if not (viewKey and viewRecord) then return nil end
    local list = {}
    for i, p in ipairs(viewRecord.professions or {}) do
        list[#list + 1] = {
            name = p.name, icon = p.icon, rank = p.rank or 0, maxRank = p.maxRank or 0, skillLine = p.skillLine,
            primary = p.primary and true or false, hasRecipes = p.hasRecipes ~= false, order = i,
            charLevel = viewRecord.level or false, -- (what it takes to train the next rank depends on it; false: not saved)
        }
    end
    return list
end

-- The icon of a profession as any character saved it (the game's own), nil when none has it.
function ns.Roster_Icon(skillLine)
    for _, record in pairs(characters()) do
        for _, p in ipairs(type(record) == "table" and record.professions or {}) do
            if p.skillLine == skillLine and p.icon then return p.icon end
        end
    end
    return nil
end

---------------------------------------------------------------------------------------------------
-- When to save
---------------------------------------------------------------------------------------------------
local pending = false

-- Soon, and once for a burst of events (learning a recipe fires several).
local function schedule(allowEmpty)
    if pending then return end
    pending = true
    C_Timer.After(3, function()
        pending = false
        ns.Roster_Snapshot(allowEmpty)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("PLAYER_LOGOUT")
pcall(events.RegisterEvent, events, "NEW_RECIPE_LEARNED") -- (not every client has it)
events:SetScript("OnEvent", function(_, event)
    if not ns.db then return end
    if event == "PLAYER_LOGOUT" then
        ns.Roster_Snapshot(true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        schedule(false)
    else
        schedule(true)
    end
end)
