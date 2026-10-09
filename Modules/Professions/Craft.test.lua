dofile("setupTests.lua")

describe("Craft", function()
    local ns, calls, queued

    local function fire(event, ...)
        local frame = WowMock.Find(function(f) return f._events and f._events[event] and f._scripts.OnEvent end)
        frame._scripts.OnEvent(frame, event, ...)
    end

    local function lastLine() return WowMock.printed[#WowMock.printed] end

    before_each(function()
        WowMock.Reset()
        calls, queued = {}, {}
        _G.C_Timer = { After = function(_, f) queued[#queued + 1] = f end, NewTicker = function() return { Cancel = function() end } end }
        _G.C_TradeSkillUI = {
            IsTradeSkillReady = function() return true end,
            CraftRecipe = function(id, count) calls[#calls + 1] = { id = id, count = count } end,
        }
        ns = LoadAddon()
    end)

    after_each(function() _G.C_Timer = { After = function(_, f) f() end, NewTicker = function() return { Cancel = function() end } end } end)

    it("asks the game to craft the recipe, as many times as asked", function()
        assert.is_true(ns.Craft_Make(2152, 3))
        assert.are.same({ { id = 2152, count = 3 } }, calls)
    end)

    it("keeps the amount between 1 and 999, and a whole number", function()
        ns.Craft_Make(1, 0)
        ns.Craft_Make(1, 5000)
        ns.Craft_Make(1, 2.7)
        ns.Craft_Make(1, nil)
        assert.are.same({ 1, 999, 2, 1 }, { calls[1].count, calls[2].count, calls[3].count, calls[4].count })
    end)

    it("says in the chat what the profession API and the call did", function()
        ns.Craft_Make(2152, 1)
        assert.matches("recipe 2152 x1: profession API ready, call accepted", lastLine())
        _G.C_TradeSkillUI.IsTradeSkillReady = function() return false end
        ns.Craft_Make(2152, 1)
        assert.matches("profession API NOT ready", lastLine())
    end)

    it("says when the call failed, and returns false", function()
        _G.C_TradeSkillUI.CraftRecipe = function() error("no profession open") end
        assert.is_false(ns.Craft_Make(2152, 1))
        assert.matches("call failed: .*no profession open", lastLine())
    end)

    it("says whether the cast started", function()
        ns.Craft_Make(2152, 1)
        fire("UNIT_SPELLCAST_START", "player", "guid", 2152)
        queued[#queued]()
        assert.matches("the cast started", lastLine())
    end)

    it("says that it did not, with the errors the game gave", function()
        ns.Craft_Make(2152, 1)
        fire("UI_ERROR_MESSAGE", 50, "You need to be at a forge")
        queued[#queued]()
        assert.matches("the cast did not start: You need to be at a forge", lastLine())
    end)

    it("ignores other units' casts", function()
        ns.Craft_Make(2152, 1)
        fire("UNIT_SPELLCAST_START", "target", "guid", 99)
        queued[#queued]()
        assert.matches("did not start %(no error given%)", lastLine())
    end)

    it("without the craft API it says so", function()
        _G.C_TradeSkillUI = nil
        assert.is_false(ns.Craft_Make(2152, 1))
        assert.matches("can't craft from here", lastLine())
    end)
end)
