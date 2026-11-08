local ns={}
for _,file in ipairs({'History.lua','Actions.lua','Production.lua','Export.lua'})do
 assert(loadfile('TitanGatheredForeverV3/'..file))('TGF v3',ns)
end
local saved={history={},actions={},production={}}
local state={character='Player-private-A',clock=100}
local function name()return state.character=='Player-private-A'and 'Žofie "Private"\\Realm\nLine'or'OtherPrivate-Realm'end
local api={Character=function()return state.character end,Name=name,Timestamp=function()return state.clock end,
 Now=function()return state.clock end,Enabled=function()return true end,Public=function()return true end,
 Recipe=function(id)return{recipeID=id,name='PrivateRecipeLabel',kind='Cooking',outputItemID=2680,outputIDs={[2680]=true}}end}
local h,a,p=ns.History.New(saved.history),ns.Actions.New(saved.actions,api),ns.Production.New(saved.production,api)
local function observe(id,items,complete,policy)
 h:Observe(state.character,name(),{id=id,kind='Mining',mapID=1,x=.123,y=.456,source='1731',sourceName='PrivateSourceLabel',
  instanceType='none',at=state.clock,items=items,complete=complete~=false,policy=policy})
end
observe('private-receipt-one',{[2770]=2},true,{key='private-policy-key',items={[2770]=true},knownItems={[2770]=true},rare=false})
observe('private-receipt-zero',{},true,{key='private-policy-key',items={[2770]=true},knownItems={[2770]=true},rare=false})
observe('private-receipt-partial',{[1210]=3},false)
a:Cast('UNIT_SPELLCAST_START','player','private-cast-pending',2575)
for i,quantity in ipairs({2,4})do
 p:Cast('UNIT_SPELLCAST_START','player','private-production-'..i,2536)
 p:Cast('UNIT_SPELLCAST_SUCCEEDED','player','private-production-'..i,2536)
 p:Result({operationID=i,itemID=2680,itemGUID='private-item-guid-'..i,quantity=quantity,
  firstCraftReward=false,isEnchant=false,multicraft=i==2 and 2 or 0,bonusCraft=i==2})
end
p:Cast('UNIT_SPELLCAST_START','player','private-production-pending',2536)
state.character='Player-private-B';state.clock=200
observe('private-other-source',{[2770]=1})
a:Cast('UNIT_SPELLCAST_SUCCEEDED','player','private-other-cast',2575)
saved.secret='PrivateUnrelatedSavedData'
return {ns=ns,saved=saved,state=state,sources={history=h,actions=a,production=p,character='Player-private-A',
 version='0.4.1-alpha',timestamp=300,sourceSHA256='catalogue-hash'}}
