local _, ns = ...

-- Completao!! (quests), optional: through its public API (CompletaoAPI), looked up at call time so the load order of the two addons
-- doesn't matter. Without it nothing here answers yes and the recipes that come from a quest have no "View Quest" button.
--   ns.Quests_Known(questID)   does Completao have the quest?
--   ns.Quests_Show(questID)    opens Completao's window on it (false when it can't)

function ns.Quests_Known(questID)
    local api = CompletaoAPI
    return api ~= nil and api.HasQuest ~= nil and questID ~= nil and api.HasQuest(questID) and true or false
end

function ns.Quests_Show(questID)
    local api = CompletaoAPI
    if not (api and api.ShowQuest and questID) then return false end
    return api.ShowQuest(questID) and true or false
end
