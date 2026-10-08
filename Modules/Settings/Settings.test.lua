dofile("setupTests.lua")

describe("Settings", function()
    local ns

    local function login(charDB, accountDB)
        _G.FabrikaoDB, _G.FabrikaoCharDB = accountDB, charDB
        ns = LoadAddon({ files = { "Modules/Settings/Settings.lua" } })
        ns.InitSettings()
        return ns
    end

    before_each(function() WowMock.Reset() end)

    it("creates the saved variables on the first login, per character", function()
        login(nil, nil)
        assert.is_not_nil(FabrikaoDB)
        assert.is_not_nil(FabrikaoCharDB)
        assert.are.equal(FabrikaoDB, ns.db)
        assert.is_true(ns.IsPerCharacter())
    end)

    it("keeps what was already saved", function()
        local account, char = { welcomed = true }, { quiet = true }
        login(char, account)
        assert.is_true(ns.db.welcomed)
        assert.is_true(ns.char.quiet)
    end)

    it("a setting never touched reads as its default; false is kept", function()
        login({}, {})
        ns.DEFAULTS.minimap = true
        assert.is_true(ns.char.minimap)
        ns.char.minimap = false
        assert.is_false(ns.char.minimap)
    end)

    it("the shared settings start with the first character's", function()
        local account = {}
        login({ quiet = true }, account)
        assert.is_true(account.shared.quiet)
    end)

    it("per character, changes don't touch the shared ones", function()
        local char, account = { quiet = true }, {}
        login(char, account)
        ns.char.quiet = false
        assert.is_false(char.quiet)
        assert.is_true(account.shared.quiet)
    end)

    it("switching to shared reads and writes the shared ones; the character's copy stays", function()
        local char, account = { quiet = false }, {}
        login(char, account)
        account.shared.quiet = true
        ns.SetPerCharacter(false)
        assert.is_false(ns.IsPerCharacter())
        assert.is_true(ns.char.quiet)
        ns.char.quiet = false
        assert.is_false(account.shared.quiet)
        assert.is_false(char.quiet)
    end)

    it("switching back to per character copies the shared ones, and re-applies the settings", function()
        local char, account = {}, {}
        login(char, account)
        local applied = 0
        ns.Minimap_Init = function() applied = applied + 1 end
        ns.SetPerCharacter(false)
        ns.char.quiet = true
        local before = applied
        ns.SetPerCharacter(true)
        assert.is_true(char.quiet)
        assert.are.equal(before + 1, applied)
        ns.SetPerCharacter(true) -- nothing changes
        assert.are.equal(before + 1, applied)
    end)

    it("the view and the window scale are switchable settings with their defaults", function()
        local char, account = {}, {}
        login(char, account)
        assert.are.equal("table", ns.char.view)
        assert.are.equal(1, ns.char.scale)
        ns.char.view = "detailed"
        assert.are.equal("detailed", char.view)
        ns.SetPerCharacter(false)
        assert.are.equal("table", ns.char.view) -- the shared ones
    end)

    it("restoring the defaults clears the settings, the window and the filters, and tells the window", function()
        local char = { view = "detailed", scale = 1.2, quiet = true, window = { w = 900 }, filters = { canMake = true }, collapsed = { known = true } }
        local account = {}
        login(char, account)
        local applied, minimap = 0, 0
        ns.UI_ApplySettings = function() applied = applied + 1 end
        ns.Minimap_Init = function() minimap = minimap + 1 end
        ns.ResetSettings()
        assert.are.equal("table", ns.char.view)
        assert.are.equal(1, ns.char.scale)
        assert.is_nil(char.quiet)
        assert.is_nil(char.window)
        assert.is_nil(char.filters)
        assert.is_nil(char.collapsed)
        assert.are.equal(1, applied)
        assert.are.equal(1, minimap)
    end)

    it("keys outside the switchable ones always belong to the character", function()
        local char, account = {}, {}
        login(char, account)
        ns.SetPerCharacter(false)
        ns.char.somethingElse = 1
        assert.are.equal(1, char.somethingElse)
        assert.is_nil(account.shared.somethingElse)
    end)
end)
