local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,f)local ok,e=pcall(f);if not ok then error(n..': '..e)end;passed=passed+1 end
local function region()
 local r={}
 function r:SetPoint(...)self.point={...}end
 function r:SetWidth(v)self.width=v end
 function r:SetHeight(v)self.height=v end
 function r:SetJustifyH()end
 function r:SetText(v)self.text=tostring(v)end
 function r:GetStringHeight()
  local height=0
  for line in ((self.text or '')..'\n'):gmatch('(.-)\n')do
   height=height+math.max(1,math.ceil(#line/math.max(1,math.floor((self.width or 100)/6))))*12
  end
  return height
 end
 return r
end
local function frame()
 local f={scripts={},shown=false,TitleText=region()}
 for _,m in ipairs({'SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing'})do f[m]=function()end end
 function f:SetSize(w,h)self.width,self.height=w,h end
 function f:SetHeight(h)self.height=h end
 function f:ClearAllPoints()self.point=nil end
 function f:SetPoint(...)self.point={...}end
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
ns.Production={labels={Tailoring='Tailoring',FirstAid='First Aid'}}
ns.Catalog.Modules=function()return{{id='Cooking',label='Cooking'}}end
assert(loadfile('TitanGatheredForeverV3/History.lua'))('TGF v3',ns);assert(loadfile('TitanGatheredForeverV3/Reports.lua'))('TGF v3',ns)
ns.history=ns.History.New({})
local function seed(char,id,item,qty)
 ns.history:Observe(char,char,{id=id,kind='Loot',source='123',mapID=1,x=.4,y=.6,at=100,complete=true,items={[item]=qty}})
end
seed('a','one',769,2);seed('b','two',769,3)
test('switching reports hides previous content and preserves independent scope and filters',function()
 ns.Reports.Show('history');ns.Reports.Show('chances')
 local h,c=ns.Reports.windows.history,ns.Reports.windows.chances
 assert(h~=c and not h:IsShown()and c:IsShown())
 ns.Reports.Show('history');assert(h:IsShown()and not c:IsShown())
 eq(_G.height,nil)
 eq(h.rows[1].cells[2].text,'2')
 h.scope.scripts.OnClick();eq(h.rows[1].cells[2].text,'5');eq(h.rows[1].cells[3].text,'Zone 1 (40.0, 60.0)');eq(c.combined,nil)
 h.filter='Cooking';ns.Reports.Update(h)
 ns.Reports.Show('chances');eq(c.rows[1].cells[2].text,'100.0%');eq(c.rows[1].cells[3].text,'1 / 1')
 ns.Reports.Show('history');eq(h.filter,'Cooking');eq(h.combined,true);eq(h.rows[1].cells[2].text,'5')
 h.filter=nil;h.scope.scripts.OnClick();eq(#UISpecialFrames,2)
end)
test('lifetime values use a total column and loot/gather coordinates at the right of the row',function()
 local w=ns.Reports.windows.history
 eq(w.headers[2].text,'Lifetime obtained');eq(w.headers[3].text,'Last loot or gather');eq(w.headers[4],nil)
 local r=w.rows[1]
 eq(r.cells[1].text,'Item 769');eq(r.cells[2].text,'2')
 eq(r.cells[3].text,'Zone 1 (40.0, 60.0)')
 assert(r.cells[3].point[4]>300);assert(r.height<37)
end)
test('global reagent report shows leading profession share and opens full breakdown',function()
 local previous=ns.production
 local selected
 ns.production={ReagentUsage=function(_,character)
  selected=character
  return {{itemID=159,quantity=100,leading='Tailoring',share=75,professions={Tailoring=75,FirstAid=25}}},
      {coverageBegan=100,unsupportedCasts=2}
 end,Rows=function()return{}end,Totals=function()return{}end}
 ns.Reports.Show('reagentUsage');local w=ns.Reports.windows.reagentUsage
 assert(w:IsShown()and not ns.Reports.windows.history:IsShown())
 eq(w.rows[1].cells[1].text,'Item 159');eq(w.rows[1].cells[2].text,'100')
 eq(w.rows[1].cells[3].text,'Tailoring');eq(w.rows[1].cells[4].text,'75.0%')
 assert(w.note.text:find('Coverage since 100',1,true));assert(w.note.text:find('2 completed recipes',1,true))
 w.scope.scripts.OnClick();eq(selected,nil);eq(w.scope.text,'All characters')
 local previousMenu=MenuUtil;local titles={};MenuUtil={CreateContextMenu=function(_,fn)
  fn({}, {CreateTitle=function(_,value)titles[#titles+1]=value end,SetScrollMode=function()end})
 end}
 w.rows[1].scripts.OnClick(w.rows[1])
 local found=false;for _,title in ipairs(titles)do if title:find('Tailoring: 75 (75.0%)',1,true)then found=true end end;assert(found)
 MenuUtil=previousMenu;ns.Reports.Update(w);ns.production=previous
end)
test('lifetime obtained quantity includes the item crafted output total',function()
 ns.production={Totals=function()return{{itemID=769,quantity=12},{itemID=2680,quantity=7}}end}
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 eq(w.headers[2].text,'Lifetime obtained')
 eq(w.headers[3].text,'Last loot or gather');eq(w.headers[4],nil)
 local rows={};for _,row in ipairs(w.rows)do if row.data then rows[row.data.itemID]=row end end
 eq(rows[769].cells[2].text,'14')
 eq(rows[2680].cells[2].text,'7')
 ns.production=nil;ns.Reports.Update(w)
end)
test('lifetime list shows quantities without an extra source occurrence counter',function()
 local previous=ns.history
 ns.history=ns.History.New({characters={a={name='A',items={[769]={quantity=8},[770]={quantity=3}},recent={},order={},
  groups={old={kind='Loot',source='123',mapID=1,trials=1,items={[769]={hits=1,quantity=2}}}}}}})
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 eq(w.rows[1].cells[2].text,'8');eq(w.rows[2].cells[2].text,'3')
 eq(w.headers[3].text,'Last loot or gather')
 ns.history=previous;ns.Reports.Update(w)
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
 assert(not ns.Reports.windows.history:IsShown()and not ns.Reports.windows.chances:IsShown())
 local cells=w.rows[1].cells
 eq(cells[1].text,'Disenchanting');eq(cells[2].text,'1');eq(cells[3].text,'1')
 eq(cells[4].text,'0');eq(cells[5].text,'0');eq(cells[6].text,'0');eq(cells[7].text,'0')
 assert(cells[8].text~='');assert(w.note.text:find('gaps',1,true))
 GameTooltip.item=nil;w.rows[1].scripts.OnEnter(w.rows[1]);eq(GameTooltip.item,nil)
 w.scope.scripts.OnClick();eq(cells[2].text,'2');eq(cells[4].text,'1')
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
 assert(not ns.Reports.windows.actions:IsShown())
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
test('crafted-only lifetime rows show the total without inventing a loot location',function()
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 local found
 for _,r in ipairs(w.rows)do if r.data and r.data.itemID==2680 then found=r end end
 assert(found);eq(found.cells[2].text,'12')
 eq(found.cells[3].text,'No loot or gather location')
end)
test('wrapped report rows paginate without overlap lost entries or resetting another report page',function()
 local original=ns.Reports.Rows
 local originalName=ns.Style.ItemName
 ns.Style.ItemName=function(id)return id==1 and string.rep('Long material name ',15)or originalName(id)end
 local rows={}
 for i=1,35 do rows[i]={itemID=i,quantity=i,percent=25,hits=1,trials=4,kind='Loot',source='123',
  sourceName=string.rep('Long creature name ',i==1 and 15 or 3),mapID=1}end
 ns.Reports.Rows=function(mode,...)if mode=='chances'then return rows end;return original(mode,...)end
 ns.Reports.Show('chances');local w=ns.Reports.windows.chances
 assert(w.rows[1].height>22)
 local total=tonumber(w.pageText.text:match('/ (%d+)'));assert(total>1)
 local seen={};local count=0
 for page=1,total do
  w.page=page;ns.Reports.Update(w)
  local bottom=0
  for _,r in ipairs(w.rows)do if r:IsShown()then
   local top=-r.point[5]
   assert(top>=bottom);bottom=top+r.height;assert(bottom<=510)
   assert(not seen[r.data.itemID]);seen[r.data.itemID]=true;count=count+1
   eq(r.cells[2].text,'25.0%');eq(r.cells[3].text,'1 / 4');eq(r.cells[4].text,tostring(r.data.quantity))
  end end
 end
 eq(count,35)
 ns.Reports.Show('history');assert(not w:IsShown())
 ns.Reports.Show('chances');eq(w.page,total)
 w.page=999;ns.Reports.Update(w);eq(w.page,total)
 w.page=-1;ns.Reports.Update(w);eq(w.page,1)
 rows[1].sourceName=string.rep('Very long source ',500)
 ns.Reports.Update(w);assert(w.rows[1].height<=378)
 rows={};ns.Reports.Update(w);eq(w.page,1);eq(w.rows[1]:IsShown(),false);assert(w.empty.text~='')
 ns.Reports.Rows=original
 ns.Style.ItemName=originalName
end)
print('PASS '..passed..' history/report window checks')
