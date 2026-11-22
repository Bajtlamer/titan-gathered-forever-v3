local _, ns = ...
-- Professions and their ranks: evidence which professions exist and how far the player has them.
local Skill = {}
ns.Skill = Skill

function Skill.Changed()
    local ctx = ns.Records.Context()
    for _, skill in ipairs(ns.api.Skills()) do
        if type(skill.name) == 'string' then
            local record = ns.Records.Touch(ns.db.data.skills, skill.name, ctx)
            record.rank, record.maxRank = skill.rank, skill.maxRank
        end
    end
end
