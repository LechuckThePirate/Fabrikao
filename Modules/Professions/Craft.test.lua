dofile("setupTests.lua")

describe("Craft", function()
    local ns, queued, opened, openSkill

    local function fire(event, ...)
        local frame = WowMock.Find(function(f) return f._events and f._events[event] and f._scripts.OnEvent end)
        frame._scripts.OnEvent(frame, event, ...)
    end

    local function lastLine() return WowMock.printed[#WowMock.printed] end

    local function run() -- the timers that were set, in order, until none is left
        while #queued > 0 do table.remove(queued, 1)() end
    end

    before_each(function()
        WowMock.Reset()
        queued, opened = {}, nil
        _G.C_Timer = { After = function(_, f) queued[#queued + 1] = f end, NewTicker = function() return { Cancel = function() end } end }
        openSkill = 171 -- the profession the game's window is open on (nil: none)
        _G.C_TradeSkillUI = {
            IsTradeSkillReady = function() return openSkill ~= nil end,
            GetBaseProfessionInfo = function() return openSkill and { professionID = openSkill } or nil end,
        }
        _G.OpenProfessionUIToSkillLine = function(skillLine) opened = skillLine end
        _G.C_Map = { GetAreaInfo = function() return nil end }
        ns = LoadAddon()
        ns.RECIPE_DATA = { recipes = {}, items = {}, trainers = {} }
    end)

    after_each(function()
        _G.C_Timer = { After = function(_, f) f() end, NewTicker = function() return { Cancel = function() end } end }
        _G.OpenProfessionUIToSkillLine = nil
    end)

    describe("with the profession's window open", function()
        it("does not open anything, and says nothing when the cast starts", function()
            local printed = #WowMock.printed
            ns.Craft_Clicked(2152, 171)
            fire("UNIT_SPELLCAST_START", "player", "guid", 2152)
            run()
            assert.is_nil(opened)
            assert.are.equal(printed, #WowMock.printed)
        end)

        it("says when the cast did not start", function()
            ns.Craft_Clicked(2152, 171)
            run()
            assert.matches("The game did not start crafting%.", lastLine())
        end)

        it("and why, with the errors the game gave", function()
            ns.Craft_Clicked(2152, 171)
            fire("UI_ERROR_MESSAGE", 50, "You need to be at a forge")
            run()
            assert.matches("did not start crafting: You need to be at a forge", lastLine())
        end)

        it("ignores other units' casts", function()
            ns.Craft_Clicked(2152, 171)
            fire("UNIT_SPELLCAST_START", "target", "guid", 99)
            run()
            assert.matches("did not start crafting", lastLine())
        end)

        it("a later recipe is not told off for an earlier one", function()
            ns.Craft_Clicked(2152, 171)
            ns.Craft_Clicked(2153, 171)
            fire("UNIT_SPELLCAST_START", "player", "guid", 2153)
            local printed = #WowMock.printed
            run()
            assert.are.equal(printed, #WowMock.printed)
        end)
    end)

    describe("with the window closed", function()
        it("opens the game's profession window on the profession, and says to click again", function()
            openSkill = nil
            ns.Craft_Clicked(2152, 171)
            assert.are.equal(171, opened)
            assert.matches("Opening the profession window: click Craft again", lastLine())
        end)

        it("opens it when another profession's window is the one open", function()
            openSkill = 164
            ns.Craft_Clicked(2152, 171)
            assert.are.equal(171, opened)
        end)

        it("opens it while the game is still switching its data", function()
            _G.C_TradeSkillUI.IsDataSourceChanging = function() return true end
            ns.Craft_Clicked(2152, 171)
            assert.are.equal(171, opened)
        end)

        it("opens it when the game does not know the recipe yet", function()
            _G.C_TradeSkillUI.GetRecipeInfo = function() return nil end
            ns.Craft_Clicked(2152, 171)
            assert.are.equal(171, opened)
        end)

        it("falls back to opening the trade skill when the game's helper is missing", function()
            openSkill = nil
            _G.OpenProfessionUIToSkillLine = nil
            _G.C_TradeSkillUI.OpenTradeSkill = function(skillLine) opened = skillLine end
            ns.Craft_Clicked(2152, 171)
            assert.are.equal(171, opened)
        end)

        it("says so when there is no way to open it", function()
            openSkill = nil
            _G.OpenProfessionUIToSkillLine = nil
            ns.Craft_Clicked(2152, 171)
            assert.matches("Open the profession window to craft", lastLine())
        end)
    end)
end)
