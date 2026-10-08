dofile("setupTests.lua")

describe("Probe", function()
    local ns

    before_each(function()
        WowMock.Reset()
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 80, 300, 1, 10, 171, 0 end
        _G.GetBuildInfo = function() return "1.60.1", "70245" end
        _G.C_SpellBook = { IsSpellKnown = function(id) return id == 100 end }
        _G.Enum = { SpellBookSpellBank = { Player = 0 } }
        ns = LoadAddon()
        ns.RECIPE_DATA = {
            recipes = { [100] = { s = 171, n = "Elixir", c = { 1, 2, 3, 4 } }, [101] = { s = 171, n = "Flask", c = { 5, 6, 7, 8 } } },
            items = {}, trainers = {},
        }
        StartAddon(ns)
    end)

    it("counts the data's recipes the client says are known, and keeps the result", function()
        ns.Probe()
        local entry = FabrikaoDB.probe.professions[1]
        assert.are.equal("Alchemy", entry.name)
        assert.are.equal(2, entry.total)
        assert.are.equal(1, entry.isSpellKnown)
        assert.are.equal(1, entry.union)
        assert.are.same({ "Elixir" }, entry.sample)
        assert.are.equal(2, FabrikaoDB.probe.recipesInData)
        assert.matches("Probe finished", WowMock.printed[#WowMock.printed])
    end)
end)
