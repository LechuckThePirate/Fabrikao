dofile("setupTests.lua")

describe("Quests (Completao)", function()
    local ns

    before_each(function()
        WowMock.Reset()
        _G.CompletaoAPI = nil
        ns = LoadAddon({ files = { "Modules/Data/Quests.lua" } })
    end)

    after_each(function() _G.CompletaoAPI = nil end)

    it("without Completao nothing is known and nothing opens", function()
        assert.is_false(ns.Quests_Known(38))
        assert.is_false(ns.Quests_Show(38))
    end)

    it("asks Completao's API", function()
        local shown
        _G.CompletaoAPI = {
            version = 1,
            HasQuest = function(id) return id == 38 end,
            ShowQuest = function(id) shown = id; return true end,
        }
        assert.is_true(ns.Quests_Known(38))
        assert.is_false(ns.Quests_Known(39))
        assert.is_false(ns.Quests_Known(nil))
        assert.is_true(ns.Quests_Show(38))
        assert.are.equal(38, shown)
    end)

    it("an API without the functions (another version) is the same as none", function()
        _G.CompletaoAPI = { version = 99 }
        assert.is_false(ns.Quests_Known(38))
        assert.is_false(ns.Quests_Show(38))
    end)
end)
