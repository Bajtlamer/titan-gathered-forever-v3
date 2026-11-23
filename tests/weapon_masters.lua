local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local state
local function fresh(options)
    options = options or {}
    state = { faction = options.faction or 'Alliance', class = options.class or 'WARRIOR', level = options.level or 30,
        skills = options.skills or {} }
    UnitFactionGroup = function() return state.faction end
    UnitClass = function() return 'Class', state.class end
    UnitLevel = function() return state.level end
    GetNumSkillLines = function() return #state.skills + 1 end
    GetSkillLineInfo = function(index)
        if index == 1 then return 'Weapon Skills', true end
        local name = state.skills[index - 1]
        return name, false, nil, 1
    end
    local ns = { IsPublic = function() return true end, settings = {}, db = {},
        Style = { gold = 'gold', gray = 'gray', white = 'white', green = 'green', red = 'red',
            Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end,
            Small = function() end },
        NpcSources = { CoinIcons = function(copper) return copper .. 'c' end } }
    assert(loadfile('TitanGatheredForever/WeaponMasters.lua'))('TitanGatheredForever', ns)
    return ns
end

local function tooltip()
    local t = { lines = {} }
    function t:AddLine(text) self.lines[#self.lines + 1] = text end
    function t:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. ' | ' .. right end
    function t:text() return table.concat(self.lines, '\n') end
    return t
end

test('the eight capital masters of both factions are listed with the evidence of the source', function()
    local ns = fresh()
    local count = 0
    for _ in pairs(ns.WeaponMasters.masters) do count = count + 1 end
    eq(count, 8)
    local woo = ns.WeaponMasters.masters[11867]
    eq(woo.name, 'Woo Ping'); eq(woo.faction, 'Alliance'); eq(woo.mapID, 1453)
    assert(math.abs(woo.x - 0.638) < 0.001 and math.abs(woo.y - 0.690) < 0.001)   -- seen in the game by the Discovery module
    eq(ns.WeaponMasters.masters[2704].faction, 'Horde')
end)

test('only the masters of the faction of the player are pinned, on the map of their city', function()
    local ns = fresh({ faction = 'Alliance' })
    local nodes = ns.WeaponMasters.List(1453)
    eq(#nodes, 1); eq(nodes[1].kind, 'WeaponMaster'); eq(nodes[1].npcID, 11867)
    eq(#ns.WeaponMasters.List(1455), 2)               -- Ironforge: two masters
    eq(#ns.WeaponMasters.List(1454), 0)               -- Orgrimmar is not for an Alliance character
    local horde = fresh({ faction = 'Horde' })
    eq(#horde.WeaponMasters.List(1454), 2); eq(#horde.WeaponMasters.List(1453), 0)
end)

test('the pins can be switched off in the settings', function()
    local ns = fresh()
    ns.settings.mapWeaponMasters = false
    eq(#ns.WeaponMasters.List(1453), 0)
    eq(ns.WeaponMasters.Enabled(), false)
    ns.settings.mapWeaponMasters = nil
    eq(ns.WeaponMasters.Enabled(), true)
end)

test('the tooltip tells what the player knows, what can be learned and what the class cannot use', function()
    local ns = fresh({ class = 'ROGUE', skills = { 'Daggers' } })
    local t = tooltip()
    ns.WeaponMasters.FillTooltip(t, { kind = 'WeaponMaster', npcID = 11867 })
    local text = t:text()
    assert(text:find('Woo Ping', 1, true))
    assert(text:find('Daggers | <green>Known', 1, true), text)
    assert(text:find('One-Handed Swords | <white>Can learn', 1, true), text)
    assert(text:find('Staves | <gray>Not for your class', 1, true), text)
end)

test('a price is shown only when the game reported it at the trainer', function()
    local ns = fresh({ class = 'WARRIOR' })
    local t = tooltip()
    ns.WeaponMasters.FillTooltip(t, { kind = 'WeaponMaster', npcID = 11867 })
    assert(not t:text():find('1000c', 1, true) and not t:text():find('rice', 1, true), 'no price, no word about prices')
    assert(ns.WeaponMasters.Observe(11867, { { name = 'Crossbows', cost = 1000 }, { name = 'Staves', cost = 1000 } }))
    t = tooltip()
    ns.WeaponMasters.FillTooltip(t, { kind = 'WeaponMaster', npcID = 11867 })
    assert(t:text():find('Crossbows | <white>Can learn  1000c', 1, true), t:text())
    assert(not t:text():find('Two-Handed Swords | <white>Can learn  ', 1, true))   -- no price known for this one
end)

test('a trainer that is not a weapon master is not recorded', function()
    local ns = fresh()
    eq(ns.WeaponMasters.Observe(424242, { { name = 'Swords', cost = 1000 } }), false)
    eq(ns.db.weaponMasters, nil)
end)

test('polearms are locked below level 20 and the status stays unknown without the skill list', function()
    local ns = fresh({ class = 'WARRIOR', level = 10 })
    local t = tooltip()
    ns.WeaponMasters.FillTooltip(t, { kind = 'WeaponMaster', npcID = 11867 })
    assert(t:text():find('Polearms | <gray>From level 20', 1, true), t:text())
    GetNumSkillLines = nil
    t = tooltip()
    ns.WeaponMasters.FillTooltip(t, { kind = 'WeaponMaster', npcID = 11867 })
    assert(t:text():find('Daggers | ', 1, true) and not t:text():find('Unknown', 1, true), t:text())
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then error(entry[1] .. ': ' .. tostring(err), 0) end
end
print('PASS weapon masters ' .. #tests .. ' checks')
