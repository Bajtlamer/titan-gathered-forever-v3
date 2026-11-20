local _, ns = ...
-- Connects game events to the collectors. The events are registered only while the module is collecting (accepted, not
-- paused), so a module that is off or waiting for consent listens to nothing. A failing collector is counted and shown
-- in /tgfd status; it never raises an error into the game.
local Manager = {}
ns.Manager = Manager

local function last(...) return (select(select('#', ...), ...)) end

Manager.HANDLERS = {
    PLAYER_ENTERING_WORLD = function() ns.Area.Changed() end,
    ZONE_CHANGED = function() ns.Area.Changed() end,
    ZONE_CHANGED_INDOORS = function() ns.Area.Changed() end,
    ZONE_CHANGED_NEW_AREA = function() ns.Area.Changed() end,
    PLAYER_TARGET_CHANGED = function() ns.Npc.Seen('target') end,
    UPDATE_MOUSEOVER_UNIT = function() ns.Npc.Seen('mouseover') end,
    LOOT_READY = function() ns.Loot.Opened() end,
    LOOT_OPENED = function() ns.Loot.Opened() end,
    LOOT_SLOT_CLEARED = function(slot) ns.Loot.SlotCleared(slot) end,
    LOOT_CLOSED = function() ns.Loot.Closed() end,
    GOSSIP_SHOW = function() ns.Npc.Contact('npc', 'gossip') end,
    MERCHANT_SHOW = function() ns.Vendor.MerchantShown() end,
    MERCHANT_UPDATE = function() ns.Vendor.MerchantUpdated() end,
    TRAINER_SHOW = function() ns.Vendor.TrainerShown() end,
    TAXIMAP_OPENED = function() ns.Npc.Contact('npc', 'flight') end,
    BANKFRAME_OPENED = function() ns.Npc.Contact('npc', 'bank') end,
    QUEST_DETAIL = function() ns.Quest.Detail() end,
    QUEST_GREETING = function() ns.Npc.Contact('npc', 'quest') end,
    QUEST_PROGRESS = function() ns.Npc.Contact('npc', 'quest') end,
    QUEST_COMPLETE = function() ns.Quest.Complete() end,
    QUEST_ACCEPTED = function(...) ns.Quest.Accepted(last(...)) end,
    QUEST_TURNED_IN = function(id) ns.Quest.TurnedIn(id) end,
    SKILL_LINES_CHANGED = function() ns.Skill.Changed() end,
}

function Manager.Handle(event, ...)
    if not ns.Consent.Collecting(ns.db, ns.runtime) then return end
    local handler = Manager.HANDLERS[event]
    if not handler then return end
    local ok, err = pcall(handler, ...)
    if not ok then
        ns.runtime.errors = (ns.runtime.errors or 0) + 1
        ns.runtime.lastError = tostring(err)
    end
end

function Manager.Refresh()
    if not ns.frame then return end
    local collecting = ns.Consent.Collecting(ns.db, ns.runtime)
    for event in pairs(Manager.HANDLERS) do
        if collecting then ns.frame:RegisterEvent(event) else ns.frame:UnregisterEvent(event) end
    end
end

-- Records the client and the current state once, then starts listening. Called when collection starts or resumes and at login.
function Manager.Begin()
    if ns.api and ns.Consent.Collecting(ns.db, ns.runtime) then
        for _, step in ipairs({ ns.Client.Record, ns.Area.Changed, ns.Skill.Changed }) do
            local ok, err = pcall(step)
            if not ok then
                ns.runtime.errors = (ns.runtime.errors or 0) + 1
                ns.runtime.lastError = tostring(err)
            end
        end
    end
    Manager.Refresh()
end
