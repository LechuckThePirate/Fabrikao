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
            -- and who gives the quests that teach a recipe
            for _, quest in ipairs(item.qs or {}) do
                for _, giver in ipairs(quest.g or {}) do listed[giver.id] = true end
            end
        end
        for _, trainers in pairs(db.trainers) do
            for _, trainer in ipairs(trainers) do listed[trainer.id] = true end
        end
        -- and the vendors and creatures that give an ingredient
        for _, reagent in pairs(db.reagents or {}) do
            for _, key in ipairs({ "v", "d", "k" }) do
                for _, entry in ipairs(reagent[key] or {}) do listed[entry.id] = true end
            end
        end
        -- and the vendors of the books and the givers of the quests of the ranks
        for _, caps in pairs(db.ranks or {}) do
            for _, rank in pairs(caps) do
                for _, book in ipairs(rank.b or {}) do
                    for _, vendor in ipairs(book.v or {}) do listed[vendor.id] = true end
                end
                for _, quest in ipairs(rank.q or {}) do
                    for _, giver in ipairs(quest.g or {}) do listed[giver.id] = true end
                end
            end
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

    it("the sources of an ingredient are for an ingredient of some recipe, named, with chances and prices in range", function()
        local used = {}
        for _, r in pairs(db.recipes) do
            for _, m in ipairs(r.m or {}) do used[m[1]] = true end
        end
        local listed = 0
        for id, reagent in pairs(db.reagents) do
            listed = listed + 1
            assert.is_true(used[id] == true, "ingredient " .. id .. " is used by no recipe")
            for _, key in ipairs({ "v", "d", "k" }) do
                for _, entry in ipairs(reagent[key] or {}) do
                    assert.is_truthy(type(entry.id) == "number" and type(entry.n) == "string", key .. " of ingredient " .. id)
                    assert.is_truthy(entry.pm == nil or (entry.pm >= 0 and entry.pm <= 10000), "chance of " .. entry.id)
                    assert.is_truthy(entry.g == nil or entry.g >= 0, "price of " .. entry.id)
                end
            end
            for _, zone in ipairs(reagent.f or {}) do
                assert.is_truthy(type(zone.z) == "number" and (zone.pm == nil or (zone.pm >= 0 and zone.pm <= 10000)), "fishing zone of " .. id)
            end
            for _, node in ipairs(reagent.g or {}) do
                assert.is_truthy(type(node.n) == "string" and type(node.z) == "table", "node of " .. id)
            end
            for _, made in ipairs(reagent.c or {}) do
                assert.is_truthy(type(made.n) == "string" and type(made.i) == "number", "maker of " .. id)
            end
        end
        assert.is_true(listed > 300)
    end)

    it("the ranks of a book or a quest have the book with its vendors, or the quest with its givers", function()
        local ranks = 0
        for skill, caps in pairs(db.ranks) do
            assert.is_not_nil(db.trainers[skill], "profession " .. skill)
            for cap, rank in pairs(caps) do
                ranks = ranks + 1
                assert.is_true(cap == 225 or cap == 300, "the skill " .. cap .. " of profession " .. skill)
                assert.is_truthy(rank.b or rank.q, "profession " .. skill .. " rank " .. cap .. " has neither")
                for _, book in ipairs(rank.b or {}) do
                    assert.is_truthy(type(book.i) == "number" and type(book.n) == "string" and #(book.v or {}) > 0, "book of " .. skill)
                end
                for _, quest in ipairs(rank.q or {}) do
                    assert.is_truthy(type(quest.id) == "number" and type(quest.n) == "string" and #(quest.g or {}) > 0, "quest of " .. skill)
                end
            end
        end
        assert.is_true(ranks >= 4) -- Expert and Artisan of at least two professions
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
