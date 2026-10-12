dofile("setupTests.lua")

-- The trainers of a profession, nearest first, with the map and waypoint buttons.
describe("Trainers", function()
    local ns, distances, mapped, waypoints

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 1 }, m = { { 10, 2 } }, k = { 6 } },
        },
        items = {},
        trainers = {
            [171] = {
                { id = 10, n = "Far Ben", t = "Alchemist", z = { 46 } },
                { id = 9, n = "Near Anna", t = "Master Alchemist", z = { 1519 }, f = "A" },
                { id = 11, n = "Horde Hank", z = { 1637 }, f = "H" },
                { id = 12, n = "Lost Nell", z = { 46 } },
                { id = 13, n = "Same Map Sam", z = { 12 } },
            },
        },
        -- where they stand: { map, x, y }
        npcs = { [9] = { 1453, 40, 60 }, [10] = { 36, 30, 20 }, [11] = { 1454, 50, 50 }, [13] = { 1453, 10, 10 } },
    }

    local function framesWith(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function trainersButton()
        return WowMock.FindAll(function(f)
            return f._text == "Trainers" and f._scripts.OnClick and f:IsVisible()
        end)[1]
    end

    local function panel() return _G.FabrikaoTrainersFrame end

    local function rows() return framesWith("tomButton") end

    local function firstLine(row) return (row.text._text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^[^\n]*")) end

    local function openAlchemy()
        ns.UI_Show()
        for _, b in ipairs(framesWith("profession")) do
            if b.profession.skillLine == 171 then click(b) end
        end
    end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 111, 150, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { GetSpellBookItemInfo = function(slot) return { spellID = slot } end, IsSpellKnown = function() return false end }
        _G.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function() return true end }
        _G.C_Item = { GetItemCount = function() return 0 end }
        _G.C_Map = { GetAreaInfo = function(id) return ({ [46] = "Burning Steppes", [1519] = "Stormwind City", [1637] = "Orgrimmar", [12] = "Elwynn" })[id] end,
            GetBestMapForUnit = function() return 1453 end }
        _G.UnitName = function() return "Tester" end
        _G.GetRealmName = function() return "Realm" end
        _G.EmbolsaoAPI, _G.EmbolsaoDB = nil, nil
        _G.TomTom = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        -- yards from the character, by the map the spot is on (Stormwind's 40,60 is the nearest)
        distances = { [1453] = 350, [36] = 4000 }
        ns.Map_Distance = function(spot)
            if spot.map == 1453 and spot.x == 10 then return nil end -- no tell: only that it is on the character's map
            return distances[spot.map]
        end
        mapped, waypoints = {}, {}
        ns.Map_Show = function(spot) mapped[#mapped + 1] = spot return true end
        StartAddon(ns)
    end)

    describe("the data", function()
        it("lists the trainers of the profession for the character's side, nearest first", function()
            local list, total = ns.RecipeDB_Trainers(171)
            local names = {}
            for _, t in ipairs(list) do names[#names + 1] = t.name end
            -- by distance, then the ones on the character's map, then the ones whose place is not known; Hank is the Horde's
            assert.are.same({ "Near Anna", "Far Ben", "Same Map Sam", "Lost Nell" }, names)
            assert.are.equal(4, total)
            assert.are.equal(350, list[1].distance)
            assert.are.equal("Stormwind City", list[1].zones)
            assert.are.equal("Master Alchemist", list[1].title)
        end)

        it("cuts the list to the limit and still says how many there are", function()
            local list, total = ns.RecipeDB_Trainers(171, 2)
            assert.are.equal(2, #list)
            assert.are.equal(4, total)
        end)

        it("is empty for a profession the data has no trainers of", function()
            local list, total = ns.RecipeDB_Trainers(164)
            assert.are.same({}, list)
            assert.are.equal(0, total)
        end)
    end)

    describe("the panel", function()
        it("a button on the profession's page opens it with the trainers, nearest first, with their zone and distance", function()
            openAlchemy()
            assert.is_nil(panel())
            click(trainersButton())
            assert.is_true(panel():IsShown())
            assert.are.equal(171, ns.Trainers_Current())
            assert.are.equal("Alchemy trainers", panel().title._text)
            local r = rows()
            assert.are.equal(4, #r)
            assert.are.equal("Near Anna <Master Alchemist>", firstLine(r[1]))
            assert.matches("Stormwind City", r[1].text._text)
            assert.matches("350 yd", r[1].text._text)
            assert.are.equal("Far Ben <Alchemist>", firstLine(r[2]))
            assert.are.equal("Lost Nell", firstLine(r[4]))
        end)

        it("the map button shows the trainer on the world map; one whose place is unknown has none", function()
            openAlchemy()
            click(trainersButton())
            local r = rows()
            assert.is_true(r[1].mapButton:IsShown())
            click(r[1].mapButton)
            assert.are.same({ { map = 1453, x = 40, y = 60 } }, mapped)
            assert.is_false(r[4].mapButton:IsShown()) -- Lost Nell
        end)

        it("the waypoint button is there with TomTom, and sets the waypoint at the trainer", function()
            _G.TomTom = { AddWaypoint = function(_, map, x, y, opts) waypoints[#waypoints + 1] = { map, x, y, opts.title } return {} end }
            openAlchemy()
            click(trainersButton())
            local r = rows()
            assert.is_true(r[1].tomButton:IsShown())
            click(r[1].tomButton)
            assert.are.same({ { 1453, 0.4, 0.6, "Near Anna" } }, waypoints)
        end)

        it("has no waypoint button without TomTom", function()
            openAlchemy()
            click(trainersButton())
            assert.is_false(rows()[1].tomButton:IsShown())
        end)

        it("a second click on the button closes it", function()
            openAlchemy()
            click(trainersButton())
            click(trainersButton())
            assert.is_false(panel():IsShown())
        end)

        it("is closed by opening a recipe, and takes the recipe's panel's place", function()
            openAlchemy()
            local row
            for _, f in ipairs(framesWith("data")) do
                if f.data.kind == "recipe" then row = f break end
            end
            click(row)
            assert.is_true(_G.FabrikaoDetailFrame:IsShown())
            click(trainersButton())
            assert.is_true(panel():IsShown())
            assert.is_false(_G.FabrikaoDetailFrame:IsShown())
            click(row)
            assert.is_false(panel():IsShown())
            assert.is_true(_G.FabrikaoDetailFrame:IsShown())
        end)

        it("goes away with the page: back to the professions, or with the window", function()
            openAlchemy()
            click(trainersButton())
            ns.UI_ShowOverview()
            assert.is_false(panel():IsShown())
            openAlchemy()
            click(trainersButton())
            ns.UI_Hide()
            assert.is_false(panel():IsShown())
        end)

        it("says so when the profession has no trainers in the data", function()
            DATA.trainers[171] = nil
            openAlchemy()
            click(trainersButton())
            assert.are.equal(0, #rows())
            assert.is_true(panel().empty:IsShown())
            DATA.trainers[171] = {}
        end)
    end)
end)
