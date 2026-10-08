dofile("setupTests.lua")

describe("Preferences", function()
    local ns

    local function click(f) f._scripts.OnClick(f) end

    local function button(text)
        return WowMock.Find(function(f) return f._text == text and f._scripts.OnClick ~= nil end)
    end

    before_each(function()
        WowMock.Reset()
        _G.GetProfessions = function() return nil end
        ns = LoadAddon()
        StartAddon(ns)
    end)

    it("opens and closes with the gear's toggle", function()
        ns.Prefs_Toggle()
        assert.is_true(_G.FabrikaoPreferencesFrame:IsShown())
        ns.Prefs_Toggle()
        assert.is_false(_G.FabrikaoPreferencesFrame:IsShown())
    end)

    it("closes with Escape", function()
        ns.Prefs_Toggle()
        local found = false
        for _, name in ipairs(UISpecialFrames) do if name == "FabrikaoPreferencesFrame" then found = true end end
        assert.is_true(found)
    end)

    describe("the view of the recipes", function()
        it("is a choice of the three views, with the current one checked", function()
            ns.Prefs_Toggle()
            local checks = _G.FabrikaoPreferencesFrame.viewChecks
            assert.is_true(checks.list:GetChecked())
            assert.is_false(checks.table:GetChecked())
            assert.is_false(checks.detailed:GetChecked())
        end)

        it("choosing one saves it and moves the check", function()
            ns.Prefs_Toggle()
            local checks = _G.FabrikaoPreferencesFrame.viewChecks
            checks.detailed:SetChecked(true)
            click(checks.detailed)
            assert.are.equal("detailed", ns.char.view)
            assert.is_true(checks.detailed:GetChecked())
            assert.is_false(checks.list:GetChecked())
            click(checks.table)
            assert.are.equal("table", ns.char.view)
        end)

        it("shows the saved one when it opens", function()
            ns.char.view = "table"
            ns.Prefs_Toggle()
            assert.is_true(_G.FabrikaoPreferencesFrame.viewChecks.table:GetChecked())
        end)
    end)

    it("the scale slider changes the window scale", function()
        ns.Prefs_Toggle()
        local slider = _G.FabrikaoPreferencesFrame.scaleSlider
        slider._scripts.OnValueChanged(slider, 1.2)
        assert.are.equal(1.2, ns.char.scale)
    end)

    it("says whether Auctionator is there", function()
        ns.Prefs_Toggle()
        local frame = _G.FabrikaoPreferencesFrame
        frame._scripts.OnShow(frame)
        assert.matches("not found", frame.prices._text)
        _G.Auctionator = { API = { v1 = {} } }
        frame._scripts.OnShow(frame)
        assert.matches("Auctionator found", frame.prices._text)
    end)

    describe("the buttons", function()
        it("reset the window's place and size", function()
            ns.UI_Toggle()
            ns.char.window = { w = 900, h = 700, point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
            ns.Prefs_Toggle()
            click(button("Reset window position and size"))
            assert.is_nil(ns.char.window)
        end)

        it("reset the filters", function()
            ns.char.filters = { canMake = true }
            ns.UI_Toggle()
            ns.Prefs_Toggle()
            click(button("Reset filters"))
            assert.is_falsy(ns.char.filters and ns.char.filters.canMake)
        end)

        it("restore the default preferences", function()
            ns.char.view = "detailed"
            ns.char.scale = 1.2
            ns.char.quiet = true
            ns.UI_Toggle()
            ns.Prefs_Toggle()
            click(button("Restore default preferences"))
            assert.are.equal("list", ns.char.view)
            assert.are.equal(1, ns.char.scale)
            assert.is_nil(ns.char.quiet)
            assert.is_true(_G.FabrikaoPreferencesFrame.viewChecks.list:GetChecked())
        end)
    end)

    it("the character specific checkbox switches between the character's and the shared settings", function()
        ns.char.view = "table"
        ns.Prefs_Toggle()
        local check = WowMock.Find(function(f) return f._template == "UICheckButtonTemplate" and f.Refresh end)
        check:SetChecked(false)
        click(check)
        assert.is_false(ns.IsPerCharacter())
        check:SetChecked(true)
        click(check)
        assert.is_true(ns.IsPerCharacter())
    end)
end)
