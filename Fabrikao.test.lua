dofile("setupTests.lua")

describe("Fabrikao (startup)", function()
    local ns

    before_each(function()
        WowMock.Reset()
        ns = LoadAddon()
    end)

    it("loads every TOC file", function()
        assert.is_not_nil(ns.L)
        assert.are.equal("function", type(ns.InitSettings))
        assert.are.equal("function", type(ns.Print))
    end)

    it("on entering, sets up the saved variables and announces in chat", function()
        StartAddon(ns)
        assert.is_not_nil(FabrikaoDB)
        assert.is_not_nil(FabrikaoCharDB)
        assert.matches("initializing", WowMock.printed[1])
        assert.matches("initialization complete", WowMock.printed[2])
    end)

    it("with messages turned off, writes nothing to chat", function()
        StartAddon(ns, nil, { quiet = true })
        assert.are.equal(0, #WowMock.printed)
    end)

    it("ignores other addons' ADDON_LOADED", function()
        _G.FabrikaoDB, _G.FabrikaoCharDB = nil, nil
        FireEvent("ADDON_LOADED", "SomethingElse")
        assert.is_nil(FabrikaoDB)
        assert.are.equal(0, #WowMock.printed)
    end)

    it("registers /fabrikao and /fab", function()
        assert.are.equal("/fabrikao", SLASH_FABRIKAO1)
        assert.are.equal("/fab", SLASH_FABRIKAO2)
        assert.are.equal("function", type(SlashCmdList.FABRIKAO))
    end)

    it("/fabrikao version prints the TOC version, anything else the usage", function()
        SlashCmdList.FABRIKAO("version")
        assert.matches("v0%.0%.0%-test", WowMock.printed[1])
        SlashCmdList.FABRIKAO("nonsense")
        assert.matches("Usage", WowMock.printed[2])
    end)
end)
