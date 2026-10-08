dofile("setupTests.lua")

describe("Inventory", function()
    local ns, bags, bank

    before_each(function()
        WowMock.Reset()
        bags, bank = { [10] = 5 }, { [10] = 2, [11] = 3 } -- the character's own: GetItemCount(id) bags, (id, true) with the bank
        _G.C_Item = { GetItemCount = function(id, includeBank)
            return (bags[id] or 0) + (includeBank and (bank[id] or 0) or 0)
        end }
        _G.UnitName = function() return "Therzok" end
        _G.UnitClass = function() return "Warrior", "WARRIOR" end
        _G.RAID_CLASS_COLORS = { MAGE = { colorStr = "ff3fc7eb" } }
        _G.EmbolsaoDB = { characterItems = {
            ["Therzok-Realm"] = { name = "Therzok", class = "WARRIOR", time = 5, bags = { [10] = 99 }, bank = {} }, -- my own (stale) copy
            ["Elsa-Realm"] = { name = "Elsa", class = "MAGE", time = 10, bags = { [10] = 4 }, bank = { [11] = 6 } },
            ["Bad Yuyu-Realm"] = { name = "Bad Yuyu", class = "WARLOCK", time = 10, bags = { [11] = 1 } },
        } }
        ns = LoadAddon({ files = { "Modules/Data/Inventory.lua" } })
        ns.char = {}
    end)

    it("lists the other characters by name, not the one playing", function()
        local others = ns.Inventory_Others()
        assert.are.equal(2, #others)
        assert.are.equal("Bad Yuyu", others[1].name)
        assert.are.equal("Elsa", others[2].name)
        assert.are.equal("MAGE", others[2].class)
    end)

    it("a character saved under several keys counts once, the newest copy", function()
        EmbolsaoDB.characterItems["Elsa-Other"] = { name = "Elsa", class = "MAGE", time = 20, bags = { [10] = 1 }, bank = {} }
        local others = ns.Inventory_Others()
        assert.are.equal(2, #others)
        assert.are.equal(1, others[2].bags[10])
    end)

    it("is not available without Embolsao's data, with no other characters, or with the preference off", function()
        assert.is_true(ns.Inventory_Available())
        ns.char.useAlts = false
        assert.is_false(ns.Inventory_Available())
        ns.char.useAlts = nil
        _G.EmbolsaoDB = nil
        assert.is_false(ns.Inventory_Available())
        assert.are.same({}, ns.Inventory_Others())
        _G.EmbolsaoDB = { characterItems = { ["Therzok-Realm"] = { name = "Therzok", bags = {} } } }
        assert.is_false(ns.Inventory_Available())
    end)

    it("counts only the character's bags by default", function()
        assert.are.equal(5, ns.Inventory_Count(10))
        assert.are.equal(0, ns.Inventory_Count(11))
    end)

    it("counts the character's bank and the other characters' bags and banks with alts", function()
        assert.are.equal(5 + 2 + 4, ns.Inventory_Count(10, true)) -- mine in bags and bank, Elsa's bags
        assert.are.equal(3 + 6 + 1, ns.Inventory_Count(11, true)) -- my bank, Elsa's bank, Bad Yuyu's bags
        assert.are.equal(0, ns.Inventory_Count(99, true))
    end)

    it("says what the others have in all", function()
        assert.are.equal(4, ns.Inventory_OthersTotal(10))
        assert.are.equal(7, ns.Inventory_OthersTotal(11))
    end)

    it("tells who has an item: the character first, then the others", function()
        local list = ns.Inventory_Breakdown(11)
        assert.are.equal(3, #list)
        assert.is_true(list[1].me)
        assert.are.equal(0, list[1].bags)
        assert.are.equal(3, list[1].bank)
        assert.are.equal("Bad Yuyu", list[2].name)
        assert.are.equal(1, list[2].bags)
        assert.are.equal("Elsa", list[3].name)
        assert.are.equal(6, list[3].bank)
    end)

    it("has no breakdown without other characters", function()
        _G.EmbolsaoDB = nil
        assert.is_nil(ns.Inventory_Breakdown(10))
    end)

    it("writes a line with the name in its class color", function()
        assert.are.equal("|cff3fc7ebElsa|r: 4 in bags, 6 in bank", ns.Inventory_Line({ name = "Elsa", class = "MAGE", bags = 4, bank = 6 }))
        assert.are.equal("Bad Yuyu: 1 in bags", ns.Inventory_Line({ name = "Bad Yuyu", class = "WARLOCK", bags = 1, bank = 0 }))
    end)
end)
