dofile("setupTests.lua")

-- Integrity of Data/Generated/Recipes.lua: what the local tool generates must have the shape the addon reads.
describe("Recipe data", function()
    local db

    setup(function()
        WowMock.Reset()
        db = LoadAddon().RECIPE_DATA
    end)

    local function count(t)
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    it("has recipes, items and trainers", function()
        assert.is_true(count(db.recipes) > 1000)
        assert.is_true(count(db.items) > 1000)
        assert.is_true(count(db.trainers) >= 7)
    end)

    it("every recipe has its profession, a name, and four skill levels that don't go down (0: that color is skipped)", function()
        for id, r in pairs(db.recipes) do
            assert.is_truthy(type(r.s) == "number" and type(r.n) == "string" and r.n ~= "", "recipe " .. id)
            if r.c then
                assert.are.equal(4, #r.c, "colors of " .. id)
                local last = 0
                for _, level in ipairs(r.c) do
                    if level > 0 then
                        assert.is_true(level >= last, "colors of " .. id .. " " .. r.n)
                        last = level
                    end
                end
            end
        end
    end)

    it("every ingredient is an item id with a count, and the product too", function()
        for id, r in pairs(db.recipes) do
            for _, m in ipairs(r.m or {}) do
                assert.is_truthy(type(m[1]) == "number" and type(m[2]) == "number" and m[2] > 0, "reagent of " .. id)
            end
            if r.p then assert.is_truthy(type(r.p[1]) == "number", "product of " .. id) end
        end
    end)

    it("the item that teaches a recipe exists", function()
        for id, r in pairs(db.recipes) do
            if r.i then assert.is_not_nil(db.items[r.i], "item " .. r.i .. " of recipe " .. id) end
        end
    end)

    it("every profession with recipes has trainers", function()
        local skills = {}
        for _, r in pairs(db.recipes) do skills[r.s] = true end
        for skill in pairs(skills) do
            assert.is_truthy(db.trainers[skill] and #db.trainers[skill] > 0, "trainers of " .. skill)
        end
    end)

    it("the positions of the NPCs are a map id and coordinates in percent, for NPCs the data lists", function()
        local listed = {}
        for _, item in pairs(db.items) do
            for _, key in ipairs({ "v", "d" }) do
                for _, entry in ipairs(item[key] or {}) do listed[entry.id] = true end
            end
        end
        for _, trainers in pairs(db.trainers) do
            for _, trainer in ipairs(trainers) do listed[trainer.id] = true end
        end
        local located = 0
        for id, spot in pairs(db.npcs) do
            located = located + 1
            assert.is_true(listed[id] == true, "npc " .. id .. " is not in the data")
            assert.is_truthy(type(spot[1]) == "number" and spot[1] > 0, "map of npc " .. id)
            assert.is_truthy(type(spot[2]) == "number" and spot[2] >= 0 and spot[2] <= 100, "x of npc " .. id)
            assert.is_truthy(type(spot[3]) == "number" and spot[3] >= 0 and spot[3] <= 100, "y of npc " .. id)
        end
        assert.is_true(located > 400)
    end)

    it("vendors, drops and quests are named", function()
        for id, item in pairs(db.items) do
            for _, key in ipairs({ "v", "d", "qs", "o" }) do
                for _, entry in ipairs(item[key] or {}) do
                    assert.is_truthy(type(entry.n) == "string" and entry.n ~= "", key .. " of item " .. id)
                end
            end
        end
    end)
end)
