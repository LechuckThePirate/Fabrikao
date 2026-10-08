dofile("setupTests.lua")

describe("Professions", function()
    local ns

    -- the game's professions: index -> { name, icon, rank, maxRank, skillLine }
    local function givenProfessions(returned, info)
        _G.GetProfessions = function() return unpack(returned, 1, 6) end
        _G.GetProfessionInfo = function(index)
            local p = info[index]
            if not p then return nil end
            return p[1], p[2], p[3], p[4], 1, index * 10, p[5], 0
        end
    end

    before_each(function()
        WowMock.Reset()
        ns = LoadAddon()
    end)

    it("lists the primary professions first, then First Aid, Cooking and Fishing", function()
        -- the game's slots: two primary, archaeology (none), fishing, cooking, first aid
        givenProfessions({ 1, 2, nil, 4, 3, 5 }, {
            [1] = { "Blacksmithing", 100, 150, 300, 164 },
            [2] = { "Mining", 101, 75, 300, 186 },
            [3] = { "Cooking", 102, 200, 300, 185 },
            [4] = { "Fishing", 103, 10, 75, 356 },
            [5] = { "First Aid", 104, 50, 300, 129 },
        })
        local names = {}
        for _, p in ipairs(ns.Professions_List()) do names[#names + 1] = p.name end
        assert.are.same({ "Blacksmithing", "Mining", "First Aid", "Cooking", "Fishing" }, names)
    end)

    it("marks primary and secondary ones, with rank and icon", function()
        givenProfessions({ 1, 2 }, {
            [1] = { "Alchemy", 111, 42, 300, 171 },
            [2] = { "Cooking", 222, 7, 75, 185 },
        })
        local list = ns.Professions_List()
        assert.is_true(list[1].primary)
        assert.are.equal(42, list[1].rank)
        assert.are.equal(300, list[1].maxRank)
        assert.are.equal(111, list[1].icon)
        assert.is_false(list[2].primary)
        assert.are.equal(171, list[1].skillLine)
    end)

    it("leaves archaeology out and survives no professions at all", function()
        givenProfessions({ nil, nil, 1 }, { [1] = { "Archaeology", 1, 1, 1, 794 } })
        assert.are.same({}, ns.Professions_List())
        _G.GetProfessions = nil
        assert.are.same({}, ns.Professions_List())
    end)

    it("knows which professions have a crafting window", function()
        givenProfessions({ 1, 2 }, {
            [1] = { "Alchemy", 1, 1, 300, 171 },
            [2] = { "Herbalism", 2, 1, 300, 182 },
        })
        _G.Enum = { SpellBookSpellBank = { Player = 0 } }
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function(spellID) return spellID == 11 end }
        local list = ns.Professions_List()
        assert.is_true(list[1].hasRecipes)
        assert.is_false(list[2].hasRecipes)
    end)

    it("finds one profession by its skill line", function()
        givenProfessions({ 1 }, { [1] = { "Tailoring", 1, 1, 300, 197 } })
        assert.are.equal("Tailoring", ns.Professions_Get(197).name)
        assert.is_nil(ns.Professions_Get(1))
    end)
end)
