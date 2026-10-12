dofile("setupTests.lua")

-- Where to get an ingredient: a click on it in a recipe's panel lists who sells it, which creatures drop it, where it is fished and
-- gathered, and what makes it, with the map and waypoint buttons of the ones that have a place.
describe("Where to get an ingredient", function()
    local ns, mapped

    local DATA = {
        recipes = {
            [1] = { s = 171, n = "Elixir of Wisdom", c = { 1, 55, 75, 95 }, p = { 200, 1, 2 }, m = { { 10, 2 }, { 11, 1 }, { 12, 1 } }, k = { 6 } },
            [2] = { s = 171, n = "Healing Potion", c = { 1, 20, 40, 60 }, m = { { 10, 1 } }, k = { 6 } },
        },
        items = {},
        trainers = {},
        reagents = {
            [10] = {
                v = {
                    { id = 2, n = "Horde Vendor", z = { 1637 }, g = 40, f = "H" },
                    { id = 3, n = "Far Vendor", z = { 46 }, g = 50 },
                    { id = 1, n = "Alliance Vendor", z = { 1519 }, g = 42, f = "A" },
                },
                d = { { id = 20, n = "Murloc Forager", z = { 12 }, lo = 9, hi = 10, pm = 1250 }, { id = 21, n = "Deeb", z = { 85 }, lo = 12, hi = 12, pm = 5 } },
                k = { { id = 22, n = "Great Goretusk", z = { 12 }, lo = 16, hi = 17, pm = 7310 } },
                f = { { z = 12, pm = 1300 }, { z = 46, pm = 100 } },
                g = { { n = "Silverleaf", z = { 12, 46 } } },
                c = { { s = 171, n = "Elixir base", i = 999 } },
            },
            [11] = { g = { { n = "Copper Vein", z = {} } } },
        },
        npcs = { [1] = { 1453, 40, 60 }, [3] = { 36, 30, 20 }, [20] = { 1429, 50, 50 } },
    }

    local function visible(field)
        local found = {}
        for _, f in ipairs(WowMock.frames) do
            if f[field] ~= nil and f:IsVisible() then found[#found + 1] = f end
        end
        return found
    end

    local function click(f) f._scripts.OnClick(f, "LeftButton") end

    local function panel() return _G.FabrikaoDetailFrame end

    local function recipeRow(name)
        for _, row in ipairs(visible("data")) do
            if row.data.kind == "recipe" and row.data.recipe.name == name then return row end
        end
    end

    -- the ingredient rows of the panel, by item
    local function ingredient(itemID)
        for _, f in ipairs(visible("itemID")) do
            if f._parent == panel().child and f.itemID == itemID then return f end
        end
    end

    local function shown(text)
        return #WowMock.FindAll(function(f) return f._text == text and f:IsVisible() end) > 0
    end

    local function textLike(pattern)
        return #WowMock.FindAll(function(f) return f._text and f._text:match(pattern) and f:IsVisible() end) > 0
    end

    -- the rows with a name and place under the ingredients, in the panel's order
    local function placeRows()
        local out = {}
        for _, f in ipairs(visible("mapButton")) do out[#out + 1] = f end
        return out
    end

    before_each(function()
        WowMock.Reset()
        WowMock.faction = "Alliance"
        _G.FabrikaoDetailFrame, _G.IsModifiedClick, _G.TomTom = nil, nil, nil
        _G.GetProfessions = function() return 1 end
        _G.GetProfessionInfo = function() return "Alchemy", 5, 100, 300, 1, 10, 171, 0 end
        _G.Enum = { SpellBookSpellBank = { Player = 0 }, CraftingReagentType = { Basic = 1 } }
        _G.C_SpellBook = { IsSpellKnown = function(id) return id == 1 end }
        _G.C_Map = {
            GetAreaInfo = function(id)
                return ({ [1519] = "Stormwind City", [1637] = "Orgrimmar", [46] = "Burning Steppes", [12] = "Elwynn Forest", [85] = "Tirisfal Glades" })[id]
            end,
            GetBestMapForUnit = function() return 1453 end,
        }
        _G.C_Item = { GetItemCount = function() return 0 end, GetItemNameByID = function(id) return "Item" .. id end, GetItemIconByID = function() return 1 end }
        _G.C_TradeSkillUI = nil
        ns = LoadAddon()
        ns.RECIPE_DATA = DATA
        -- yards from the character, by the map of the spot (Stormwind is the nearest)
        ns.Map_Distance = function(spot) return ({ [1453] = 350, [36] = 4000 })[spot.map] end
        mapped = {}
        ns.Map_Show = function(spot) mapped[#mapped + 1] = spot return true end
        StartAddon(ns)
        ns.UI_Toggle()
        click(visible("profession")[1])
    end)

    describe("the data", function()
        local function titles(lines)
            local out = {}
            for _, line in ipairs(lines) do out[#out + 1] = line.title end
            return out
        end

        it("lists the kinds of source in order, only the ones there are", function()
            assert.are.same({ "Sold by", "Dropped by", "Skinned from", "Fished in", "Gathered from", "Made by" }, titles(ns.RecipeDB_ReagentWhere(10)))
            assert.are.same({ "Gathered from" }, titles(ns.RecipeDB_ReagentWhere(11)))
        end)

        it("is empty for an ingredient the data knows nothing of", function()
            assert.are.same({}, ns.RecipeDB_ReagentWhere(12))
            assert.are.same({}, ns.RecipeDB_ReagentWhere(99999))
        end)

        it("lists the vendors for the character's side, nearest first, with the price and the id to show them", function()
            local vendors = ns.RecipeDB_ReagentWhere(10)[1].entries
            assert.are.equal(2, #vendors) -- the Horde's is not for an Alliance character
            assert.are.equal("Alliance Vendor", vendors[1].name)
            assert.are.equal(1, vendors[1].id)
            assert.are.equal(350, vendors[1].distance)
            assert.matches("Stormwind City", vendors[1].text)
            assert.matches("42c", vendors[1].text) -- the price, 42 copper
            assert.are.equal("Far Vendor", vendors[2].name)
        end)

        it("lists the creatures that drop it with their level and the chance, in the order of the data", function()
            local drops = ns.RecipeDB_ReagentWhere(10)[2].entries
            assert.are.equal("Murloc Forager", drops[1].name)
            assert.matches("level 9%-10", drops[1].text)
            assert.matches("12%.5%%", drops[1].text)
            assert.matches("Elwynn Forest", drops[1].text)
            assert.matches("<0%.1%%", drops[2].text) -- a chance of 0.05%
        end)

        it("says in which zones it is fished, where it is gathered and what makes it, as plain text", function()
            local lines = ns.RecipeDB_ReagentWhere(10)
            assert.matches("Elwynn Forest %-%- 13%.0%%", lines[4].entries[1].text)
            assert.matches("Burning Steppes", lines[4].entries[2].text)
            assert.matches("Silverleaf %(Elwynn Forest, Burning Steppes%)", lines[5].entries[1].text)
            assert.matches("Alchemy: Elixir base", lines[6].entries[1].text)
            assert.is_nil(lines[4].entries[1].id) -- no place to show on the map
        end)
    end)

    describe("the panel", function()
        before_each(function()
            click(recipeRow("Elixir of Wisdom"))
        end)

        it("shows nothing under the ingredients until one is clicked", function()
            assert.is_false(shown("Sold by"))
            assert.is_false(ns.RecipeDetail_ReagentOpen(10))
        end)

        it("a click on an ingredient opens where to get it under its row, and another closes it", function()
            click(ingredient(10))
            assert.is_true(ns.RecipeDetail_ReagentOpen(10))
            assert.is_true(shown("Sold by"))
            assert.is_true(shown("Dropped by"))
            assert.is_true(shown("Fished in"))
            click(ingredient(10))
            assert.is_false(shown("Sold by"))
        end)

        it("the vendors and creatures have the map button, which shows them on the map", function()
            click(ingredient(10))
            local rows = placeRows()
            -- the Alliance vendor, the far one and the murloc have a place; the other creatures and the rest do not
            assert.is_true(#rows >= 3)
            click(rows[1].mapButton)
            assert.are.same({ { map = 1453, x = 40, y = 60 } }, mapped)
        end)

        it("has the waypoint button with TomTom installed", function()
            _G.TomTom = { AddWaypoint = function() return {} end }
            click(ingredient(10))
            assert.is_true(placeRows()[1].tomButton:IsShown())
        end)

        it("says so when the data has no source for the ingredient", function()
            click(ingredient(12))
            assert.is_true(shown("No known source."))
        end)

        it("one ingredient's list does not close another's", function()
            click(ingredient(10))
            click(ingredient(12))
            assert.is_true(shown("Sold by"))
            assert.is_true(shown("No known source."))
        end)

        it("a shift-click links the item instead and opens nothing", function()
            _G.IsModifiedClick = function() return true end
            click(ingredient(10))
            assert.is_false(ns.RecipeDetail_ReagentOpen(10))
        end)

        it("stays open when the same recipe is filled again, and closes with another recipe", function()
            click(ingredient(10))
            click(recipeRow("Elixir of Wisdom")) -- the list's click on the same recipe fills it again
            assert.is_true(ns.RecipeDetail_ReagentOpen(10))
            click(recipeRow("Healing Potion"))
            assert.is_false(ns.RecipeDetail_ReagentOpen(10))
        end)


    end)
end)
