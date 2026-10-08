local _, ns = ...
local L = ns.L

-- What the other characters carry and keep in their banks, to count ingredients across the account. Embolsao saves it for
-- every character (account-wide, at logout and after every bag change) in EmbolsaoDB.characterItems:
--   [key] = { name =, class = "MAGE", time =, bags = { [itemID] = count }, bank = { [itemID] = count }, ... }
-- It is read as it is saved: Embolsao has no public API for it yet. Without Embolsao (or with the preference off) none of
-- this exists and every count is the character's own.

local function saved()
    if ns.char and ns.char.useAlts == false then return nil end
    return EmbolsaoDB and EmbolsaoDB.characterItems
end

local function identity(name)
    return ((name or ""):gsub("%s", "")):lower()
end

local function nameOf(key, info)
    return (info and info.name) or (key or ""):match("^(.-)%-") or key
end

-- Every OTHER character with something saved, each once (the newest copy when one is saved under several keys), by name:
-- { { key =, name =, class =, time =, bags =, bank = }, ... }
function ns.Inventory_Others()
    local others = {}
    local mine = identity(UnitName and UnitName("player"))
    local newest = {}
    for key, info in pairs(saved() or {}) do
        local name = nameOf(key, info)
        local id = identity(name)
        local seen = newest[id]
        if id ~= mine and type(info) == "table" and (not seen or (info.time or 0) > (seen.time or 0)) then
            newest[id] = { key = key, name = name, class = info.class, time = info.time, bags = info.bags or {}, bank = info.bank or {} }
        end
    end
    for _, character in pairs(newest) do others[#others + 1] = character end
    table.sort(others, function(a, b) return a.name < b.name end)
    return others
end

-- Are there other characters to count?
function ns.Inventory_Available()
    return #ns.Inventory_Others() > 0
end

-- The character's own: in the bags, and in the bank (what the client has of it: the bank's copy since the last visit).
function ns.Inventory_Mine(itemID)
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    local bags = count(itemID) or 0
    local both = count(itemID, true) or bags
    return bags, math.max(0, both - bags)
end

-- How many of an item there are: only in the character's bags by default, or with `alts`, everything: its own bags and
-- bank and the bags and banks of the other characters.
function ns.Inventory_Count(itemID, alts)
    local bags, bank = ns.Inventory_Mine(itemID)
    if not alts then return bags end
    local total = bags + bank
    for _, character in ipairs(ns.Inventory_Others()) do
        total = total + (character.bags[itemID] or 0) + (character.bank[itemID] or 0)
    end
    return total
end

-- Who has the item: { { name =, class =, bags =, bank =, me = true or nil }, ... }, the character first, then the others by
-- name; only those with some. Nil when there are no other characters to tell from.
function ns.Inventory_Breakdown(itemID)
    if not ns.Inventory_Available() then return nil end
    local list = {}
    local bags, bank = ns.Inventory_Mine(itemID)
    if bags > 0 or bank > 0 then
        local class = UnitClass and select(2, UnitClass("player"))
        list[#list + 1] = { name = UnitName("player"), class = class, bags = bags, bank = bank, me = true }
    end
    for _, character in ipairs(ns.Inventory_Others()) do
        local inBags, inBank = character.bags[itemID] or 0, character.bank[itemID] or 0
        if inBags > 0 or inBank > 0 then
            list[#list + 1] = { name = character.name, class = character.class, bags = inBags, bank = inBank }
        end
    end
    return list
end

-- The same as a line of text: "Elsa: 5 in bags, 2 in bank" (the name in its class color).
function ns.Inventory_Line(entry)
    local color = entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class]
    local name = color and ("|c" .. (color.colorStr or "ffffffff") .. entry.name .. "|r") or entry.name
    local parts = {}
    if entry.bags > 0 then parts[#parts + 1] = L["%d in bags"]:format(entry.bags) end
    if entry.bank > 0 then parts[#parts + 1] = L["%d in bank"]:format(entry.bank) end
    return name .. ": " .. table.concat(parts, ", ")
end

-- How many of an item the OTHER characters have in all (bags and banks).
function ns.Inventory_OthersTotal(itemID)
    local total = 0
    for _, character in ipairs(ns.Inventory_Others()) do
        total = total + (character.bags[itemID] or 0) + (character.bank[itemID] or 0)
    end
    return total
end
