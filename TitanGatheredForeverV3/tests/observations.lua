local passed=0
local function eq(a,b) assert(a==b,tostring(a)..' != '..tostring(b)) end
local function test(n,f) local ok,e=pcall(f);if not ok then error(n..': '..e) end;passed=passed+1 end
local ns={};assert(loadfile('TitanGatheredForeverV3/History.lua'))('TGF v3',ns);assert(loadfile('TitanGatheredForeverV3/Observations.lua'))('TGF v3',ns)
local function fixture()
 local h=ns.History.New({});local s={now=1,allowed=true,maps={},slots={}}
 local api={Now=function()return s.now end,Timestamp=function()return 100 end,CanRecord=function()return s.allowed end,
 Position=function()return s.position or{mapID=1,x=.4,y=.6}end,Loot=function()return s.slots end,
 IsFishing=function()return s.fishing end,Track=function()return s.track~=false end,Active=function()return true end,
 Eligible=function(id)return id==2770 or id==1210 or id==769 end,
 Inputs=function()return{['Item-test']=1001}end,SourceItem=function()return nil end,
 Commit=function(e)if s.track~=false then h:Observe('a','Alice',e)end;for id in pairs(e.items)do s.maps[#s.maps+1]=id end end}
 return ns.Observations.New(api),h,s
end
local function slot(id,guid,qty) return{slot=1,itemID=id,quantity=qty or 1,sources={guid},sourceQuantities={[guid]=qty or 1},quality=1}end
local function finish(o,s,spell,guid)
 if spell then o:Cast('UNIT_SPELLCAST_SUCCEEDED','player',guid or 'cast',spell)end
 o:LootReady();for _,v in ipairs(s.slots)do o:SlotCleared(v.slot)end;o:LootClosed()
end
test('gathering includes ore and rare byproducts with separate quantities',function()
 local o,h,s=fixture();s.slots={slot(2770,'GameObject-0-1-2-3-1731-9',3),slot(1210,'GameObject-0-1-2-3-1731-9')};s.slots[2].slot=2
 finish(o,s,2575);eq(#h:Totals('a'),2);eq(#h:Rates('a'),2);eq(#s.maps,2)
end)
test('ordinary corpse meat records source and duplicate reopening is ignored',function()
 local o,h,s=fixture();s.slots={slot(769,'Creature-0-1-2-3-123-9',2)};finish(o,s);finish(o,s)
 eq(h:Totals('a')[1].quantity,2);eq(h:Rates('a')[1].kind,'Loot');eq(h:Rates('a')[1].source,'123')
end)
test('fishing includes junk in catch denominator',function()
 local o,h,s=fixture();s.fishing=true;s.slots={slot(6291,'GameObject-0-1-2-3-35591-1')};finish(o,s,7620,'c1')
 s.slots={slot(45190,'GameObject-0-1-2-3-35591-2')};finish(o,s,7620,'c2')
 local r=h:Rates('a');eq(#r,2);eq(r[1].trials,2);eq(r[1].percent,50);eq(r[1].kind,'Fishing')
end)
test('enchanting identifies input item and avoids generic location',function()
 local o,h,s=fixture();s.slots={slot(10940,'Item-test',2)};finish(o,s,13262)
 local r=h:Rates('a')[1];eq(r.kind,'Enchanting');eq(r.source,'1001');eq(r.mapID,0)
end)
test('partial loot does not enter rate denominator',function()
 local o,h,s=fixture();s.slots={slot(2770,'GameObject-0-1-2-3-1731-9'),slot(1210,'GameObject-0-1-2-3-1731-9')};s.slots[2].slot=2
 o:Cast('UNIT_SPELLCAST_SUCCEEDED','player','c',2575);o:LootReady();o:SlotCleared(1);o:LootClosed()
 eq(#h:Totals('a'),1);eq(#h:Rates('a'),0)
end)
test('instance loot, failed casts and inventory-only changes do not produce gathering history',function()
 local o,h,s=fixture();s.slots={slot(2770,'GameObject-0-1-2-3-1731-9')};s.allowed=false;finish(o,s,2575);eq(#h:Totals('a'),0)
 s.allowed=true;o:Cast('UNIT_SPELLCAST_START','player','c',2575);o:Cast('UNIT_SPELLCAST_FAILED','player','c',2575)
 -- A failed gathering cast cannot reclassify its node as ordinary useful loot.
 o:LootReady();o:SlotCleared(1);o:LootClosed();eq(#h:Totals('a'),0)
end)
test('delayed source metadata preserves cleared slots',function()
 local o,h,s=fixture();s.slots={{slot=1,itemID=2770,quantity=2,sources={}}}
 o:Cast('UNIT_SPELLCAST_SUCCEEDED','player','c',2575);o:LootReady();o:SlotCleared(1)
 s.slots={slot(2770,'GameObject-0-1-2-3-1731-9',2)};o:LootReady();o:LootClosed();eq(h:Totals('a')[1].quantity,2)
end)
test('money-only sources count as zero outcomes and unclaimed money makes a partial sample',function()
 local o,h,s=fixture();s.slots={slot(769,'Creature-0-1-2-3-123-1')};finish(o,s)
 s.slots={slot(nil,'Creature-0-1-2-3-123-2',10)};finish(o,s)
 eq(h:Rates('a')[1].trials,2);eq(h:Rates('a')[1].percent,50)
 s.slots={slot(769,'Creature-0-1-2-3-123-3'),slot(nil,'Creature-0-1-2-3-123-3',10)};s.slots[2].slot=2
 o:LootReady();o:SlotCleared(1);o:LootClosed();eq(h:Rates('a')[1].trials,2)
end)
test('ordinary loot uses loot position after an unrelated fishing cast',function()
 local o,h,s=fixture();o:Cast('UNIT_SPELLCAST_SUCCEEDED','player','fish',7620)
 o:Cast('UNIT_SPELLCAST_INTERRUPTED','player','fish',7620)
 s.position={mapID=2,x=.8,y=.2};s.slots={slot(769,'Creature-0-1-2-3-123-1')};finish(o,s)
 eq(h:Totals('a')[1].mapID,2);eq(h:Rates('a')[1].x,.8)
end)
test('fishing without a known spell still distinguishes catches from the same pool',function()
 local o,h,s=fixture();s.fishing=true;s.slots={slot(6291,'GameObject-0-1-2-3-35591-1')}
 finish(o,s);finish(o,s);eq(h:Rates('a')[1].trials,2)
end)
test('item loot after disenchant can retain an explicitly unknown input',function()
 local o,h,s=fixture();s.slots={{slot=1,itemID=10940,quantity=2,sources={}}}
 o:Cast('UNIT_SPELLCAST_SUCCEEDED','player','d1',13262)
 o:LootReady(true);o:SlotCleared(1);o:LootClosed()
 local r=h:Rates('a')[1];assert(r);eq(r.source,'unknown input');eq(r.kind,'Enchanting')
end)
test('a partial fishing receipt keeps its identity when reopened',function()
 local o,h,s=fixture();s.fishing=true
 s.slots={slot(6291,'GameObject-0-1-2-3-35591-1'),slot(45190,'GameObject-0-1-2-3-35591-1')};s.slots[2].slot=2
 o:LootReady();o:SlotCleared(1);o:LootClosed();eq(#h:Rates('a'),0)
 s.slots={slot(45190,'GameObject-0-1-2-3-35591-1')};finish(o,s)
 eq(#h:Rates('a'),2);eq(h:Rates('a')[1].trials,1);eq(h:Rates('a')[1].hits,1)
end)
test('area loot allocates quantities and trials to each source',function()
 local o,h,s=fixture();local a,b='Creature-0-1-2-3-123-1','Creature-0-1-2-3-123-2'
 s.slots={{slot=1,itemID=769,quantity=5,sources={a,b},sourceQuantities={[a]=2,[b]=3}}}
 finish(o,s);local r=h:Rates('a')[1];eq(r.trials,2);eq(r.hits,2);eq(r.quantity,5);eq(r.percent,100)
end)
test('late fishing metadata remains usable after cleared loot slots',function()
 local o,h,s=fixture();s.slots={slot(6291,'GameObject-0-1-2-3-35591-1')}
 o:Cast('UNIT_SPELLCAST_SUCCEEDED','player','fish',7620);o:LootReady();o:SlotCleared(1)
 s.fishing=true;o:LootReady();o:LootClosed();eq(h:Rates('a')[1].kind,'Fishing')
end)
test('remaining unidentified item loot retains lifetime quantities without a guessed disenchant rate',function()
 local o,h,s=fixture();s.slots={{slot=1,itemID=2770,quantity=2,sources={}},{slot=2,itemID=1210,quantity=1,sources={}}}
 o:Cast('UNIT_SPELLCAST_SUCCEEDED','player','d1',13262);o:LootReady(true);o:SlotCleared(1);o:LootClosed()
 s.slots={{slot=1,itemID=1210,quantity=1,sources={}}}
 o:LootReady(true);o:SlotCleared(1);o:LootClosed()
 eq(h:Total('a',2770),2);eq(h:Total('a',1210),1);eq(#h:Rates('a'),0)
end)
print('PASS '..passed..' source observation checks')
