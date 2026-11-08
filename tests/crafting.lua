local ns={}
assert(loadfile('TitanGatheredForeverV3/Crafting.lua'))('TGF v3',ns)
local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,f)local ok,e=pcall(f);if not ok then error(n..': '..e)end;passed=passed+1 end
local secret={};ns.IsPublic=function(v)return v~=secret end
local function slot(id,quantity,index)
 return {slotIndex=index or 1,dataSlotIndex=index or 1,reagentType=1,required=true,quantityRequired=quantity or 2,
  reagents={{itemID=id}},variableQuantities={},dataSlotType=1,hiddenInCraftingForm=false}
end
local function recipe(slots)return {recipeID=2536,name='Recipe',kind='Cooking',learned=true,slots=slots or{slot(2672,2),slot(159,1,2)}}end
local function inventory(bags,bank,bagsState,bankState)
 return {Get=function(_,id)return{bags=(bags or{})[id]or 0,bank=(bank or{})[id]or 0,
  bagsState=bagsState or'current',bankState=bankState or'current',bankObservedAt=100}end}
end
test('fixed reagent quantities yield deficits and a material-limited operation count',function()
 local p=ns.Crafting.Compute(recipe(),inventory({[2672]=7,[159]=2}),false,3)
 eq(p.craftable,2);eq(p.operations,3);eq(p.scope,'Bags');eq(p.rows[1].itemID,159)
 eq(p.rows[2].required,6);eq(p.rows[2].available,7);eq(p.rows[2].missing,0);eq(p.rows[1].missing,1)
end)
test('bank scope follows display selection and never leaks hidden bank quantities',function()
 local inv=inventory({[2672]=2,[159]=1},{[2672]=8,[159]=10},'current','cached')
 local bags=ns.Crafting.Compute(recipe(),inv,false,1);eq(bags.craftable,1);eq(bags.cached,false);eq(bags.bankObservedAt,nil)
 local total=ns.Crafting.Compute(recipe(),inv,true,1);eq(total.craftable,5);eq(total.scope,'Bags + Bank');eq(total.cached,true);eq(total.bankObservedAt,100)
end)
test('repeated item slots are aggregated before determining capacity',function()
 local p=ns.Crafting.Compute(recipe({slot(2672,2),slot(2672,3,2)}),inventory({[2672]=9}),false,2)
 eq(#p.rows,1);eq(p.rows[1].perOperation,5);eq(p.rows[1].missing,1);eq(p.craftable,1)
end)
test('unknown inventory displays zero without asserting an actual material limit',function()
 local p=ns.Crafting.Compute(recipe(),inventory({},nil,'unknown'),false,1);eq(p.craftable,nil);eq(p.unknown,true)
 eq(p.rows[1].available,0);eq(p.rows[1].missing,1)
 local p=ns.Crafting.Compute(recipe(),inventory({[2672]=6,[159]=6},nil,'current','unknown'),true,1)
 eq(p.craftable,nil);eq(p.unknown,true)
end)
test('cached bags retain estimates and their status',function()
 local p=ns.Crafting.Compute(recipe(),inventory({[2672]=6,[159]=3},nil,'cached'),false,1)
 eq(p.craftable,3);eq(p.cached,true)
end)
test('optional modifying reagents do not reduce the basic material limit',function()
 local optional=slot(999,1,3);optional.reagentType=0;optional.required=false
 local p=ns.Crafting.Compute(recipe({slot(2672,2),optional}),inventory({[2672]=6}),false,1)
 eq(p.craftable,3);eq(#p.rows,1);eq(p.optionalExcluded,true)
end)
test('unresolved required alternatives suppress a misleading aggregate estimate',function()
 local alternative=slot(2672);alternative.reagents={{itemID=2672},{itemID=2673}}
 local p=ns.Crafting.Compute(recipe({alternative}),inventory({[2672]=20}),false,1)
 eq(p.craftable,nil);assert(#p.issues>0)
end)
test('required currency and variable-quantity slots remain unresolved',function()
 local currency=slot(2672);currency.reagents={{currencyID=10}};currency.dataSlotType=3
 local variable=slot(2672);variable.variableQuantities={{reagent={itemID=2672},quantity=2}}
 for _,s in ipairs({currency,variable})do
  local p=ns.Crafting.Compute(recipe({s}),inventory({[2672]=20}),false,1);eq(p.craftable,nil);assert(#p.issues>0)
 end
end)
test('required modifiers and automatic slots cannot silently disappear',function()
 for _,kind in ipairs({0,2,3})do local s=slot(2672);s.reagentType=kind
  local p=ns.Crafting.Compute(recipe({s}),inventory({[2672]=20}),false,1);eq(p.craftable,nil);assert(#p.issues>0)
 end
end)
test('protected and malformed required fields fail closed',function()
 for _,field in ipairs({'required','reagentType','quantityRequired','reagents','variableQuantities','dataSlotType'})do
  local s=slot(2672);s[field]=secret
  local p=ns.Crafting.Compute(recipe({s}),inventory({[2672]=20}),false,1);eq(p.craftable,nil);assert(#p.issues>0)
 end
 local s=slot(2672);s.reagents[1].itemID=secret
 eq(ns.Crafting.Compute(recipe({s}),inventory(),false,1).craftable,nil)
end)
test('missing zero sparse or duplicate slots do not imply unlimited capacity',function()
 for _,slots in ipairs({{}, {slot(2672,0)}, {[2]=slot(2672)}, {slot(2672),slot(159)}})do
  local p=ns.Crafting.Compute(recipe(slots),inventory({[2672]=20,[159]=20}),false,1);eq(p.craftable,nil);assert(p.error or #p.issues>0)
 end
end)
test('invalid operation targets are rejected without inventory access',function()
 for _,target in ipairs({0,-1,1.5,math.huge,1000001})do
  local p=ns.Crafting.Compute(recipe(),{Get=function()error('must not scan')end},false,target)
  eq(p.craftable,nil);eq(#p.rows,0);assert(p.error)
 end
end)
test('source evidence keeps zone trials separate from saved positions',function()
 ns.history={Rates=function()return{{mapID=1,kind='Mining',trials=2,hits=2,percent=100},
  {mapID=2,kind='Mining',trials=20,hits=3,percent=15}}end}
 ns.gathering={saved={maps={[1]={{itemID=2672},{itemID=2672},{itemID=159}}}}}
 local e=ns.Crafting.Evidence(2672,'a');eq(e.rates[1].trials,20);eq(e.spots[1].positions,2);eq(e.spots[1].mapID,1)
end)
local function liveAPI()
 ns.settings={showBank=false,categories={}};ns.Catalog={modules={Cooking={}}}
 C_TradeSkillUI={GetRecipeInfo=function(id)return{recipeID=id,name='Recipe',learned=false,isRecraft=false,
  isDummyRecipe=false,isGatheringRecipe=false,isSalvageRecipe=false}end,
  GetProfessionInfoByRecipeID=function()return{professionID=185}end,
  GetRecipeSchematic=function(id,recraft)eq(recraft,false);return{recipeID=id,recipeType=1,isRecraft=false,
   reagentSlotSchematics={slot(2672,2)}}end}
end
test('live schematics supply quantities even for an unlearned ordinary recipe',function()
 liveAPI();local r=ns.Crafting.Read(2536);eq(r.kind,'Cooking');eq(r.learned,false);eq(r.slots[1].quantityRequired,2)
 ns.inventory=inventory({[2672]=7});local p=ns.Crafting.Plan(2536,3);eq(p.craftable,3);eq(p.rows[1].required,6)
end)
test('disabled and missing modules cannot supply a recipe estimate',function()
 liveAPI();ns.settings.categories.Cooking=false;eq(ns.Crafting.Read(2536),nil)
 ns.settings.categories={};ns.Catalog.modules={};eq(ns.Crafting.Read(2536),nil)
end)
test('unknown protected wrong-identity or recraft metadata produces no plan',function()
 liveAPI();C_TradeSkillUI.GetRecipeInfo=function()return secret end;eq(ns.Crafting.Read(2536),nil)
 liveAPI();C_TradeSkillUI.GetRecipeSchematic=function()return{recipeID=999,recipeType=1,isRecraft=false,reagentSlotSchematics={}}end
 eq(ns.Crafting.Read(2536),nil)
 liveAPI();C_TradeSkillUI.GetRecipeInfo=function(id)return{recipeID=id,name='Recraft',learned=true,isRecraft=true,
  isDummyRecipe=false,isGatheringRecipe=false,isSalvageRecipe=false}end
 eq(ns.Crafting.Read(2536),nil);C_TradeSkillUI=nil;eq(ns.Crafting.Read(2536),nil)
 assert(ns.Crafting.Plan(2536,1).error)
end)
print('PASS '..passed..' contextual crafting checks')
