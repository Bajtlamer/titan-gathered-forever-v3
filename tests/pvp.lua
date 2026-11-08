local ns={}
COMBATLOG_HONORGAIN='%s dies, honorable kill Rank: %s (Estimated Honor Points: %d)'
assert(loadfile('TitanGatheredForeverV3/PvP.lua'))('TGF v3',ns)
local PvP=ns.PvP
local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(name,fn)local ok,err=pcall(fn);if not ok then error(name..': '..err)end;passed=passed+1 end
local function fixture(saved)
 local state={character='a',timestamp=100,now=1,changed=0}
 local p=PvP.New(saved or {},{Character=function()return state.character end,
  Timestamp=function()return state.timestamp end,Now=function()return state.now end,
  Changed=function()state.changed=state.changed+1 end})
 return p,state
end

test('honor event parser extracts the awarded PvP victim and estimated honor',function()
 local victim,rank,honor=PvP.ParseHonorMessage('Enemy dies, honorable kill Rank: Private (Estimated Honor Points: 42)')
 eq(victim,'Enemy');eq(rank,'Private');eq(honor,42)
end)
test('generic honor awards do not look like a player kill',function()
 eq(PvP.ParseHonorMessage('You have been awarded 50 honor points.'),nil)
end)
test('death recap counts hostile player killing blows and rejects creatures or nonlethal attackers',function()
 local p=fixture()
 local playerFlags=0x00000040+0x00000400
 local creatureFlags=0x00000040+0x00000800
 assert(p:DeathRecap({{{sourceName='Enemy',sourceFlags=playerFlags,overkill=3}}},'none','d1'))
 eq(p:DeathRecap({{sourceName='Wolf',sourceFlags=creatureFlags,overkill=12}},'none','d2'),false)
 eq(p:DeathRecap({{sourceName='Enemy',sourceFlags=playerFlags,overkill=-1}},'none','d3'),false)
 eq(p:DeathRecap({{sourceName='Enemy',sourceFlags=0x00000040+0x00000400,overkill=5}},'pvp','d4'),true)
 local row=p:Snapshot('a');eq(row.deaths.world,1);eq(row.deaths.battleground,1);eq(row.deaths.total,2)
end)
test('outdoor honor receipt counts an eligible assist and preserves its location',function()
 local p,s=fixture()
 local accepted=p:HonorMessage('Enemy dies, honorable kill Rank: Private (Estimated Honor Points: 42)',
  {mapID=141,x=.4,y=.6,context='none',eventToken='line-1'})
 assert(accepted);eq(accepted.victim,'Enemy');eq(accepted.estimatedHonor,42)
 local row=p:Snapshot('a');eq(row.worldKills,1);eq(row.worldHonorEstimate,42);eq(row.coverageBegan,100)
 eq(s.changed,1)
end)
test('honor kills in battlegrounds and arenas are tracked without world map positions',function()
 local p=fixture()
 local bg=p:HonorMessage('Enemy dies, honorable kill Rank: Private (Estimated Honor Points: 42)',
  {mapID=489,x=.4,y=.6,context='pvp',eventToken='bg-1'})
 local arena=p:HonorMessage('Enemy dies, honorable kill Rank: Private (Estimated Honor Points: 42)',
  {mapID=559,x=.4,y=.6,context='arena',eventToken='arena-1'})
 assert(bg and not bg.position and arena and not arena.position)
 local row=p:Snapshot('a');eq(row.worldKills,0);eq(row.battlegroundKills,1);eq(row.arenaKills,1)
 eq(row.battlegroundHonorEstimate,42);eq(row.arenaHonorEstimate,42)
end)
test('duplicate honor event token is counted once while a later kill can count again',function()
 local p,s=fixture();local message='Enemy dies, honorable kill Rank: Private (Estimated Honor Points: 42)'
 local context={mapID=141,x=.4,y=.6,context='none',eventToken='same'}
 p:HonorMessage(message,context);p:HonorMessage(message,context)
 context.eventToken='later';s.now=2;p:HonorMessage(message,context)
 eq(p:Snapshot('a').worldKills,2);eq(p:Snapshot('a').worldHonorEstimate,84)
end)
test('only validated PvP death signals are counted by context',function()
 local p=fixture()
 p:Death({playerCaused=true,killer='Enemy'},'none')
 p:Death({playerCaused=true,killer='Enemy'},'pvp')
 p:Death({playerCaused=true,killer='Enemy'},'arena')
 p:Death({playerCaused=false,killer='Wolf'},'none')
 p:Death({},'none')
 local row=p:Snapshot('a');eq(row.deaths.world,1);eq(row.deaths.battleground,1);eq(row.deaths.arena,1);eq(row.deaths.total,3)
end)
test('observed PvP data persists per character with explicit coverage',function()
 local saved={};local p,s=fixture(saved)
 p:Death({playerCaused=true,killer='Enemy'},'none')
 s.character='b';s.timestamp=200
 p:Death({playerCaused=true,killer='Enemy'},'pvp')
 local a,b=p:Snapshot('a'),p:Snapshot('b')
 eq(a.deaths.total,1);eq(a.coverageBegan,100);eq(b.deaths.total,1);eq(b.coverageBegan,200)
 local reloaded=PvP.New(saved,{Character=function()return'a'end,Timestamp=function()return 300 end,Now=function()return 3 end})
 eq(reloaded:Snapshot('a').deaths.world,1);eq(reloaded:Snapshot('b').deaths.battleground,1)
end)
test('native lifetime kills and current rank are exposed when client APIs provide them',function()
 local saved={};local p=PvP.New(saved,{Character=function()return'a'end,Timestamp=function()return 100 end,
  LifetimeStats=function()return 27,8 end,CurrentRank=function()return 6,'Knight' end})
 local row=p:Snapshot('a');eq(row.lifetimeHonorableKills,27);eq(row.highestRankID,8)
 eq(row.currentRankID,6);eq(row.currentRankName,'Knight')
 local unavailable=PvP.New({}, {Character=function()return'b'end,Timestamp=function()return 100 end}):Snapshot('b')
 eq(unavailable.lifetimeHonorableKills,nil);eq(unavailable.currentRankID,nil)
 local malformed=PvP.New({}, {Character=function()return'c'end,Timestamp=function()return 100 end,
  LifetimeStats=function()return'27','bad'end,CurrentRank=function()return{},'Knight'end}):Snapshot('c')
 eq(malformed.lifetimeHonorableKills,nil);eq(malformed.highestRankID,nil);eq(malformed.currentRankID,nil)
end)
assert(loadfile('TitanGatheredForeverV3/Gathering.lua'))('TGF v3',ns)
test('PvP map nodes merge nearby events, preserve estimate totals and clear by type',function()
 local gathering=ns.Gathering.New({Timestamp=function()return 100 end}, {maps={}},function()return{}end,function()return true end)
 gathering:RecordPvP({mapID=141,x=.4,y=.6},42)
 gathering:RecordPvP({mapID=141,x=.401,y=.6},18)
 gathering:RecordPvP({mapID=141,x=.41,y=.6},9)
 local nodes=gathering.saved.maps[141]
 eq(#nodes,2);eq(nodes[1].kind,'PvP');eq(nodes[1].itemID,nil);eq(nodes[1].count,2);eq(nodes[1].honorEstimate,60)
 eq(gathering:Count(141,'PvP'),2);eq(gathering:Clear(141,'Mining'),0);eq(gathering:Count(141,'PvP'),2)
 eq(gathering:Clear(141,'PvP'),2);eq(gathering:Count(141,'PvP'),0)
end)

print('PASS '..passed..' PvP observation checks')
