local _, ns = ...
ns.Professions = {}
local kinds = { [171]='Alchemy', [164]='Blacksmithing', [333]='Enchanting', [202]='Engineering',
    [182]='Herbs', [165]='Leatherworking', [186]='Mining', [393]='Skinning', [197]='Tailoring',
    [185]='Cooking', [356]='Fishing', [129]='FirstAid' }
local skills = {
    { 171 }, { 164 }, { 333 }, { 202 }, { 182 }, { 165 }, { 186 }, { 393 }, { 197 },
    { 185, true }, { 356, true }, { 129, true },
}

function ns.Professions.Rows()
    local result = {}
    for _, skill in ipairs(skills) do
        local ok, info = pcall(C_SkillInfo.GetSkillLineInfoByID, skill[1])
        if ok and info and ns.IsPublic(info.name) and ns.IsPublic(info.rank)
            and ns.IsPublic(info.maxRank) and type(info.name) == 'string'
            and type(info.rank) == 'number' and info.rank > 0
            and type(info.maxRank) == 'number' and info.maxRank > 0 then
            result[#result + 1] = { skillID = skill[1], kind = kinds[skill[1]], name = info.name, rank = info.rank,
                                   maxRank = info.maxRank, secondary = skill[2] == true }
        end
    end
    table.sort(result, function(a, b)
        if a.secondary ~= b.secondary then return not a.secondary end
        return a.name < b.name
    end)
    return result
end
