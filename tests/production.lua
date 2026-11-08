local ns={}
assert(loadfile('TitanGatheredForeverV3/Production.lua'))('TGF v3',ns)
local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,f)local ok,e=pcall(f);if not ok then error(n..': '..e)end;passed=passed+1 end
local function result(op,item,qty)
 return {operationID=op or 1,itemID=item or 2680,quantity=qty or 2,itemGUID='Item-output',hyperlink='item:2680',
  resourcesReturned=nil,craftingQuality=nil,qualityProgress=0,isCrit=false,critBonusSkill=0,recraftable=false,
  bonusCraft=false,multicraft=0,firstCraftReward=false,isEnchant=false,hasIngenuityProc=false,
  concentrationCurrencyID=0,concentrationSpent=0,ingenuityRefund=0}
end
local function fixture(saved)
 local s={clock=100,character='a',enabled=true,secret={},recipes={
  [2536]={recipeID=2536,name='Spiced Wolf Meat',kind='Cooking',outputItemID=2680,outputIDs={[2680]=true}},
  [1000]={recipeID=1000,name='Other recipe',kind='Alchemy',outputItemID=2680,outputIDs={[2680]=true}}}}
 local p=ns.Production.New(saved or {},{Now=function()return s.clock end,Timestamp=function()return s.clock end,
  Character=function()return s.character end,Name=function()return s.character end,Enabled=function()return s.enabled end,
  Public=function(v)return v~=s.secret end,Recipe=function(id)return s.recipes[id]end})
 return p,s
end
local function cast(p,event,guid,id,unit)p:Cast('UNIT_SPELLCAST_'..event,unit or 'player',guid or 'a',id or 2536)end
local function complete(p,guid,id)cast(p,'START',guid,id);cast(p,'SUCCEEDED',guid,id)end
test('success and explicit result record one operation and actual quantity',function()
 local p=fixture();cast(p,'START');cast(p,'SUCCEEDED');p:Result(result());p:Result(result());cast(p,'SUCCEEDED')
 local r=p:Rows('a')[1];eq(r.attempts,1);eq(r.completed,1);eq(r.matched,1);eq(r.quantity,2)
 eq(p:Total('a',2680),2);eq(r.outputs[2680].distribution[2],1)
end)
test('queued repeated recipes preserve operations and variable output distribution',function()
 local p=fixture();for i,q in ipairs({2,2,5})do cast(p,'START','c'..i);cast(p,'SUCCEEDED','c'..i);p:Result(result(i,2680,q))end
 local r=p:Rows()[1];eq(r.completed,3);eq(r.matched,3);eq(r.quantity,9)
 eq(r.outputs[2680].hits,3);eq(r.outputs[2680].distribution[2],2);eq(r.outputs[2680].distribution[5],1)
end)
test('output before success waits for cast confirmation',function()
 local p=fixture();cast(p,'START');p:Result(result());eq(p:Total('a',2680),0)
 cast(p,'STOP');cast(p,'SUCCEEDED');eq(p:Total('a',2680),2);eq(p:Rows()[1].matched,1)
end)
test('failed and interrupted casts never turn buffered results into production',function()
 local p=fixture();cast(p,'START','a');p:Result(result());cast(p,'FAILED','a');cast(p,'SUCCEEDED','a')
 cast(p,'START','b');p:Result(result(2));cast(p,'INTERRUPTED','b');cast(p,'SUCCEEDED','b')
 local r=p:Rows()[1];eq(r.failed,1);eq(r.interrupted,1);eq(r.completed,0);eq(r.quantity,0)
end)
test('ordinary loot bag changes and unpaired results cannot invent production',function()
 local p=fixture();p:Result(result());cast(p,'START','other',123);cast(p,'SUCCEEDED','other',123)
 eq(#p:Rows(),0);eq(#p:Totals(),0)
end)
test('pending recipes sharing an output are ambiguous and skipped',function()
 local p=fixture();complete(p,'a',2536);complete(p,'b',1000);p:Result(result())
 eq(p:Total('a',2680),0)
end)
test('result identity binds multiple outputs to one operation',function()
 local p=fixture();complete(p);p:Result(result());p:Result(result(1,9999,1));p:Result(result(1,9999,1))
 local r=p:Rows()[1];eq(r.completed,1);eq(r.matched,1);eq(r.quantity,3)
 eq(r.outputs[9999].quantity,1);eq(r.outputs[9999].hits,1)
end)
test('first craft rewards and enchant payloads are not produced items',function()
 local p=fixture();complete(p);local d=result();d.firstCraftReward=true;p:Result(d)
 d=result();d.isEnchant=true;p:Result(d);eq(p:Total('a',2680),0)
end)
test('proc rates retain readable denominators and never infer procs from quantity',function()
 local p,s=fixture();complete(p,'a');local d=result(1,2680,10);d.multicraft=s.secret;d.bonusCraft=s.secret;p:Result(d)
 complete(p,'b');d=result(2);d.multicraft=3;d.bonusCraft=true;p:Result(d)
 complete(p,'c');p:Result(result(3))
 local r=p:Rows()[1];eq(r.multicraftKnown,2);eq(r.multicraftHits,1);eq(r.bonusKnown,2);eq(r.bonusHits,1)
end)
test('protected or invalid identity and quantities are rejected',function()
 local p,s=fixture();complete(p)
 for _,field in ipairs({'operationID','itemID','quantity','itemGUID','firstCraftReward','isEnchant'})do
  local d=result();d[field]=s.secret;p:Result(d)
 end
 p:Result(result(0));p:Result(result(1,2680,-1));p:Result(result(1,2680,1.5));p:Result(s.secret)
 eq(p:Total('a',2680),0)
end)
test('stale contexts and mismatched primary outputs do not claim results',function()
 local p,s=fixture();complete(p);p:Result(result(1,9999));eq(p:Total('a',9999),0)
 s.clock=161;p:Result(result());eq(p:Total('a',2680),0)
end)
test('policy pause and reload seal pending and late output',function()
 local saved={};local p,s=fixture(saved);cast(p,'START');p:Result(result());p:Pause();cast(p,'SUCCEEDED')
 eq(p:Total('a',2680),0);s.enabled=false;cast(p,'SUCCEEDED','b');s.enabled=true
 cast(p,'START','c');local next=fixture(saved);cast(next,'SUCCEEDED','c');next:Result(result(3));eq(next:Total('a',2680),0)
 eq(next:Rows()[1].attempts,2);eq(next:Rows()[1].completed,0)
end)
test('combined view adds per-character output and keeps earliest coverage',function()
 local p,s=fixture();complete(p);p:Result(result());s.character='b';s.clock=200
 complete(p,'b');p:Result(result(2,2680,4))
 local r=p:Rows()[1];eq(r.completed,2);eq(r.quantity,6);eq(r.began,100);eq(p:Total('b',2680),4)
 eq(p:Totals()[1].quantity,6)
end)
test('recent receipts are bounded and saved totals survive reload',function()
 local saved={};local p=fixture(saved)
 for i=1,1100 do complete(p,'c'..i);p:Result(result(i))end
 eq(#saved.characters.a.order,1024);eq(p:Total('a',2680),2200)
 local next=fixture(saved);eq(next:Total('a',2680),2200);eq(next:Rows()[1].completed,1100)
end)
test('future schemas and nonplayer events remain untouched',function()
 local saved={schema=2,characters={future=true}};local p=fixture(saved);cast(p,'START');p:Result(result());p:Pause()
 eq(#p:Rows(),0);eq(saved.characters.future,true)
 local p=fixture();cast(p,'START','a',2536,'party1');eq(#p:Rows(),0)
end)
test('sealed unmatched outputs block new attribution across a recording gap',function()
 local p,s=fixture();complete(p,'old');p:Pause();complete(p,'new')
 p:Result(result(1,2680,7));p:Result(result(2,2680,2));eq(p:Total('a',2680),0)
 eq(p:Rows()[1].completed,2);eq(p:Rows()[1].matched,0)
 s.clock=161;complete(p,'later');p:Result(result(3));eq(p:Total('a',2680),2)
end)
test('terminal events without an observed enabled start cannot create production',function()
 local p,s=fixture();cast(p,'SUCCEEDED','missing');eq(#p:Rows(),0)
 s.enabled=false;cast(p,'START','off');s.enabled=true;cast(p,'SUCCEEDED','off');p:Result(result())
 eq(#p:Rows(),0)
end)
test('secondary output before primary binding remains unattributed',function()
 local p=fixture();complete(p);p:Result(result(1,9999,1));p:Result(result());eq(p:Total('a',9999),0)
 eq(p:Total('a',2680),2)
end)
print('PASS '..passed..' crafting production checks')
