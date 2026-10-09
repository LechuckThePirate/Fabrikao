dofile("setupTests.lua")

describe("Craft", function()
    local ns, toRecipe, openedSkill

    local function lastLine() return WowMock.printed[#WowMock.printed] end

    before_each(function()
        WowMock.Reset()
        toRecipe, openedSkill = nil, nil
        _G.ProfessionsUtil = { OpenProfessionFrameToRecipe = function(recipeID) toRecipe = recipeID; return true end }
        _G.OpenProfessionUIToSkillLine = function(skillLine) openedSkill = skillLine end
        _G.C_TradeSkillUI = nil
        ns = LoadAddon()
    end)

    after_each(function()
        _G.ProfessionsUtil, _G.OpenProfessionUIToSkillLine = nil, nil
    end)

    it("opens the game's profession window on the recipe, the way the game does it for its own alerts", function()
        assert.is_true(ns.Craft_Open(2152, 165))
        assert.are.equal(2152, toRecipe)
        assert.is_nil(openedSkill)
    end)

    it("opens the profession when the game's helper can't place the recipe", function()
        _G.ProfessionsUtil.OpenProfessionFrameToRecipe = function() return false end
        assert.is_true(ns.Craft_Open(2152, 165))
        assert.are.equal(165, openedSkill)
    end)

    it("and when the helper fails with an error", function()
        _G.ProfessionsUtil.OpenProfessionFrameToRecipe = function() error("no data") end
        assert.is_true(ns.Craft_Open(2152, 165))
        assert.are.equal(165, openedSkill)
    end)

    it("opens the profession when the helper does not exist", function()
        _G.ProfessionsUtil = nil
        assert.is_true(ns.Craft_Open(2152, 165))
        assert.are.equal(165, openedSkill)
    end)

    it("falls back to the trade skill when the game's profession helper is missing too", function()
        _G.ProfessionsUtil, _G.OpenProfessionUIToSkillLine = nil, nil
        local opened
        _G.C_TradeSkillUI = { OpenTradeSkill = function(skillLine) opened = skillLine end }
        assert.is_true(ns.Craft_Open(2152, 165))
        assert.are.equal(165, opened)
    end)

    it("says so when there is no way to open it", function()
        _G.ProfessionsUtil, _G.OpenProfessionUIToSkillLine = nil, nil
        assert.is_false(ns.Craft_Open(2152, 165))
        assert.matches("Could not open the profession window", lastLine())
    end)

    it("says so when it does not know the profession either", function()
        _G.ProfessionsUtil.OpenProfessionFrameToRecipe = function() return false end
        assert.is_false(ns.Craft_Open(2152, nil))
        assert.matches("Could not open the profession window", lastLine())
    end)
end)
