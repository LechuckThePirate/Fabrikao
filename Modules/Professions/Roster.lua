local _, ns = ...

-- The professions and known recipes of every character that has logged in with the addon, kept account-wide. The game cannot tell
-- what another character knows, so each character saves a copy of its own:
--   FabrikaoDB.characters[key] = { name =, realm =, class = "MAGE", ruleset =, level =, time =, professions = { { skillLine =, name =,
--     icon =, rank =, maxRank =, primary =, hasRecipes =, known = { spellID, ... } }, ... } }   (the professions in the window's order)
-- `known` holds the spells of the addon's data the character knows, per profession.
--
-- "Consolidate alts" (the switch in the title bar, ns.Consolidated) looks at the account as one, for the whole addon: a recipe any
-- character knows counts as known, the professions of all of them are listed (each once, with the alts that have it), and what each
-- of them can learn and craft now is on the start screen (only the playing one crafts). Only the characters of the playing one's
-- ruleset go together, as in Completao!!: the game has no query for a realm's ruleset, so each realm is one, plus whether Hardcore is on.

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

local function rulesetOf(realm, hardcore)
    return (realm or "?") .. (hardcore and "+HC" or "")
end

local function myRuleset()
    local hardcore = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
    return rulesetOf(GetRealmName and GetRealmName() or nil, hardcore)
end

-- Whether a saved character goes with the playing one (one saved before the ruleset was: by its realm).
local function sameRuleset(record)
    return (record.ruleset or rulesetOf(record.realm, false)) == myRuleset()
end

local knownSets = {} -- key -> the set of the spells an alt knows (built once: its copy does not change while another one plays)

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

    -- On Forever a two-word name ("Barby Turika") comes back cut to its first word from UnitName: the longest any call gives is the
    -- one Embolsao!! saves the character's bags under
    local fullName = UnitName("player")
    for _, other in ipairs({ GetUnitName and GetUnitName("player", false) or false, UnitFullName and UnitFullName("player") or false }) do
        if other and #other > #fullName then fullName = other end
    end

    ns.db.characters = ns.db.characters or {}
    ns.db.characters[key] = {
        name = UnitName("player"), fullName = fullName, realm = GetRealmName and GetRealmName() or "", class = classOf(), ruleset = myRuleset(),
        level = UnitLevel and UnitLevel("player") or nil, time = time and time() or 0, professions = professions,
    }
    knownSets[key] = nil
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

-- Does the character know the spell? (the spell book; with "Consolidate alts" on, any character of the account: what it saved)
function ns.Roster_Knows(spellID)
    if ns.RecipeDB_Known(spellID) then return true end
    if not ns.Consolidated() then return false end
    for _, alt in ipairs(ns.Roster_Alts()) do
        if ns.Roster_KnowsFor(alt.key, spellID) then return true end
    end
    return false
end

-- A saved character's professions, in the shape of ns.Professions_Mine, each with its `owner` (the character's key).
local function professionsOf(key, record)
    local list = {}
    for i, p in ipairs(record.professions or {}) do
        list[#list + 1] = {
            name = p.name, icon = p.icon, rank = p.rank or 0, maxRank = p.maxRank or 0, skillLine = p.skillLine,
            primary = p.primary and true or false, hasRecipes = p.hasRecipes ~= false, order = i, owner = key,
            charLevel = record.level or false, -- (what it takes to train the next rank depends on it; false: not saved)
        }
    end
    return list
end

---------------------------------------------------------------------------------------------------
-- Consolidate alts
---------------------------------------------------------------------------------------------------
-- The "Consolidate alts" switch is on.
function ns.Consolidated()
    return ns.char and ns.char.consolidateAlts and true or false
end

function ns.SetConsolidated(on)
    if not ns.char then return end
    ns.char.consolidateAlts = on and true or nil
    if ns.UI_ConsolidatedChanged then ns.UI_ConsolidatedChanged() end
end

-- The other characters of the playing one's ruleset with a saved copy, by name: { { key =, name =, label =, class =, level = }, ... }
function ns.Roster_Alts()
    local all = characters()
    local list = {}
    for _, info in ipairs(ns.Roster_Others()) do
        local record = all[info.key]
        if sameRuleset(record) then
            info.level = record.level
            list[#list + 1] = info
        end
    end
    return list
end

-- A character's name in its class color, from its key (nil: the playing one).
function ns.Roster_NameOf(key)
    if key == nil or key == myKey() then
        return ns.Roster_ColoredName({ label = UnitName("player"), class = classOf() })
    end
    for _, info in ipairs(ns.Roster_Others()) do
        if info.key == key then return ns.Roster_ColoredName(info) end
    end
    return key
end

-- The plain name of a saved character (as Embolsao!! names it too), from its key.
function ns.Roster_PlainName(key)
    local record = key and characters()[key]
    return type(record) == "table" and record.name or nil
end

-- The name Embolsao!! knows a saved character by: its whole name ("Barby Turika"), which copies of older versions lack (then the
-- short one, which ns.Inventory_CountFor matches by its first word).
function ns.Roster_BagsName(key)
    local record = key and characters()[key]
    if type(record) ~= "table" then return nil end
    return record.fullName or record.name
end

-- Does a character know the spell? `key` nil is the playing one (its spell book), else its saved copy.
function ns.Roster_KnowsFor(key, spellID)
    if key == nil or key == myKey() then return ns.RecipeDB_Known(spellID) end
    local set = knownSets[key]
    if not set then
        set = {}
        local record = characters()[key]
        for _, p in ipairs(type(record) == "table" and record.professions or {}) do
            for _, id in ipairs(p.known or {}) do set[id] = true end
        end
        knownSets[key] = set
    end
    return set[spellID] == true
end

-- A saved character's professions (see professionsOf), nil when it has no copy.
function ns.Roster_ProfessionsOf(key)
    local record = characters()[key]
    if type(record) ~= "table" then return nil end
    return professionsOf(key, record)
end

-- Who of the account knows the spell: the playing character first, then the alts of its ruleset by name:
-- { { key =, name =, label =, class =, me = true or nil }, ... }
function ns.Roster_KnownBy(spellID)
    local list = {}
    if ns.RecipeDB_Known(spellID) then
        local name = UnitName("player")
        list[1] = { name = name, label = name, class = classOf(), me = true }
    end
    for _, alt in ipairs(ns.Roster_Alts()) do
        if ns.Roster_KnowsFor(alt.key, spellID) then list[#list + 1] = alt end
    end
    return list
end

-- Names in their class colors, joined: "Elsa, Bob".
function ns.Roster_NamesText(list)
    local out = {}
    for i, info in ipairs(list) do out[i] = ns.Roster_ColoredName(info) end
    return table.concat(out, ", ")
end

-- The professions of the whole account, each once: the playing character's (with its own skill), then those only alts have (with the
-- best skill among them), in the order of ns.Professions_Mine. Each has `holders`, the alts that have it, by name (with their rank and
-- maxRank), and `owner`, whose skill it shows (nil: the playing character's).
function ns.Roster_AccountProfessions()
    local list, bySkill = {}, {}
    for _, p in ipairs(ns.Professions_Mine()) do
        local entry = { holders = {}, mine = true }
        for k, v in pairs(p) do entry[k] = v end
        list[#list + 1] = entry
        bySkill[p.skillLine] = entry
    end
    for _, alt in ipairs(ns.Roster_Alts()) do
        for _, p in ipairs(ns.Roster_ProfessionsOf(alt.key) or {}) do
            local entry = bySkill[p.skillLine]
            if not entry then
                entry = p
                entry.holders = {}
                list[#list + 1] = entry
                bySkill[p.skillLine] = entry
            elseif not entry.mine and p.rank > entry.rank then
                local holders = entry.holders -- the best skill among the alts is the one shown
                for k in pairs(entry) do entry[k] = nil end
                for k, v in pairs(p) do entry[k] = v end
                entry.holders = holders
            end
            entry.holders[#entry.holders + 1] = {
                key = alt.key, name = alt.name, label = alt.label, class = alt.class, rank = p.rank, maxRank = p.maxRank,
            }
        end
    end
    for i, entry in ipairs(list) do entry.order = i end
    table.sort(list, ns.Professions_Before)
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
-- An empty list of professions is only believed once the game has answered with some this session: while it loads (SKILL_LINES_CHANGED
-- fires then too) and while it logs out, it answers none, and saving that wiped the copy of every alt. A character that drops its last
-- profession had it listed before, so that is still saved.
local pending, answered = false, false

local function snapshot(allowEmpty)
    if ns.Professions_Mine and #ns.Professions_Mine() > 0 then answered = true end
    ns.Roster_Snapshot(allowEmpty and answered)
end

-- Soon, and once for a burst of events (learning a recipe fires several).
local function schedule(allowEmpty)
    if pending then return end
    pending = true
    C_Timer.After(3, function()
        pending = false
        snapshot(allowEmpty)
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
        snapshot(false) -- (the game may have let the professions go already)
    elseif event == "PLAYER_ENTERING_WORLD" then
        schedule(false)
        C_Timer.After(15, function() snapshot(false) end) -- again, for a game slow to load them
    else
        schedule(true)
    end
end)
