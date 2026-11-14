local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,f)local ok,e=pcall(f);if not ok then error(n..': '..e)end;passed=passed+1 end
local function region()return{SetPoint=function()end,SetWidth=function()end,SetJustifyH=function()end,SetWordWrap=function()end,SetText=function(self,v)self.text=v end}end
local function frame()
 local f={scripts={},shown=false,TitleText=region(),buttons={}}
 for _,m in ipairs({'SetSize','SetPoint','ClearAllPoints','SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetThumbTexture','EnableMouseWheel','SetValue','SetColorTexture','SetAllPoints','SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing','SetNumeric','SetMaxLetters','SetAutoFocus','ClearFocus'})do f[m]=function()end end
 function f:SetScript(k,fn)self.scripts[k]=fn end
 function f:SetText(v)self.text=v end
 function f:GetText()return self.text end
 function f:HasFocus()return false end
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
local slots={}
for i=1,7 do slots[i]={slotIndex=i,dataSlotIndex=i,reagentType=1,required=true,quantityRequired=1,
 reagents={{itemID=1000+i}},variableQuantities={},dataSlotType=1}end
C_TradeSkillUI={GetRecipeInfo=function(id)if id==2536 then return{recipeID=id,name='Meal',learned=true,isRecraft=false,
 isDummyRecipe=false,isGatheringRecipe=false,isSalvageRecipe=false}end end,
 GetProfessionInfoByRecipeID=function()return{professionID=185}end,
 GetRecipeSchematic=function(id)return{recipeID=id,recipeType=1,isRecraft=false,reagentSlotSchematics=slots}end}
ns.inventory={Get=function(_,id)return{bags=id-1000,bagsState='current',bank=10,bankState='cached',bankObservedAt=100}end}
for _,file in ipairs({'Style.lua','History.lua','Crafting.lua','Navigation.lua','Reports.lua','CraftingView.lua'})do assert(loadfile('TitanGatheredForeverV3/'..file))('TGF v3',ns)end
ns.Style.ItemName=function(id)return'Item '..id end
ns.history=ns.History.New({})
ns.history:Observe('a','A',{id='one',kind='Mining',source='123',mapID=4,at=100,complete=true,items={[1001]=1}})
ns.gathering={saved={maps={[4]={{itemID=1001,kind='Mining',x=.5,y=.5}}}}}
local function plain(text)return(tostring(text):gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''))end
test('reagents are sorted with the missing ones first and show need, bags, bank and where to get them',function()
 ns.CraftingView.Show(2536,3);local w=ns.CraftingView.window
 assert(w and w:IsShown());eq(#w.rows,18);eq(#UISpecialFrames,1)
 eq(w.rows[1].data.itemID,1001);eq(w.rows[1].data.state,'missing')   -- 1 in the bags, 3 needed
 eq(w.rows[1].need.text,'3');eq(w.rows[1].bags.text,'1');eq(w.rows[1].bank.text,'-');eq(plain(w.rows[1].missing.text),'2')
 assert(plain(w.rows[1].where.text):find('1 of 1 samples',1,true))   -- the observed source
 eq(w.rows[2].data.itemID,1002);eq(plain(w.rows[2].where.text),'No recorded source')
 eq(w.rows[3].data.state,'ready');eq(plain(w.rows[3].where.text),'Ready');eq(w.rows[3].missing.text,'-')
 assert(w.rows[1].name.text:find(ns.Style.red,1,true));assert(w.rows[3].name.text:find(ns.Style.green,1,true))
 eq(w.rows[7].data.itemID,1007);eq(w.rows[8]:IsShown(),false)
 assert(plain(w.summary.text):find('You can craft 1 of 3 planned.',1,true))
 assert(plain(w.counts.text):find('Missing 2',1,true));assert(plain(w.counts.text):find('In bank 0',1,true))
 assert(plain(w.counts.text):find('Ready 5',1,true))
 assert(w.summary.text:find(ns.Style.yellow,1,true))
 eq(ns.history:Total('a',1001),1)
end)
test('sorting keeps problems first and orders by name inside a group',function()
 C_Item={GetItemInfo=function(id)return({[1]='Zeta',[2]='Alpha'})[id]end}
 local rows={{itemID=3,state='ready'},{itemID=1,state='ready'},{itemID=2,state='ready'},{itemID=4,state='missing'},
  {itemID=5,state='bank'},{itemID=6,state='unknown'}}
 local sorted=ns.CraftingView.Sorted(rows)
 local ids={};for _,row in ipairs(sorted)do ids[#ids+1]=row.itemID end
 eq(table.concat(ids,','),'4,6,5,2,1,3')   -- missing, unknown, bank, then ready: Alpha, Zeta, the unnamed one last
 C_Item=nil
end)
test('planner error states hide stale rows and clear the lines',function()
 local w=ns.CraftingView.window
 ns.CraftingView.Show(999,1);assert(w.summary.text:find('unavailable',1,true));eq(w.rows[1]:IsShown(),false);eq(w.counts.text,'')
 ns.CraftingView.Show(2536,3);eq(w.offset,0);eq(w.rows[1]:IsShown(),true)
end)
test('plus, minus and the number box change the planned crafts',function()
 local w=ns.CraftingView.window
 local function find(label)for _,b in ipairs(w.buttons)do if b.text==label then return b end end end
 local plus,minus=find('+'),find('-')
 ns.CraftingView.Show(2536,3)
 plus.scripts.OnClick();eq(w.operations,4);eq(w.operationsBox.text,'4')
 minus.scripts.OnClick();minus.scripts.OnClick();eq(w.operations,2)
 minus.scripts.OnClick();minus.scripts.OnClick();eq(w.operations,1)       -- never below one
 IsShiftKeyDown=function()return true end
 plus.scripts.OnClick();eq(w.operations,6)                                  -- shift adds five
 IsShiftKeyDown=nil
 w.operationsBox.text='25';w.operationsBox.scripts.OnEnterPressed(w.operationsBox);eq(w.operations,25)
 w.operationsBox.text='';w.operationsBox.scripts.OnEnterPressed(w.operationsBox);eq(w.operations,25) -- nothing typed: unchanged
 w.operationsBox.text='99999999';w.operationsBox.scripts.OnEnterPressed(w.operationsBox);eq(w.operations,1000000)
 ns.CraftingView.Show(2536,3)
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
test('with the bank counted, reagents that are only in the bank turn yellow and say how many to take',function()
 ns.settings.showBank=true;ns.CraftingView.Show(2536,3);local w=ns.CraftingView.window
 eq(w.rows[1].data.state,'bank');eq(w.rows[1].data.fromBank,2);eq(w.rows[1].bank.text,'10')
 eq(plain(w.rows[1].where.text),'In the bank: take 2');assert(w.rows[1].where.text:find(ns.Style.yellow,1,true))
 assert(plain(w.summary.text):find('Enough for 3 crafts, but 2 reagents are in the bank.',1,true))
 assert(plain(w.counts.text):find('In bank 2',1,true));assert(plain(w.counts.text):find('Missing 0',1,true))
 assert(w.note.text:find('Material limit: 11 crafts (cached estimate)',1,true));assert(w.scope.text:find('Bags + Bank',1,true))
 assert(w.note.text:find('Bank observed',1,true));assert(w.note.text:find('100',1,true))
 ns.settings.showBank=false
end)
test('a merchant seen selling a reagent is named in the last column and in the source menu',function()
 assert(loadfile('TitanGatheredForeverV3/NpcSources.lua'))('TGF v3',ns)
 ns.db={npcs={[50]={name='Vendor Vic',mapID=4,x=.5,y=.5,lastSeen=1,
  goods={{itemID=1001,price=250,stack=5},{itemID=1002,price=100,extendedCost=true}}}}}
 ns.NpcSources.Invalidate()
 ns.CraftingView.Show(2536,3);local w=ns.CraftingView.window
 eq(plain(w.rows[1].where.text),'Buy 50c each: Vendor Vic, Zone 4')       -- 250 copper for a stack of 5
 eq(plain(w.rows[2].where.text),'Buy special cost: Vendor Vic, Zone 4')   -- paid with something other than money
 local row=w.rows[1];row.scripts.OnClick(row)
 local combined=table.concat(menu.titles,' ');assert(combined:find('Sold by',1,true))
 local callback=menu.buttons['Vendor Vic: 50c each, Zone 4'];assert(callback)
 local opened;OpenWorldMap=function(id)opened=id end;GetTime=function()return 100 end
 callback();eq(opened,4);eq(ns.NpcSources.IsHighlighted(50),true)
 ns.NpcSources.SetHighlight(nil);OpenWorldMap=nil;ns.db=nil
 ns.CraftingView.Show(2536,3)
end)
test('map history label cannot imply a probability at one pin',function()
 assert(loadfile('TitanGatheredForeverV3/PinStyle.lua'))('TGF v3',ns)
 local _,note=ns.PinStyle.HistoryLines({itemID=1001,mapID=4,kind='Mining'})
 assert(note and note:find('not a chance at this coordinate',1,true))
end)
print('PASS '..passed..' crafting planner window checks')
