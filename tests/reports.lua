local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,f)local ok,e=pcall(f);if not ok then error(n..': '..e)end;passed=passed+1 end
local function region()return{SetPoint=function()end,SetWidth=function()end,SetJustifyH=function()end,SetText=function(self,v)self.text=v end}end
local function frame()
 local f={scripts={},shown=false,TitleText=region()}
 for _,m in ipairs({'SetSize','SetPoint','SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing'})do f[m]=function()end end
 function f:SetScript(k,fn)self.scripts[k]=fn end
 function f:SetText(v)self.text=v end
 function f:CreateFontString()return region()end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 return f
end
CreateFrame=function()return frame()end;UIParent=frame();UISpecialFrames={};UnitGUID=function()return'a'end
C_Map={GetMapInfo=function(id)return{name='Zone '..id}end};GameTooltip={SetOwner=function()end,SetItemByID=function(self,id)self.item=id end,Show=function()end,Hide=function()end}
local ns={ItemName=function(id)return'Item '..id end,Style={ItemName=function(id)return'Item '..id end},Catalog={modules={Cooking={label='Cooking',items={[769]=true}}}}}
ns.Catalog.Modules=function()return{{id='Cooking',label='Cooking'}}end
assert(loadfile('TitanGatheredForeverV3/History.lua'))('TGF v3',ns);assert(loadfile('TitanGatheredForeverV3/Reports.lua'))('TGF v3',ns)
ns.history=ns.History.New({})
local function seed(char,id,item,qty)
 ns.history:Observe(char,char,{id=id,kind='Loot',source='123',mapID=1,x=.4,y=.6,at=100,complete=true,items={[item]=qty}})
end
seed('a','one',769,2);seed('b','two',769,3)
test('two independent windows show current character and combined values',function()
 ns.Reports.Show('history');ns.Reports.Show('chances')
 local h,c=ns.Reports.windows.history,ns.Reports.windows.chances
 assert(h~=c and h:IsShown()and c:IsShown());assert(h.rows[1].detail.text:find('2 obtained',1,true))
 h.scope.scripts.OnClick();assert(h.rows[1].detail.text:find('5 obtained',1,true));eq(c.combined,nil)
 assert(c.rows[1].detail.text:find('100.0% (1 / 1 samples)',1,true));eq(#UISpecialFrames,2)
end)
test('report rows filter by consuming profession and source kind',function()
 eq(#ns.Reports.Rows('history','a','Cooking'),1);eq(#ns.Reports.Rows('chances','a','Cooking'),1)
 eq(#ns.Reports.Rows('history','a','Mining'),0)
end)
test('paging bounds and empty views do not display stale rows',function()
 local h=ns.Reports.windows.history;h.page=99;ns.Reports.Update(h);eq(h.page,1)
 h.filter='Mining';ns.Reports.Update(h);eq(h.rows[1]:IsShown(),false);assert(h.empty.text~='')
 h.filter=nil;ns.Reports.Update(h);eq(h.rows[1]:IsShown(),true)
end)
test('report item hovers use native item tooltip',function()
 local row=ns.Reports.windows.history.rows[1];row.scripts.OnEnter(row);eq(GameTooltip.item,769)
end)
test('history profession filters include observed uncatalogued outputs',function()
 ns.history:Observe('a','Alice',{id='fish',kind='Fishing',source='catch',mapID=1,at=101,complete=true,items={[6291]=1}})
 local rows=ns.Reports.Rows('history','a','Fishing');eq(#rows,1);eq(rows[1].itemID,6291)
end)
test('actions report shows coverage and counts without item interactions',function()
 assert(loadfile('TitanGatheredForeverV3/Actions.lua'))('TGF v3',ns)
 local character='a'
 ns.actions=ns.Actions.New({}, {Character=function()return character end,Name=function()return character end,
  Timestamp=function()return 100 end,Now=function()return 100 end,Enabled=function()return true end})
 ns.actions:Cast('UNIT_SPELLCAST_SUCCEEDED','player','one',13262)
 character='b';ns.actions:Cast('UNIT_SPELLCAST_FAILED','player','two',13262)
 ns.Reports.Show('actions');local w=ns.Reports.windows.actions;assert(w and w:IsShown())
 assert(w.rows[1].name.text:find('Disenchanting',1,true));assert(w.rows[1].detail.text:find('1 attempts',1,true))
 assert(w.rows[1].detail.text:find('1 completed',1,true));assert(w.rows[1].detail.text:find('Recording began',1,true))
 GameTooltip.item=nil;w.rows[1].scripts.OnEnter(w.rows[1]);eq(GameTooltip.item,nil)
 w.scope.scripts.OnClick();assert(w.rows[1].detail.text:find('2 attempts',1,true))
 assert(w.rows[1].detail.text:find('1 failed',1,true))
 w.filter='Cooking';ns.Reports.Update(w);eq(w.rows[1]:IsShown(),false)
end)
test('production report distinguishes completions matched results and explicit flag denominators',function()
 assert(loadfile('TitanGatheredForeverV3/Production.lua'))('TGF v3',ns)
 ns.production=ns.Production.New({}, {Character=function()return'a'end,Name=function()return'A'end,
  Timestamp=function()return 100 end,Now=function()return 100 end,Enabled=function()return true end,Public=function()return true end,
  Recipe=function(id)return{recipeID=id,name='Cook '..id,kind='Cooking',outputItemID=2680,outputIDs={[2680]=true}}end})
 for i=1,6 do
  ns.production:Cast('UNIT_SPELLCAST_START','player','c'..i,2500+i)
  ns.production:Cast('UNIT_SPELLCAST_SUCCEEDED','player','c'..i,2500+i)
  ns.production:Result({operationID=i,itemID=2680,itemGUID='Item-output',quantity=2,firstCraftReward=false,isEnchant=false,bonusCraft=false,multicraft=0})
 end
 ns.Reports.Show('production');local w=ns.Reports.windows.production;assert(w and w:IsShown());eq(#w.rows,5)
 assert(w.rows[1].name.text:find('Cook 2501',1,true));assert(w.rows[1].detail.text:find('1 completed',1,true))
 assert(w.rows[1].detail.text:find('1 matched',1,true));assert(w.rows[1].detail.text:find('0 / 1',1,true))
 w.page=2;ns.Reports.Update(w);assert(w.rows[1].name.text:find('Cook 2506',1,true));eq(w.rows[2]:IsShown(),false)
 local titles={};MenuUtil={CreateContextMenu=function(_,fn)
  local menu={CreateTitle=function(_,v)titles[#titles+1]=v end,SetScrollMode=function()end};fn({},menu)
 end}
 w.rows[1].scripts.OnClick(w.rows[1]);local found=false
 for _,v in ipairs(titles)do if v:find('2 items in 1 operations',1,true)then found=true end end;assert(found)
 local rows=ns.Reports.Rows('history','a','Cooking');local output
 for _,r in ipairs(rows)do if r.itemID==2680 then output=r end end
 assert(output);eq(output.quantity,0);eq(output.crafted,12)
end)
print('PASS '..passed..' history/report window checks')
