local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,f)local ok,e=pcall(f);if not ok then error(n..': '..e)end;passed=passed+1 end
local function region()return{SetPoint=function()end,SetWidth=function()end,SetJustifyH=function()end,SetText=function(self,v)self.text=v end}end
local function frame()
 local f={scripts={},shown=false,TitleText=region(),buttons={}}
 for _,m in ipairs({'SetSize','SetPoint','ClearAllPoints','SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetThumbTexture','EnableMouseWheel','SetValue','SetColorTexture','SetAllPoints','SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing'})do f[m]=function()end end
 function f:SetScript(k,fn)self.scripts[k]=fn end
 function f:SetText(v)self.text=v end
 function f:CreateFontString()return region()end
 function f:CreateTexture()return{SetAllPoints=function()end,SetColorTexture=function()end}end
 function f:GetThumbTexture()return{SetSize=function()end}end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 return f
end
CreateFrame=function(_,_,parent)local f=frame();if parent then parent.buttons[#parent.buttons+1]=f end;return f end
UIParent=frame();UISpecialFrames={};UnitGUID=function()return'a'end
GameTooltip={SetOwner=function()end,SetItemByID=function(self,id)self.item=id end,Show=function()end,Hide=function()end}
C_Map={GetMapInfo=function(id)return{name='Zone '..id}end}
local menu
MenuUtil={CreateContextMenu=function(_,fn)
 menu={titles={},buttons={},CreateTitle=function(self,t)self.titles[#self.titles+1]=t end,
  CreateButton=function(self,t,cb)self.buttons[t]=cb end,SetScrollMode=function()end};fn({},menu)
end}
local ns={IsPublic=function()return true end,settings={showBank=false,categories={}},
 ItemName=function(id)return'Item '..id end,Style={ItemName=function(id)return'Item '..id end},
 Catalog={modules={Cooking={}},Get=function()return{recipes={2536}}end}}
ns.Style.MenuNote=function(root,value)return root:CreateTitle(value)end
local slots={}
for i=1,7 do slots[i]={slotIndex=i,dataSlotIndex=i,reagentType=1,required=true,quantityRequired=1,
 reagents={{itemID=1000+i}},variableQuantities={},dataSlotType=1}end
C_TradeSkillUI={GetRecipeInfo=function(id)if id==2536 then return{recipeID=id,name='Meal',learned=true,isRecraft=false,
 isDummyRecipe=false,isGatheringRecipe=false,isSalvageRecipe=false}end end,
 GetProfessionInfoByRecipeID=function()return{professionID=185}end,
 GetRecipeSchematic=function(id)return{recipeID=id,recipeType=1,isRecraft=false,reagentSlotSchematics=slots}end}
ns.inventory={Get=function(_,id)return{bags=id-1000,bagsState='current',bank=10,bankState='cached',bankObservedAt=100}end}
for _,file in ipairs({'History.lua','Crafting.lua','Navigation.lua','Reports.lua','CraftingView.lua'})do assert(loadfile('TitanGatheredForeverV3/'..file))('TGF v3',ns)end
ns.history=ns.History.New({})
ns.history:Observe('a','A',{id='one',kind='Mining',source='123',mapID=4,at=100,complete=true,items={[1001]=1}})
ns.gathering={saved={maps={[4]={{itemID=1001,kind='Mining',x=.5,y=.5}}}}}
test('planner shows deficits material limit scope and source evidence',function()
 ns.CraftingView.Show(2536,3);local w=ns.CraftingView.window
 assert(w and w:IsShown());eq(#w.rows,6);assert(w.summary.text:find('Material limit: 1 operations',1,true))
 assert(w.rows[1].detail.text:find('need 3, have 1, missing 2',1,true))
 assert(w.rows[1].detail.text:find('Zone 4',1,true));eq(#UISpecialFrames,1)
 eq(ns.history:Total('a',1001),1)
end)
test('planner paging and error states hide stale rows',function()
 local w=ns.CraftingView.window;w.offset=6;ns.CraftingView.Refresh();eq(w.offset,1);eq(w.rows[1].data.itemID,1002);eq(w.rows[6].data.itemID,1007)
 w.offset=0;ns.CraftingView.Refresh();eq(w.rows[1].data.itemID,1001);assert(w.pageText.text:find('1-6 of 7',1,true))
 ns.CraftingView.Show(999,1);assert(w.summary.text:find('unavailable',1,true));eq(w.rows[1]:IsShown(),false)
 ns.CraftingView.Show(2536,3);eq(w.offset,0);eq(w.rows[1]:IsShown(),true)
end)
test('planner reagent click exposes rates saved positions and contextual recipe links',function()
 local row=ns.CraftingView.window.rows[1];row.scripts.OnClick(row)
 local combined=table.concat(menu.titles,' ');assert(combined:find('source and zone',1,true));assert(combined:find('coordinate',1,true))
 local positionButton
 for label,callback in pairs(menu.buttons)do if label:find('saved positions',1,true)then positionButton=callback end end
 assert(positionButton);WorldMapFrame={Show=function(self)self.shown=true end,SetMapID=function(self,id)self.mapID=id end}
 positionButton();eq(WorldMapFrame.mapID,4)
 row.scripts.OnEnter(row);eq(GameTooltip.item,1001)
end)
test('bank scope refresh retains cached estimate and never scans inventory',function()
 ns.settings.showBank=true;ns.CraftingView.Refresh();local w=ns.CraftingView.window
 assert(w.summary.text:find('11 operations',1,true));assert(w.summary.text:find('cached',1,true))
 assert(w.note.text:find('Bags + Bank',1,true));assert(w.note.text:find('100',1,true))
end)
test('map history label cannot imply a probability at one pin',function()
 assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TGF v3',ns)
 local _,note=ns.PinStyle.HistoryLines({itemID=1001,mapID=4,kind='Mining'})
 assert(note and note:find('not a chance at this coordinate',1,true))
end)
print('PASS '..passed..' crafting planner window checks')
