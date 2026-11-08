local passed = 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then io.stderr:write('FAIL ' .. name .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
    passed = passed + 1
end
local function eq(a, b) assert(a == b, tostring(a) .. ' != ' .. tostring(b)) end
local function fixture(saved)
    local ns = {}
    assert(loadfile('TitanGatheredForeverV3/Gathering.lua'))('TitanGatheredForeverV3', ns)
    local state = { now = 100, position = { mapID = 1, x = 0.4, y = 0.6 }, enabled = true,
                    slots = { { slot = 1, itemID = 2770, sources = { 'GameObject-0-1-2-3-1731-9' } } } }
    local api = { Now = function() return state.now end,
                  CanRecord = function() return not state.inInstance end,
                  Timestamp = function() return state.wall or state.now end,
                  Position = function() return state.position end,
                  Loot = function() return state.slots end }
    local resources = { Mining = { [2770] = 0, [249391] = 1 }, Herbs = { [765] = 0 },
                        Skinning = { [2318] = 0, [783] = 0 } }
    local controller = ns.Gathering.New(api, saved or {}, function(kind) return resources[kind] end,
        function(kind) return state.enabled and state.disabledKind ~= kind end)
    return controller, state
end
local function gather(controller, spellID)
    controller:Cast('UNIT_SPELLCAST_START', 'player', 'cast1', spellID or 2575)
    controller:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', spellID or 2575)
    controller:LootReady()
    controller:SlotCleared(1)
    controller:LootClosed()
end

test('successful gathered game-object loot records a persistent location', function()
    local saved = {}
    local c = fixture(saved); gather(c)
    local points = c:List(1)
    eq(#points, 1); eq(points[1].itemID, 2770); eq(points[1].kind, 'Mining')
    eq(points[1].x, 0.4); eq(points[1].count, 1)
    local reloaded = fixture(saved); eq(#reloaded:List(1), 1)
end)
test('opening loot without taking it records nothing', function()
    local c = fixture()
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 2575)
    c:LootReady(); c:LootClosed(); eq(#c:List(1), 0)
end)
test('failed or interrupted gathers record nothing', function()
    for _, event in ipairs({ 'UNIT_SPELLCAST_FAILED', 'UNIT_SPELLCAST_INTERRUPTED' }) do
        local c = fixture()
        c:Cast('UNIT_SPELLCAST_START', 'player', 'cast1', 2575)
        c:Cast(event, 'player', 'cast1', 2575)
        c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
    end
end)
test('ordinary corpse, chest and unrelated spell loot do not create gathering pins', function()
    local c, s = fixture()
    s.slots[1].sources = { 'Creature-0-1-2-3-123-9' }; gather(c); eq(#c:List(1), 0)
    c, s = fixture(); gather(c, 999); eq(#c:List(1), 0)
    c, s = fixture(); c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
end)
test('nearby observations merge and other resources remain separate', function()
    local c, s = fixture(); gather(c)
    s.position.x = 0.4005; s.now = 110; gather(c)
    eq(#c:List(1), 1); eq(c:List(1)[1].count, 2)
    s.position.x = 0.5; gather(c); eq(#c:List(1), 2)
end)
test('regular ore takes marker priority over scarce byproducts regardless of loot order', function()
    local c, s = fixture()
    s.slots = { { slot = 1, itemID = 249391, sources = { 'GameObject-0-1-2-3-1731-9' } },
                { slot = 2, itemID = 2770, sources = { 'GameObject-0-1-2-3-1731-9' } } }
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 2575)
    c:LootReady(); c:SlotCleared(1); c:SlotCleared(2); c:LootClosed()
    eq(#c:List(1), 1); eq(c:List(1)[1].itemID, 2770)
end)
test('master and profession switches stop recording while preserving saved points', function()
    local c, s = fixture(); gather(c); s.enabled = false; s.position.x = 0.7; gather(c)
    eq(#c:List(1), 0)
    s.enabled = true; eq(#c:List(1), 1)
    s.disabledKind = 'Mining'; gather(c); eq(#c:List(1), 0)
    s.disabledKind = nil; eq(#c:List(1), 1)
end)
test('map scopes, invalid positions and stale cast correlations are rejected', function()
    local c, s = fixture(); gather(c); eq(#c:List(2), 0)
    s.position = nil; gather(c); eq(#c:List(1), 1)
    s.position = { mapID = 1, x = 2, y = 0.2 }; gather(c); eq(#c:List(1), 1)
    s.position = { mapID = 1, x = 0.2, y = 0.2 }
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 2575)
    s.now = 200; c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 1)
end)
test('another player casting cannot establish a gather', function()
    local c = fixture()
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'party1', 'cast1', 2575)
    c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
end)
test('loot ready before spell success is supported without credit before success', function()
    local c = fixture()
    c:Cast('UNIT_SPELLCAST_START', 'player', 'cast1', 2575)
    c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 2575); eq(#c:List(1), 1)
end)
test('loot source metadata becoming available after LOOT_READY still records the herb icon item', function()
    local c, s = fixture(); s.slots[1].itemID = 765; s.slots[1].sources = {}
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast1', 2366)
    c:LootReady()
    s.slots = { { slot = 1, itemID = 765, sources = { 'GameObject-0-1-2-3-657380-9' } } }
    c:LootReady(); c:SlotCleared(1); c:LootClosed()
    eq(#c:List(1), 1); eq(c:List(1)[1].itemID, 765)
end)

test('herb gathers produce herbalism observations', function()
    local c, s = fixture(); s.slots[1].itemID = 765; gather(c, 2366)
    eq(#c:List(1), 1); eq(c:List(1)[1].kind, 'Herbs')
end)
test('retained map points have a bounded per-map count', function()
    local c, s = fixture()
    for i = 1, 510 do
        s.position = { mapID = 1, x = (i % 30) / 30, y = math.floor(i / 30) / 30 }
        s.now = 100 + i; gather(c)
    end
    eq(#c:List(1), 500)
end)
test('saved observation times survive uptime resets without evicting the newest spots', function()
    local saved = {}
    local c, s = fixture(saved)
    for i = 1, 500 do
        s.position = { mapID = 1, x = (i % 30) / 30, y = math.floor(i / 30) / 30 }
        s.now = 100 + i; gather(c)
    end
    c, s = fixture(saved)
    s.now, s.wall = 1, 10000
    s.position = { mapID = 1, x = 0.99, y = 0.99 }; gather(c)
    s.now, s.wall = 2, 10001
    s.position = { mapID = 1, x = 0.95, y = 0.95 }; gather(c)
    local retained = false
    for _, node in ipairs(c:List(1)) do
        if node.x == 0.99 then retained = true; eq(node.lastSeen, 10000) end
    end
    assert(retained, 'New observation was evicted because the session clock restarted')
end)
test('malformed saved entries are pruned before enforcing the map limit', function()
    local saved = { maps = { [1] = {} } }
    for i = 1, 500 do saved.maps[1][i] = i end
    local c = fixture(saved); gather(c)
    eq(#saved.maps[1], 1); eq(#c:List(1), 1)
end)
test('skinning records each distinct taken material from the skinned creature', function()
    local saved = {}
    local c, s = fixture(saved)
    s.slots = { { slot = 1, itemID = 2318, sources = { 'Creature-0-1-2-3-2958-9' } },
                { slot = 2, itemID = 783, sources = { 'Creature-0-1-2-3-2958-9' } } }
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'skin1', 8613)
    c:LootReady(); c:SlotCleared(1); c:SlotCleared(2); c:LootClosed()
    eq(#c:List(1), 2)
    local items = {}; for _, node in ipairs(c:List(1)) do items[node.itemID] = true; eq(node.kind, 'Skinning') end
    assert(items[2318] and items[783])
    local reloaded = fixture(saved); eq(#reloaded:List(1), 2)
end)
test('skinning does not credit ordinary corpse loot, untaken loot or game objects', function()
    local c, s = fixture(); s.slots[1].itemID = 2318
    s.slots[1].sources = { 'Creature-0-1-2-3-2958-9' }
    c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
    c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'skin1', 8613)
    c:LootReady(); c:LootClosed(); eq(#c:List(1), 0)
    s.slots[1].sources = { 'GameObject-0-1-2-3-2958-9' }; gather(c, 8613); eq(#c:List(1), 0)
    s.slots[1].sources = { 'Creature-0-1-2-3-2958-9' }
    c:Cast('UNIT_SPELLCAST_START', 'player', 'skin1', 8613)
    c:Cast('UNIT_SPELLCAST_FAILED', 'player', 'skin1', 8613)
    c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
end)
test('instances block every gathering profession and changing areas invalidates pending casts', function()
    for _, item in ipairs({ { 2575, 2770, 'GameObject' }, { 2366, 765, 'GameObject' }, { 8613, 2318, 'Creature' } }) do
        local c, s = fixture(); s.slots[1].itemID = item[2]; s.slots[1].sources = { item[3] .. '-0-1-2-3-2958-9' }
        s.inInstance = true; gather(c, item[1]); eq(#c:List(1), 0)
        s.inInstance = false
        c:Cast('UNIT_SPELLCAST_SUCCEEDED', 'player', 'enter1', item[1])
        s.inInstance = true; c:LootReady(); c:SlotCleared(1); c:LootClosed(); eq(#c:List(1), 0)
    end
end)
test('skinning switch suppresses records and hides existing skinning spots', function()
    local c, s = fixture(); s.slots[1].itemID = 2318; s.slots[1].sources = { 'Creature-0-1-2-3-2958-9' }
    gather(c, 8613); eq(#c:List(1), 1)
    s.disabledKind = 'Skinning'; gather(c, 8613); eq(#c:List(1), 0)
    s.disabledKind = nil; eq(#c:List(1), 1); eq(c:List(1)[1].count, 1)
end)
test('clear spots affects only the chosen map and category, including hidden spots', function()
    local c, state = fixture(); gather(c)
    state.slots[1].itemID = 765; gather(c, 2366)
    state.position.mapID = 2; state.slots[1].itemID = 2770; gather(c)
    state.disabledKind = 'Mining'
    local changed = 0; c.changed = function() changed = changed + 1 end
    eq(c:Count(1, 'Mining'), 1)
    eq(c:Clear(1, 'Mining'), 1); eq(changed, 1)
    eq(c:Count(1, 'Mining'), 0)
    eq(#c.saved.maps[1], 1); eq(c.saved.maps[1][1].kind, 'Herbs')
    eq(#c.saved.maps[2], 1)
    eq(c:Clear(1, 'Mining'), 0); eq(c:Clear(1, 'invalid'), 0)
    eq(c:Clear(nil, 'Mining'), 0); eq(#c.saved.maps[2], 1)
end)
test('clear cancels a matching pending gather and persists the removal', function()
    local c, state = fixture(); gather(c)
    c:Cast('UNIT_SPELLCAST_START', 'player', 'pending', 2575)
    assert(c.cast)
    eq(c:Clear(1, 'Mining'), 1); eq(c.cast, nil)
    local restored = fixture(c.saved); eq(#restored:List(1), 0)
end)
test('legacy co-located mining byproducts do not cover recorded ore and saved data remains intact',function()
    local function point(id,x)return{mapID=1,x=x,y=.6,kind='Mining',itemID=id,count=1,lastSeen=100}end
    local saved={maps={[1]={point(2770,.4),point(2835,.4001),point(1210,.4),point(249391,.4),point(2835,.7)}}}
    local c=fixture(saved);local nodes=c:List(1)
    eq(#nodes,2);eq(nodes[1].itemID,2770);eq(nodes[2].itemID,2835);eq(nodes[2].x,.7)
    eq(#saved.maps[1],5);eq(c:Count(1,'Mining'),5)
end)
print('PASS ' .. passed .. ' gathering observation tests')
