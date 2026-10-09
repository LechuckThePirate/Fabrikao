dofile("setupTests.lua")

describe("Craft", function()
    local ns, calls, queued, opened, openSkill

    local function fire(event, ...)
        local frame = WowMock.Find(function(f) return f._events and f._events[event] and f._scripts.OnEvent end)
        frame._scripts.OnEvent(frame, event, ...)
    end

    local function lastLine() return WowMock.printed[#WowMock.printed] end

    local function run(queue) -- the timers that were set, in order, until none is left
        while #queue > 0 do table.remove(queue, 1)() end
    end

    before_each(function()
        WowMock.Reset()
        calls, queued, opened, openSkill = {}, {}, 0, nil
        _G.C_Timer = { After = function(_, f) queued[#queued + 1] = f end, NewTicker = function() return { Cancel = function() end } end }
        openSkill = 171 -- the profession the game's window is open on (nil: none)
        _G.C_TradeSkillUI = {
            IsTradeSkillReady = function() return openSkill ~= nil end,
            GetBaseProfessionInfo = function() return openSkill and { professionID = openSkill } or nil end,
            CraftRecipe = function(id, count) calls[#calls + 1] = { id = id, count = count } end,
        }
        _G.OpenProfessionUIToSkillLine = nil
        _G.C_Map = { GetAreaInfo = function() return nil end }
        ns = LoadAddon()
        ns.RECIPE_DATA = { recipes = {}, items = {}, trainers = {} }
    end)

    after_each(function()
        _G.C_Timer = { After = function(_, f) f() end, NewTicker = function() return { Cancel = function() end } end }
        _G.OpenProfessionUIToSkillLine = nil
    end)

    describe("with the profession open", function()
        it("asks the game to craft the recipe, as many times as asked", function()
            assert.is_true(ns.Craft_Make(2152, 3, 171))
            assert.are.same({ { id = 2152, count = 3 } }, calls)
        end)

        it("keeps the amount between 1 and 999, and a whole number", function()
            ns.Craft_Make(1, 0, 171)
            ns.Craft_Make(1, 5000, 171)
            ns.Craft_Make(1, 2.7, 171)
            ns.Craft_Make(1, nil, 171)
            assert.are.same({ 1, 999, 2, 1 }, { calls[1].count, calls[2].count, calls[3].count, calls[4].count })
        end)

        it("says in the chat what the call did", function()
            ns.Craft_Make(2152, 1, 171)
            assert.matches("recipe 2152 x1: profession window open, call accepted", lastLine())
        end)

        it("says when the call failed, and returns false", function()
            _G.C_TradeSkillUI.CraftRecipe = function() error("no profession open") end
            assert.is_false(ns.Craft_Make(2152, 1, 171))
            assert.matches("call failed: .*no profession open", lastLine())
        end)

        it("says whether the cast started", function()
            ns.Craft_Make(2152, 1, 171)
            fire("UNIT_SPELLCAST_START", "player", "guid", 2152)
            run(queued)
            assert.matches("the cast started", lastLine())
        end)

        it("says that it did not, with the errors the game gave", function()
            ns.Craft_Make(2152, 1, 171)
            fire("UI_ERROR_MESSAGE", 50, "You need to be at a forge")
            run(queued)
            assert.matches("the cast did not start: You need to be at a forge", lastLine())
        end)

        it("ignores other units' casts", function()
            ns.Craft_Make(2152, 1, 171)
            fire("UNIT_SPELLCAST_START", "target", "guid", 99)
            run(queued)
            assert.matches("did not start %(no error given%)", lastLine())
        end)
    end)

    describe("with the profession not open", function()
        it("opens the game's profession window the way the game does, then crafts when it is ready", function()
            openSkill = nil
            _G.OpenProfessionUIToSkillLine = function(skillLine) opened = skillLine end
            ns.Craft_Make(2152, 2, 171)
            assert.are.equal(171, opened)
            assert.are.same({}, calls) -- not yet: it is loading
            table.remove(queued, 1)() -- a wait goes by, still not ready
            assert.are.same({}, calls)
            openSkill = 171
            run(queued)
            assert.are.same({ { id = 2152, count = 2 } }, calls)
            assert.matches("the cast did not start", lastLine()) -- (nothing cast in the test)
        end)

        it("falls back to opening the trade skill when the game's helper is missing", function()
            openSkill = nil
            _G.C_TradeSkillUI.OpenTradeSkill = function(skillLine) opened = skillLine; openSkill = skillLine end
            ns.Craft_Make(2152, 1, 171)
            run(queued)
            assert.are.equal(171, opened)
            assert.are.equal(1, #calls)
        end)

        it("does not craft, and says so, when the profession never gets ready", function()
            openSkill = nil
            _G.OpenProfessionUIToSkillLine = function() end
            ns.Craft_Make(2152, 1, 171)
            run(queued)
            assert.are.same({}, calls)
            assert.matches("did not get ready in time", lastLine())
        end)

        it("opens it again when another profession's window is the one open", function()
            openSkill = 164
            _G.OpenProfessionUIToSkillLine = function(skillLine) opened = skillLine; openSkill = skillLine end
            ns.Craft_Make(2152, 1, 171)
            run(queued)
            assert.are.equal(171, opened)
            assert.are.equal(1, #calls)
        end)
    end)

    it("without the craft API it says so", function()
        _G.C_TradeSkillUI = nil
        assert.is_false(ns.Craft_Make(2152, 1, 171))
        assert.matches("can't craft from here", lastLine())
    end)
end)
