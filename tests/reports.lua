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
 function r:SetWordWrap()end
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
 for _,m in ipairs({'SetClampedToScreen','SetMovable','EnableMouse','RegisterForDrag','StartMoving','StopMovingOrSizing','SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetThumbTexture','EnableMouseWheel','SetColorTexture','SetAllPoints','SetAutoFocus','ClearFocus'})do f[m]=function()end end
 function f:SetSize(w,h)self.width,self.height=w,h end
 function f:SetHeight(h)self.height=h end
 function f:ClearAllPoints()self.point=nil end
 function f:SetPoint(...)self.point={...}end
 function f:SetScript(k,fn)self.scripts[k]=fn end
 function f:SetText(v)self.text=v end
 function f:CreateFontString()return region()end
 function f:CreateTexture()local t={shown=true};for _,m in ipairs({'SetAllPoints','SetPoint','SetColorTexture','SetHeight'})do t[m]=function()end end;function t:Show()self.shown=true end;function t:Hide()self.shown=false end;return t end
 function f:GetThumbTexture()return{SetSize=function()end}end
 function f:SetValue(v)self.value=v end
 function f:GetText()return self.text or ''end
 function f:Show()self.shown=true end
 function f:Hide()self.shown=false end
 function f:IsShown()return self.shown end
 return f
end
CreateFrame=function()return frame()end;UIParent=frame();UISpecialFrames={};UnitGUID=function()return'a'end
C_Map={GetMapInfo=function(id)return{name='Zone '..id}end};GameTooltip={SetOwner=function()end,SetItemByID=function(self,id)self.item=id end,Show=function()end,Hide=function()end}
local function pick(control,label)
 local previous=MenuUtil;local actions={}
 MenuUtil={CreateContextMenu=function(owner,fn)fn(owner,{CreateButton=function(_,l,cb)actions[l]=cb end})end}
 control.scripts.OnClick(control);MenuUtil=previous;actions[label]()
end
local ns={ItemName=function(id)return'Item '..id end,Style={ItemName=function(id)return'Item '..id end},Catalog={modules={Cooking={label='Cooking',items={[769]=true}}}}}
ns.Style.MenuNote=function(root,value)return root:CreateTitle(value)end
dofile('tests/style_stub.lua')(ns.Style)
ns.Production={labels={Tailoring='Tailoring',FirstAid='First Aid'}}
ns.Catalog.Modules=function()return{{id='Cooking',label='Cooking'}}end
assert(loadfile('TitanGatheredForever/History.lua'))('Titan Gathered Forever',ns);assert(loadfile('TitanGatheredForever/Navigation.lua'))('Titan Gathered Forever',ns);assert(loadfile('TitanGatheredForever/ColumnSort.lua'))('Titan Gathered Forever',ns);ns.settings={};assert(loadfile('TitanGatheredForever/Reports.lua'))('Titan Gathered Forever',ns)
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
 pick(h.scope,'All characters');eq(h.rows[1].cells[2].text,'5');eq(h.rows[1].cells[3].text,'1 source');eq(c.combined,nil)
 h.filter='Cooking';ns.Reports.Update(h)
 ns.Reports.Show('chances');eq(c.rows[1].cells[2].text,'100.0%');eq(c.rows[1].cells[3].text,'1 / 1')
 ns.Reports.Show('history');eq(h.filter,'Cooking');eq(h.combined,true);eq(h.rows[1].cells[2].text,'5')
 h.filter=nil;pick(h.scope,'This character');eq(#UISpecialFrames,2)
end)
test('lifetime values replace the last location with observed source chances',function()
 local w=ns.Reports.windows.history
 eq(w.headers[2].text,'Lifetime obtained');eq(w.headers[3].text,'Observed source');eq(w.headers[4].text,'Chance');eq(w.headers[5].text,'Hits / samples')
 local r=w.rows[1]
 eq(r.cells[1].text,'Item 769');eq(r.cells[2].text,'2')
 eq(r.cells[3].text,'1 source')
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
 assert(w.note.text:find('Coverage since '..ns.Style.Date('100'),1,true));assert(w.note.text:find('2 completed recipes',1,true))
 pick(w.scope,'All characters');eq(selected,nil);eq(w.scope.text,'All characters')
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
 eq(w.headers[3].text,'Observed source');eq(w.headers[4].text,'Chance');eq(w.headers[5].text,'Hits / samples')
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
 eq(w.headers[3].text,'Observed source')
 ns.history=previous;ns.Reports.Update(w)
end)
test('report rows filter by consuming profession and source kind',function()
 eq(#ns.Reports.Rows('history','a','Cooking'),1);eq(#ns.Reports.Rows('chances','a','Cooking'),1)
 eq(#ns.Reports.Rows('history','a','Mining'),0)
end)
test('paging bounds and empty views do not display stale rows',function()
 local h=ns.Reports.windows.history;h.offset=99;ns.Reports.Update(h);eq(h.offset,0)
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
 assert(loadfile('TitanGatheredForever/Actions.lua'))('Titan Gathered Forever',ns)
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
 pick(w.scope,'All characters');eq(cells[2].text,'2');eq(cells[4].text,'1')
 w.filter='Cooking';ns.Reports.Update(w);eq(w.rows[1]:IsShown(),false)
end)
test('the actions window can show what was gathered and what it is worth',function()
 ns.Economy={Coin=function(copper)return copper..'c'end}
 ns.Yields={Available=function()return ns.available or{'Mining','Fishing'}end,Rows=function(character,filter,sort)
  ns.Yields.last={filter=filter,sort=sort}
  return{{summary=true,title=true,kind='Mining',text='Mining',gold=true},{summary=true,kind='Mining',text='Mining: 5 completed, 12 items collected, worth 90c'},
   {summary=true,kind='Mining',text='Active time 10 min'},
   {itemID=769,kind='Mining',quantity=10,share=83.3,unit=5,value=50,source='vendor'},
   {itemID=770,kind='Mining',quantity=2,share=16.7,unit=nil,value=nil}}
 end}
 ns.Reports.Show('actions');local w=ns.Reports.windows.actions
 pick(w.group,'Gathered, most valuable')
 eq(ns.Yields.last.sort,'value');eq(w.headers[1].text,'Item');eq(w.headers[5].text,'Total value');eq(w.headers[7].text,'')
 eq(w.rows[1].cells[1].text,ns.Style.Text(ns.Style.gold,'Mining'));assert(w.rows[2].cells[1].text:find('Mining: 5 completed',1,true));eq(w.rows[2].cells[2].text,'')
 eq(w.rows[4].cells[2].text,'10');eq(w.rows[4].cells[3].text,'83.3%');eq(w.rows[4].cells[4].text,'5c');eq(w.rows[4].cells[5].text,'50c');eq(w.rows[4].cells[6].text,'vendor')
 eq(w.rows[5].cells[4].text,'No price');eq(w.rows[5].cells[5].text,'Unknown')
 assert(w.note.text:find('valued at',1,true))
 eq(w.filter,'Mining')                                        -- the first available profession, never a combined entry
 w.filter='Fishing';ns.Reports.Update(w);eq(ns.Yields.last.filter,'Fishing')
 w.filter='Herbs';ns.Reports.Update(w);eq(w.filter,'Mining')       -- a profession that is gone falls back to the first one
 ns.available={};ns.Reports.Update(w);eq(w.filter,nil);eq(w.rows[1]:IsShown(),false)
 assert(w.empty.text:find('No gathering profession',1,true));ns.available=nil;ns.Reports.Update(w);eq(w.filter,'Mining')
 w.filter=nil;pick(w.group,'Actions summary');eq(w.headers[1].text,'Profession');eq(w.headers[8].text,'Recording began');assert(w.note.text:find('gaps',1,true))
 w.filter=nil;ns.Economy,ns.Yields=nil,nil
end)
test('production report distinguishes completions matched results and explicit flag denominators',function()
 assert(loadfile('TitanGatheredForever/Production.lua'))('Titan Gathered Forever',ns)
 ns.production=ns.Production.New({}, {Character=function()return'a'end,Name=function()return'A'end,
  Timestamp=function()return 100 end,Now=function()return 100 end,Enabled=function()return true end,Public=function()return true end,
  Recipe=function(id)return{recipeID=id,name='Cook '..id,kind='Cooking',outputItemID=2680,outputIDs={[2680]=true}}end})
 for i=1,6 do
  ns.production:Cast('UNIT_SPELLCAST_START','player','c'..i,2500+i)
  ns.production:Cast('UNIT_SPELLCAST_SUCCEEDED','player','c'..i,2500+i)
  ns.production:Result({operationID=i,itemID=2680,itemGUID='Item-output',quantity=2,firstCraftReward=false,isEnchant=false,bonusCraft=false,multicraft=0})
 end
 ns.Reports.Show('production');local w=ns.Reports.windows.production;assert(w and w:IsShown());eq(#w.rows,18)
 assert(w.rows[1].name.text:find('Cook 2501',1,true));eq(w.rows[1].cells[2].text,'1');eq(w.rows[1].cells[3].text,'1')
 eq(w.rows[1].cells[4].text,'100.0%');eq(w.rows[1].cells[5].text,'1')
 eq(w.rows[1].cells[6].text,'2');eq(w.rows[1].cells[7].text,'0.0% (0/1)')
 eq(w.rows[1].cells[8].text,'0.0% (0/1)');assert(w.rows[6]:IsShown());assert(w.rows[1].height<37)
 local titles={};MenuUtil={CreateContextMenu=function(_,fn)
  local menu={CreateTitle=function(_,v)titles[#titles+1]=v end,SetScrollMode=function()end};fn({},menu)
 end}
 w.rows[1].scripts.OnClick(w.rows[1]);local found=false
 local distribution=ns.Style.Value(2)..ns.Style.Label(' items in ')..ns.Style.Value(1)..ns.Style.Label(' operations')
 for _,v in ipairs(titles)do if v==distribution then found=true end end;assert(found)
 local rows=ns.Reports.Rows('history','a','Cooking');local output
 for _,r in ipairs(rows)do if r.itemID==2680 then output=r end end
 assert(output);eq(output.quantity,0);eq(output.crafted,12)
end)
test('crafted-only lifetime rows show the total without inventing a loot location',function()
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 local found
 for _,r in ipairs(w.rows)do if r.data and r.data.itemID==2680 then found=r end end
 assert(found);eq(found.cells[2].text,'12')
 eq(found.cells[3].text,'Unknown')
end)
test('wrapped report rows scroll without overlap lost entries or resetting another report scroll position',function()
 local original=ns.Reports.Rows
 local originalName=ns.Style.ItemName
 ns.Style.ItemName=function(id)return id==1 and string.rep('Long material name ',15)or originalName(id)end
 local rows={}
 for i=1,35 do rows[i]={itemID=i,quantity=i,percent=25,hits=1,trials=4,kind='Loot',source='123',
  sourceName=string.rep('Long creature name ',i==1 and 15 or 3),mapID=1}end
 ns.Reports.Rows=function(mode,...)if mode=='chances'then return rows end;return original(mode,...)end
 ns.Reports.Show('chances');local w=ns.Reports.windows.chances
 assert(w.rows[1].height>22);assert(w.rangeText.text:find('35',1,true))
 local seen={};local last=0
 local offset=0
 repeat
  ns.Reports.ScrollTo(w,offset)
  local bottom=0
  for _,r in ipairs(w.rows)do if r:IsShown()then
   local top=-r.point[5]
   assert(top>=bottom);bottom=top+r.height;assert(bottom<=510)
   seen[r.data.itemID]=true;last=r.data.itemID
   eq(r.cells[2].text,'25.0%');eq(r.cells[3].text,'1 / 4');eq(r.cells[4].text,tostring(r.data.quantity))
  end end
  offset=offset+3
 until offset>40
 eq(last,35);local count=0;for _ in pairs(seen)do count=count+1 end;eq(count,35)
 w.offset=7;ns.Reports.Show('history');assert(not w:IsShown())
 ns.Reports.Show('chances');eq(w.offset,7)
 ns.Reports.Scroll(w,-100);eq(w.offset,0)
 ns.Reports.Scroll(w,1000);assert(w.offset>0 and w.offset<35);eq(w.slider.value,w.offset)
 ns.Reports.ScrollTo(w,0)
 rows[1].sourceName=string.rep('Very long source ',500)
 ns.Reports.Update(w);assert(w.rows[1].height<=378)
 rows={};ns.Reports.Update(w);eq(w.offset,0);eq(w.rows[1]:IsShown(),false);assert(w.empty.text~='');eq(w.rangeText.text,'No entries')
 ns.Reports.Rows=original
 ns.Style.ItemName=originalName
end)
test('search keeps matching names and clearing it restores the list',function()
 local original=ns.Reports.Rows
 local rows={}
 for i=1,5 do rows[i]={itemID=i,quantity=i,percent=25,hits=1,trials=4,kind='Loot',source='123',sourceName='W',mapID=1}end
 ns.Reports.Rows=function(mode,...)if mode=='chances'then return rows end;return original(mode,...)end
 ns.Reports.Show('chances');local w=ns.Reports.windows.chances
 w.search.scripts.OnTextChanged({GetText=function()return 'item 3'end},true)
 eq(w.rows[1].data.itemID,3);eq(w.rows[2]:IsShown(),false);assert(w.rangeText.text:find(ns.Style.Value(1),1,true))
 w.search.scripts.OnTextChanged({GetText=function()return 'nothing'end},true)
 eq(w.rows[1]:IsShown(),false);eq(w.empty.text,'Nothing matches this search.')
 w.search.scripts.OnTextChanged({GetText=function()return ''end},true)
 assert(w.rows[5]:IsShown());eq(w.empty.text,'')
 ns.Reports.Rows=original
end)
test('a click on a column header sorts the chances, grouped or not, and a second click reverses it',function()
 local original=ns.Reports.Rows
 local rows={
  {itemID=7,quantity=2,percent=50,hits=1,trials=2,kind='Mining',source='1',mapID=1},
  {itemID=8,quantity=9,percent=10,hits=1,trials=10,kind='Loot',source='3',sourceName='Bear',mapID=1},
  {itemID=9,quantity=4,percent=75,hits=3,trials=4,kind='Loot',source='4',sourceName='Wolf',mapID=1}}
 ns.Reports.Rows=function(mode,...)if mode=='chances'then return rows end;return original(mode,...)end
 ns.Reports.Show('chances');local w=ns.Reports.windows.chances
 assert(w.sorter,'the header is sortable')
 eq(w.rows[1].data.itemID,7)                                       -- before a click: the order of the data
 w.sorter.buttons[4].scripts.OnClick()                             -- Items, a number: the most first
 eq(w.rows[1].data.itemID,8);eq(w.rows[2].data.itemID,9);eq(w.rows[3].data.itemID,7)
 w.sorter.buttons[4].scripts.OnClick()
 eq(w.rows[1].data.itemID,7);eq(w.rows[3].data.itemID,8)
 w.sorter.buttons[2].scripts.OnClick()                             -- Observed percent: the highest first
 eq(w.rows[1].data.itemID,9);eq(w.rows[2].data.itemID,7);eq(w.rows[3].data.itemID,8)
 w.sorter.buttons[1].scripts.OnClick()                             -- Material, a text: a to z
 eq(w.rows[1].data.itemID,7);eq(w.rows[3].data.itemID,9)
 pick(w.group,'Grouped by item')                                   -- the order holds when the list is grouped
 eq(w.rows[1].data.itemID,7);eq(w.rows[3].data.itemID,9)
 w.sorter.buttons[1].scripts.OnClick()
 eq(w.rows[1].data.itemID,9);eq(w.rows[3].data.itemID,7)
 eq(ns.settings.columnSort.reports_chances.column,1);eq(ns.settings.columnSort.reports_chances.descending,true)
 pick(w.group,'All sources');w.sorter.state=nil;w.sorter.Sync();ns.settings.columnSort={};ns.Reports.Update(w)
 ns.Reports.Rows=original
end)
test('the lifetime and reagent use lists sort by their columns',function()
 local previous=ns.production
 ns.production={ReagentUsage=function()
  return {{itemID=159,quantity=100,leading='Tailoring',share=75,professions={Tailoring=75,FirstAid=25}},
          {itemID=160,quantity=30,leading='FirstAid',share=90,professions={FirstAid=30}}},{coverageBegan=100,unsupportedCasts=0}
 end,Rows=function()return{}end,Totals=function()return{}end}
 ns.Reports.Show('reagentUsage');local w=ns.Reports.windows.reagentUsage
 assert(w.sorter,'the header is sortable')
 eq(w.rows[1].data.itemID,159)
 w.sorter.buttons[4].scripts.OnClick()                             -- Share of tracked use: the highest first
 eq(w.rows[1].data.itemID,160);eq(w.rows[2].data.itemID,159)
 w.sorter.buttons[3].scripts.OnClick()                             -- Leading profession, a text: a to z (First Aid, Tailoring)
 eq(w.rows[1].data.itemID,160)
 w.sorter.state=nil;w.sorter.Sync();ns.settings.columnSort={};ns.Reports.Update(w);ns.production=previous
 ns.Reports.Show('history');local h=ns.Reports.windows.history
 assert(h.sorter,'the lifetime header is sortable');eq(h.sorter.buttons[4].scripts.OnClick,nil)   -- Chance and Hits/samples hold no value of a parent row
end)
test('chances can be grouped by item with expandable sources',function()
 local original=ns.Reports.Rows
 local rows={
  {itemID=7,quantity=2,percent=50,hits=1,trials=2,kind='Mining',source='1',mapID=1},
  {itemID=7,quantity=3,percent=100,hits=1,trials=1,kind='Loot',source='2',sourceName='Wolf',mapID=1},
  {itemID=8,quantity=1,percent=10,hits=1,trials=10,kind='Loot',source='3',sourceName='Bear',mapID=1}}
 ns.Reports.Rows=function(mode,...)if mode=='chances'then return rows end;return original(mode,...)end
 ns.Reports.Show('chances');local w=ns.Reports.windows.chances
 eq(w.rows[3]:IsShown(),true);eq(w.group.text,'All sources')
 pick(w.group,'Grouped by item')
 eq(w.group.text,'Grouped by item');eq(w.rows[3]:IsShown(),false)
 eq(w.rows[1].cells[4].text,'5');eq(w.rows[1].cells[5].text,'2 sources');eq(w.rows[2].cells[5].text,'1 source')
 assert(w.rows[1].expand:IsShown())
 w.rows[1].expand.scripts.OnClick(w.rows[1].expand)
 eq(w.rows[2].data.sourceRate.kind,'Mining');eq(w.rows[2].cells[2].text,'50.0%');eq(w.rows[3].cells[3].text,'1 / 1')
 eq(w.rows[4].data.itemID,8);assert(not w.rows[2].expand:IsShown())
 pick(w.group,'All sources');eq(w.rows[3]:IsShown(),true);eq(w.rows[3].cells[1].text,'Item 8')
 ns.Reports.Rows=original
end)
test('every tab window shares the strip position and replaces the others',function()
 ns.Reports.Show('history');local h=ns.Reports.windows.history
 eq(h.width,985);assert(h.tabButtons.pvp and h.tabButtons.recipes and h.tabButtons.chances)
 h.tabButtons.chances.scripts.OnClick();assert(ns.Reports.windows.chances:IsShown()and not h:IsShown());eq(ns.Nav.last,'chances')
 ns.Nav.Toggle();assert(not ns.Reports.windows.chances:IsShown())
 ns.Nav.Toggle();assert(ns.Reports.windows.chances:IsShown())
 h.GetPoint=function()return 'TOPLEFT',UIParent,'TOPLEFT',40,-50 end
 h.scripts.OnDragStop(h);ns.Reports.Show('history');eq(h.point[1],'TOPLEFT');eq(h.point[4],40);eq(h.point[5],-50)
end)
test('PvP Board keeps client totals separate from addon tracked outdoor estimates and deaths',function()
 ns.pvp={Snapshot=function(_,character)
  eq(character,'a')
  return{lifetimeHonorableKills=27,currentRankName='Knight',highestRankID=8,worldKills=3,worldHonorEstimate=60,
   battlegroundKills=4,battlegroundHonorEstimate=100,arenaKills=2,arenaHonorEstimate=50,
   deaths={world=1,battleground=2,arena=1,total=4}}
 end}
 ns.Reports.Show('pvp');local w=ns.Reports.windows.pvp
 assert(w and w:IsShown()and w.TitleText.text=='Titan Gathered Forever PvP Board')
 eq(w.rows[1].cells[1].text,'Client lifetime honorable kills (current character)');eq(w.rows[1].cells[2].text,'27')
 eq(w.rows[2].cells[2].text,'Knight');eq(w.rows[4].cells[2].text,'3');eq(w.rows[5].cells[2].text,'60')
 eq(w.rows[6].cells[2].text,'4');eq(w.rows[8].cells[2].text,'2');eq(w.rows[13].cells[2].text,'4')
 assert(w.note.text:find('cannot be reconstructed',1,true))
 assert(not w.filterButton:IsShown()or w.filterButton.hidden~=false)
 ns.Reports.Show('history');assert(not w:IsShown())
end)
test('source presentation omits internal IDs and keeps readable names',function()
 eq(ns.Reports.Source({kind='Mining',source='656333',mapID=1}),'Mining - Zone 1')
 eq(ns.Reports.Source({kind='Loot',source='123',sourceName='Wolf',mapID=1}),'Loot - Wolf - Zone 1')
end)
test('lifetime chances retain distinct source denominators and zero outcomes',function()
 local previous=ns.history
 ns.history=ns.History.New({})
 ns.history:Observe('a','A',{id='yes',kind='Mining',source='1',mapID=1,at=1,complete=true,items={[769]=4}})
 ns.history:Observe('a','A',{id='no',kind='Mining',source='1',mapID=1,at=2,complete=true,items={}})
 ns.history:Observe('a','A',{id='other',kind='Loot',source='2',mapID=1,at=3,complete=true,items={[769]=1}})
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 eq(w.rows[1].cells[3].text,'2 sources')
 local rates=w.rows[1].data.sources;eq(#rates,2)
 local byKind={};for _,rate in ipairs(rates)do byKind[rate.kind]=rate end
 eq(byKind.Mining.hits,1);eq(byKind.Mining.trials,2)
 eq(byKind.Loot.hits,1);eq(byKind.Loot.trials,1)
 ns.history=previous;ns.Reports.Update(w)
end)
test('lifetime parent rows stay compact and expand independent source evidence',function()
 local previous,production=ns.history,ns.production
 ns.history=ns.History.New({});ns.production=nil
 ns.history:Observe('a','A',{id='yes',kind='Mining',source='1',mapID=1,at=1,complete=true,items={[769]=4}})
 ns.history:Observe('a','A',{id='no',kind='Mining',source='1',mapID=1,at=2,complete=true,items={}})
 ns.history:Observe('a','A',{id='other',kind='Loot',source='2',mapID=1,at=3,complete=true,items={[769]=1}})
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 w.combined=nil;w.filter=nil;w.page=1;w.expanded={};ns.Reports.Update(w)
 local parent=w.rows[1]
 eq(parent.cells[2].text,'5');eq(parent.cells[3].text,'2 sources')
 assert(parent.expand:IsShown());eq(parent.expand.text,'+')
 assert(parent.height<37);eq(w.rows[2]:IsShown(),false)
 parent.expand.scripts.OnClick(parent.expand)
 eq(parent.expand.text,'-');assert(w.rows[2]:IsShown()and w.rows[3]:IsShown())
 local observed={}
 for _,view in ipairs(w.rows)do if view.data and view.data.sourceRate then
  observed[view.data.sourceRate.kind]={view.cells[4].text,view.cells[5].text}
  eq(view.cells[1].text,'');eq(view.cells[2].text,'');assert(not view.expand:IsShown())
 end end
 eq(observed.Mining[1],'50.0%');eq(observed.Mining[2],'1 / 2')
 eq(observed.Loot[1],'100.0%');eq(observed.Loot[2],'1 / 1')
 ns.Reports.Show('chances');ns.Reports.Show('history');assert(w.expanded[769])
 parent.expand.scripts.OnClick(parent.expand);eq(w.rows[2]:IsShown(),false)
 eq(ns.history:Total('a',769),5)
 ns.history,ns.production=previous,production;w.expanded={};ns.Reports.Update(w)
end)
test('expanded history scrolls through every source with no overlap',function()
 local previous,production=ns.history,ns.production
 ns.history=ns.History.New({});ns.production=nil
 for i=1,50 do ns.history:Observe('a','A',{id='source'..i,kind='Loot',source=tostring(i),
  sourceName=i==25 and string.rep('Very long source name ',150)or('Wolf '..i),mapID=1,at=i,complete=true,items={[769]=1}})end
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 w.combined=nil;w.filter=nil;w.offset=0;w.expanded={[769]=true};ns.Reports.Update(w)
 local seen={};local count=0
 for offset=0,60 do
  ns.Reports.ScrollTo(w,offset)
  local bottom=132
  for _,view in ipairs(w.rows)do if view:IsShown()then
   local top=-view.point[5];assert(top>=bottom);bottom=top+view.height;assert(bottom<=510)
   if view.data.sourceRate then
    local id=view.data.sourceRate.source
    if not seen[id]then seen[id]=true;count=count+1 end
   end
  end end
 end
 eq(count,50)
 ns.Reports.ScrollTo(w,0);eq(w.rows[1].data.sourceRate,nil);eq(w.rows[1].cells[2].text,'50')
 w.rows[1].expand.scripts.OnClick(w.rows[1].expand)
 eq(w.offset,0);eq(w.rows[2]:IsShown(),false)
 ns.history,ns.production=previous,production;w.expanded={};ns.Reports.Update(w)
end)
test('unknown chances have no expander and combined sources use summed trials',function()
 local previous,production=ns.history,ns.production
 ns.history=ns.History.New({});ns.production=nil
 ns.history:Observe('a','A',{id='partial',kind='Loot',source='1',mapID=1,at=1,complete=false,items={[770]=2}})
 ns.history:Observe('a','A',{id='hit-a',kind='Mining',source='2',mapID=1,at=2,complete=true,items={[769]=1}})
 ns.history:Observe('b','B',{id='hit-b',kind='Mining',source='2',mapID=1,at=3,complete=true,items={[769]=1}})
 ns.history:Observe('b','B',{id='miss-b',kind='Mining',source='2',mapID=1,at=4,complete=true,items={}})
 ns.Reports.Show('history');local w=ns.Reports.windows.history
 w.combined=nil;w.filter=nil;w.page=1;w.expanded={[769]=true};ns.Reports.Update(w)
 eq(w.rows[2].cells[4].text,'100.0%');eq(w.rows[2].cells[5].text,'1 / 1')
 local unknown=w.rows[3];eq(unknown.data.itemID,770);eq(unknown.cells[3].text,'Unknown');assert(not unknown.expand:IsShown())
 pick(w.scope,'All characters');eq(w.rows[2].cells[4].text,'66.7%');eq(w.rows[2].cells[5].text,'2 / 3')
 eq(w.rows[1].cells[2].text,'2');eq(w.rows[3].cells[2].text,'2')
 ns.Reports.Show('chances');ns.Reports.Show('history');assert(w.expanded[769])
 ns.history,ns.production=previous,production;w.combined=nil;w.expanded={};ns.Reports.Update(w)
end)
test('data of a profession that is not installed or is switched off stays out of the reports',function()
 local previousHistory,previousProduction,previousActions=ns.history,ns.production,ns.actions
 ns.history=ns.History.New({})
 ns.history:Observe('a','a',{id='m',kind='Mining',source='9',mapID=1,x=.4,y=.6,at=100,complete=true,items={[2770]=3}})
 ns.history:Observe('a','a',{id='l',kind='Loot',source='8',mapID=1,x=.4,y=.6,at=100,complete=true,items={[769]=1}})
 ns.production={Totals=function()return{}end,Rows=function()return{{kind='Mining',outputs={}},{kind='Cooking',outputs={}}}end}
 ns.actions={Rows=function()return{{kind='Mining'},{kind='Herbs'}}end}
 local function ids(rows)local r={};for _,row in ipairs(rows)do r[row.itemID or row.kind]=true end;return r end
 ns.Catalog.Hidden=nil
 assert(ids(ns.Reports.Rows('history','a'))[2770] and ids(ns.Reports.Rows('chances','a'))[2770])
 ns.Catalog.Hidden=function(kind)return kind=='Mining'end
 local history=ids(ns.Reports.Rows('history','a'));assert(history[769] and not history[2770])
 local chances=ids(ns.Reports.Rows('chances','a'));assert(chances[769] and not chances[2770])
 local production=ids(ns.Reports.Rows('production','a'));assert(production.Cooking and not production.Mining)
 local actions=ids(ns.Reports.Rows('actions','a'));assert(actions.Herbs and not actions.Mining)
 ns.Catalog.Modules=function()return{{id='Cooking',label='Cooking',items={[769]=true}},{id='Mining',label='Mining',items={[2770]=true}}}end
 history=ids(ns.Reports.Rows('history','a'));assert(not history[2770],'a hidden profession item stays hidden even though its module lists it')
 ns.Catalog.Modules=function()return{{id='Cooking',label='Cooking'}}end
 ns.Catalog.Hidden=nil;ns.history,ns.production,ns.actions=previousHistory,previousProduction,previousActions
end)
test('every report copes with a player who has no profession addon installed',function()
 local modules,hiddenKind=ns.Catalog.Modules,ns.Catalog.Hidden
 ns.Catalog.Modules=function()return{}end;ns.Catalog.Hidden=function()return true end
 ns.Yields={Available=function()return{}end,Rows=function()return{}end};ns.Economy={Coin=function(c)return c..'c'end}
 for _,mode in ipairs({'history','chances','production','actions','reagentUsage'})do
  ns.Reports.Show(mode);local w=ns.Reports.windows[mode];assert(w:IsShown(),mode)
 end
 local w=ns.Reports.windows.actions;pick(w.group,'Gathered, most items')
 eq(w.filter,nil);eq(w.rows[1]:IsShown(),false);assert(w.empty.text:find('No gathering profession',1,true))
 pick(w.group,'Actions summary')
 ns.Catalog.Modules,ns.Catalog.Hidden=modules,hiddenKind;ns.Yields,ns.Economy=nil,nil
end)
test('Economy shows confirmed receipts for the empty Forever realm key and labels missing coverage', function()
    GetRealmName = function() return '' end
    ns.Economy = { Coin = function(copper) return copper .. 'c' end }
    ns.db = { sales = { entries = {
        { realm = '', source = 'invoice', count = 5, bid = 1000, fee = 50, deposit = 20, received = 970 },
        { realm = '', source = 'invoice', bid = 500, fee = 25, deposit = 10, received = 300 },
        { realm = '', source = 'header', count = 8, received = 2000 },
        { realm = 'Other realm', source = 'invoice', count = 20, bid = 1000, fee = 50, deposit = 100, received = 1050 },
    } }, lootIncome = { [''] = { player = { copper = 35, pickups = 2 } } },
        vendorSales = { [''] = { player = {
            sale = { [42] = { units = 3, copper = 68, stacks = 1 } },
            buyback = { [40] = { units = 2, copper = 45, stacks = 1 } },
            repair = { copper = 96, count = 3 },
        } } }, questIncome = { [''] = { player = { [12] = { copper = 40, turnIns = 2 } } } } }
    assert(loadfile('TitanGatheredForever/Sales.lua'))('Titan Gathered Forever', ns)
    assert(loadfile('TitanGatheredForever/LootIncome.lua'))('Titan Gathered Forever', ns)
    assert(loadfile('TitanGatheredForever/VendorSales.lua'))('Titan Gathered Forever', ns)
    assert(loadfile('TitanGatheredForever/QuestIncome.lua'))('Titan Gathered Forever', ns)
    assert(loadfile('TitanGatheredForever/EconomyView.lua'))('Titan Gathered Forever', ns)
    local previous = ns.Nav.Current()
    assert(previous)
    ns.Nav.Open('economy')
    local w = ns.EconomyView.window
    eq(ns.Nav.Current(), 'economy')
    eq(w.rows[1].units.text, ns.Style.Value(3))
    eq(w.rows[1].income.text, ns.Style.Value('68c'))
    eq(w.vendorBuybacks.text, ns.Style.Value(2) .. ns.Style.Label(' units for ') .. ns.Style.Value('45c'))
    eq(w.vendorRepairs.text, ns.Style.Value(3) .. ns.Style.Label(' repairs for ') .. ns.Style.Value('96c'))
    eq(w.rows[2].units.text, ns.Style.Label('At least ') .. ns.Style.Value(5))
    eq(w.rows[2].income.text, ns.Style.Label('At least ') .. ns.Style.Value('950c'))
    eq(w.rows[3].income.text, ns.Style.Value('40c'))
    eq(w.rows[3].coverage.text, ns.Style.Value(2) .. ns.Style.Label(' verified turn-ins'))
    eq(w.rows[4].income.text, ns.Style.Value('35c'))
    eq(w.rows[4].coverage.text, ns.Style.Value(2) .. ns.Style.Label(' verified coin pickups'))
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('1093c'))
    eq(w.invoiceCount.text, ns.Style.Value(2))
    eq(w.gross.text, ns.Style.Value('1500c'))
    eq(w.credit.text, ns.Style.Value('1270c'))
    ns.db.sales.entries[2].received = 485
    ns.db.sales.entries[2].count = 2
    ns.EconomyView.Refresh()
    eq(w.rows[2].units.text, ns.Style.Value(7))
    eq(w.rows[2].income.text, ns.Style.Value('1425c'))
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('1568c'))
    ns.Nav.Open('history')
    assert(not w:IsShown())
    ns.db.sales.entries = {}
    ns.Nav.Open('economy')
    eq(w.invoiceCount.text, ns.Style.Value(0))
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('143c'))
    ns.db.lootIncome = {}
    ns.db.vendorSales = {}
    ns.db.questIncome = {}
    ns.EconomyView.Refresh()
    eq(w.rows[4].income.text, ns.Style.Label('Unavailable'))
    eq(w.rows[5].income.text, ns.Style.Label('Unavailable'))
    ns.characterID = 'player'
    ns.db.characters = { player = { economyName = 'Seller' } }
    ns.db.production = { characters = { alt = { name = 'Crafter - ' } } }
    ns.db.vendorSales[''] = {
        player = { sale = { [42] = { units = 2, copper = 25, stacks = 1 } } },
        alt = { buyback = { [42] = { units = 1, copper = 11, stacks = 1 } }, repair = { copper = 13, count = 1 } },
    }
    ns.db.questIncome[''] = { alt = { [12] = { copper = 120, turnIns = 1 } } }
    ns.db.lootIncome[''] = { player = { copper = 15, pickups = 1 }, alt = { copper = 18, pickups = 2 } }
    ns.db.sales.entries = {
        { realm = '', character = 'Seller', source = 'invoice', count = 1, bid = 100, fee = 5, deposit = 10, received = 105 },
        { realm = '', character = 'Crafter', source = 'invoice', count = 2, bid = 200, fee = 10, deposit = 10, received = 200 },
        { realm = '', character = 'Auctioneer', source = 'invoice', count = 1, bid = 100, fee = 5, deposit = 0, received = 95 },
    }
    ns.EconomyView.Refresh()
    pick(w.characterPicker, 'This character')
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('135c'))
    eq(w.invoiceCount.text, ns.Style.Value(1))
    eq(w.vendorRepairs.text, ns.Style.Label('None recorded'))
    pick(w.characterPicker, 'Crafter')
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('328c'))
    eq(w.vendorRepairs.text, ns.Style.Value(1) .. ns.Style.Label(' repair for ') .. ns.Style.Value('13c'))
    eq(w.vendorBuybacks.text, ns.Style.Value(1) .. ns.Style.Label(' unit for ') .. ns.Style.Value('11c'))
    pick(w.characterPicker, 'Auctioneer (auction history)')
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('95c'))
    pick(w.characterPicker, 'All characters')
    eq(w.rows[5].income.text, ns.Style.Label('At least ') .. ns.Style.Value('558c'))
    ns.characterID = nil
end)
test('profession statistics attach below the native window, preserve recipe counts and show scoped history',function()
    local base=CreateFrame
    local created={}
    CreateFrame=function(_,_,parent)
        local f=base();f.parent=parent;created[#created+1]=f
        function f:GetFrameLevel()return self.frameLevel or 5 end
        function f:SetFrameLevel(level)self.frameLevel=level end
        function f:SetHighlightTexture()end
        function f:LockHighlight()self.highlighted=true end
        function f:UnlockHighlight()self.highlighted=false end
        function f:HookScript(name,callback)self.scripts[name]=callback end
        function f:Show()if self.shown then return end;self.shown=true;if self.scripts.OnShow then self.scripts.OnShow()end end
        function f:Hide()if not self.shown then return end;self.shown=false;if self.scripts.OnHide then self.scripts.OnHide()end end
        function f:SetShown(shown)if shown then self:Show()else self:Hide()end end
        function f:IsVisible()return self:IsShown()and(not self.parent or self.parent:IsVisible())end
        function f:RegisterEvent()end
        return f
    end
    ns.characterID='a';ns.IsPublic=function()return true end
    ns.Crafting={Resolve=function(info)return info.recipeID end}
    ns.ProfessionButton={Sync=function()end}
    ns.production=ns.Production.New({}, {Character=function()return'a'end,Name=function()return'A'end,
        Timestamp=function()return 100 end,Now=function()return 100 end,Enabled=function()return true end,
        Public=function()return true end,Recipe=function(id)
            return {recipeID=id,name='Soup',kind='Cooking',outputItemID=2680,outputIDs={[2680]=true},
                reagents={[159]=3},reagentsSupported=true}
        end})
    ProfessionsFrame=CreateFrame('Frame');ProfessionsFrame:Show()
    local page=CreateFrame('Frame',nil,ProfessionsFrame);page:Show();ProfessionsFrame.CraftingPage=page
    function page:SetAlpha(v)self.alpha=v end;function page:GetAlpha()return self.alpha or 1 end
    local book=CreateFrame('Frame',nil,ProfessionsFrame);book:Show();ProfessionsFrame.BookPage=book
    function book:SetAlpha(v)self.alpha=v end;function book:GetAlpha()return self.alpha or 1 end
    function book:HookScript(name,callback)self.scripts[name]=callback end
    local sideTabs={}
    local function sideTab(left,width)
        local b=CreateFrame('Button',nil,UIParent);b.clicks=0
        function b:GetObjectType()return'CheckButton'end
        function b:GetLeft()return left end;function b:GetRight()return left+width end
        function b:GetWidth()return width end;function b:GetHeight()return 60 end
        function b:HookScript(name,callback)self.hookedScripts=self.hookedScripts or{};self.hookedScripts[name]=callback end
        b:Show();sideTabs[#sideTabs+1]=b;return b
    end
    local tabOne,tabTwo,insideButton=sideTab(805,60),sideTab(805,60),sideTab(300,60)   -- the last one is inside the window
    function ProfessionsFrame:GetRight()return 800 end
    function ProfessionsFrame:GetChildren()return tabOne,tabTwo,insideButton end
    page.professionInfo={professionID=185}
    local row=CreateFrame('Button');row.learned=true
    local info={recipeID=2536};local node={GetData=function()return {recipeInfo=info}end}
    function row:GetElementData()return node end
    function row:GetWidth()return 200 end
    row.Label=region();row.Label:SetText('Soup');function row.Label:GetStringWidth()return 40 end
    row.Count=CreateFrame('Frame');row.Count:Show();row.Count:SetText(' [7] ')
    function row.Count:GetStringWidth()return #self.text*4 end
    row.SkillUps={GetWidth=function()return 16 end}
    local box={ForEachFrame=function(_,callback)callback(row)end}
    page.RecipeList={ScrollBox=box}
    ScrollUtil={AddInitializedFrameCallback=function(scroll,callback,owner)eq(scroll,box)
        box.initialized=function()callback(owner,row,node)end
    end}
    local function cast(outcome,guid)ns.production:Cast('UNIT_SPELLCAST_'..outcome,'player',guid,2536)end
    cast('START','first');cast('SUCCEEDED','first');cast('START','second');cast('FAILED','second')
    assert(loadfile('TitanGatheredForever/ProfessionStats.lua'))('Titan Gathered Forever',ns)
    local view=ns.ProfessionStats
    view.Initialize();eq(view.tab.parent,ProfessionsFrame);eq(view.tab.point[3],'BOTTOMRIGHT')
    -- The native list shows the number that can be made with the materials at hand in square brackets: the add-on must not
    -- write a second number beside it (the lifetime count is in the Statistics panel and in the recipe menu).
    eq(row.Count.text,' [7] ');view.Refresh();eq(row.Count.text,' [7] ')
    eq(box.initialized,nil)
    view.tab.scripts.OnClick();assert(view.panel:IsVisible());eq(view.panel.kind,'Cooking')
    eq(#view.panel.backgrounds,2,'the background leaves the portrait of the window free')
    -- The panel covers everything in the native window, also its skill bars (they are drawn at high frame levels).
    assert(view.panel.frameLevel>=ProfessionsFrame:GetFrameLevel()+500,'the panel is above the native window')
    eq(view.panel.lines[1].cells[1].text,ns.Style.Value('Soup'))
    eq(view.panel.lines[1].cells[2].text,ns.Style.Value(2));eq(view.panel.lines[1].cells[3].text,ns.Style.Value(1))
    -- Matched outputs, Items, Bonus and Multicraft were always Unknown in this client: they are not columns, the details
    -- stay in the menu of a recipe.
    eq(view.panel.lines[1].cells[4].text,ns.Style.Value('50.0%'))
    eq(view.panel.lines[1].cells[5].text,'')
    local heads={};for index=1,4 do heads[index]=view.panel.head[index].text end
    eq(heads[1],ns.Style.Label('Recipe'));eq(heads[2],ns.Style.Label('Attempts'));eq(heads[3],ns.Style.Label('Completed'))
    eq(heads[4],ns.Style.Label('Completed %'));eq(view.panel.head[5].text,'')
    assert(view.panel.coverage.text:find('Completed % = completed',1,true),'the explanation of the column is kept')
    -- The views are chosen in a combo box on the row of the pickers (the portrait and the skill bar of the native window
    -- cover the top-left corner of the panel), like the other pickers.
    local viewPicker=view.panel.viewPicker
    eq(viewPicker.point[5],-40);assert(viewPicker.point[4]>=360,'right of the pickers')
    local viewOptions=view.panel.ViewOptions()
    eq(#viewOptions,3);eq(viewOptions[1].value,'attempts');eq(viewOptions[1].label,'Attempts')
    eq(viewOptions[2].label,'Materials');eq(viewOptions[3].value,'gathered');eq(viewOptions[3].label,'Gathered items')
    view.panel.SetView('materials')
    eq(view.panel.lines[1].cells[1].text,'Item 159');eq(view.panel.lines[1].cells[4].text,ns.Style.Value(3))
    eq(view.panel.lines[1].cells[2].text,'');eq(view.panel.lines[1].cells[3].text,'')
    -- The header sorts the list: a click on a column sorts by it (names a to z, numbers from the highest), a second click
    -- reverses the order, and the choice is kept for each of the two views.
    local rows={
        {name='Beta',recipeID=2,attempts=10,completed=5},{name='Alpha',recipeID=1,attempts=4,completed=4},
        {name='Gamma',recipeID=3,attempts=7,completed=7},{name='Delta',recipeID=4,attempts=0,completed=0},
    }
    local function names(list)local r={};for _,row in ipairs(list)do r[#r+1]=row.name end;return table.concat(r,',')end
    local function sorted(state)local copy={};for i,row in ipairs(rows)do copy[i]=row end;view.SortRows(copy,'attempts',state);return names(copy)end
    eq(sorted({column=1,descending=false}),'Alpha,Beta,Delta,Gamma');eq(sorted({column=1,descending=true}),'Gamma,Delta,Beta,Alpha')
    eq(sorted({column=2,descending=true}),'Beta,Gamma,Alpha,Delta');eq(sorted({column=2,descending=false}),'Delta,Alpha,Gamma,Beta')
    eq(sorted({column=3,descending=true}),'Gamma,Beta,Alpha,Delta')
    eq(sorted({column=4,descending=true}),'Alpha,Gamma,Beta,Delta')      -- 100%, 100%, 50%, unknown last; ties by name
    local usage={{itemID=3,quantity=5},{itemID=1,quantity=9},{itemID=2,quantity=5}}
    view.SortRows(usage,'materials',{column=4,descending=true});eq(usage[1].itemID,1);eq(usage[2].itemID,2);eq(usage[3].itemID,3)
    view.SortRows(usage,'materials',{column=1,descending=false});eq(usage[1].itemID,1);eq(usage[3].itemID,3)
    view.panel.SetView('attempts')
    local buttons=view.panel.headButtons
    eq(#buttons,6);eq(view.panel.sorts.attempts.column,1);eq(view.panel.sorts.attempts.descending,false)
    buttons[3].scripts.OnClick();eq(view.panel.sorts.attempts.column,3);eq(view.panel.sorts.attempts.descending,true)
    buttons[3].scripts.OnClick();eq(view.panel.sorts.attempts.descending,false)
    buttons[1].scripts.OnClick();eq(view.panel.sorts.attempts.column,1);eq(view.panel.sorts.attempts.descending,false)
    eq(view.panel.sorts.materials.column,4);eq(view.panel.sorts.materials.descending,true)   -- the other view keeps its own
    -- One list for crafts and for gathering: the Herbalism attempts are a row next to the recipes, with their own details.
    ns.Economy=ns.Economy or {Coin=function(copper)return copper..'c' end}
    local originalRows=ns.Reports.Rows
    ns.Reports.Rows=function(mode,...)
        local result=originalRows(mode,...)
        if mode=='actions'then result[#result+1]={kind='Herbs',attempts=3,completed=2,failed=1,interrupted=0,stopped=0,unresolved=0,began=100}end
        return result
    end
    view.panel.kind=false;view.Refresh()
    local gathering,disenchant
    for _,line in ipairs(view.panel.lines)do
        if line.data and line.data.action and line.data.action.kind=='Herbs' then gathering=line end
        if line.data and line.data.action and line.data.action.kind=='Enchanting' then disenchant=line end
    end
    assert(gathering,'a gathering row is in the list');assert(gathering.cells[1].text:find('Herbalism',1,true))
    assert(gathering.cells[1].text:find('(gathering)',1,true),'it is marked as gathering')
    assert(disenchant and not disenchant.cells[1].text:find('(gathering)',1,true),'disenchanting is not called gathering')
    eq(gathering.cells[2].text,ns.Style.Value(gathering.data.attempts))
    local titles={};local previousMenu=MenuUtil
    MenuUtil={CreateContextMenu=function(owner,fn)fn(owner,{CreateTitle=function(_,t)titles[#titles+1]=t end,SetScrollMode=function()end})end}
    gathering.scripts.OnClick(gathering)
    local joined=table.concat(titles,'\n');assert(joined:find('Failed',1,true) and joined:find('Interrupted',1,true),joined)
    MenuUtil=previousMenu;ns.Reports.Rows=originalRows
    ns.Catalog.modules.Herbs={label='Herbalism',items={}}
    local options=view.KindOptions(view.panel);local seen={}
    for _,option in ipairs(options)do seen[option.value]=true end
    assert(seen[false] and seen.Cooking and seen.Herbs,'crafts and gathering professions are in the picker')
    page.professionInfo={professionID=393}
    eq(view.ActiveKind(),'Skinning');page.professionInfo={professionID=185}
    -- The Gathered view: what was gathered and what it is worth, one gathering profession at a time.
    local asked={}
    ns.Yields={Available=function()return{'Herbs'}end,Rows=function(character,kind,sort)
        asked[#asked+1]={character,kind,sort}
        return {{summary=true,title=true,text='Herbalism',gold=true},{summary=true,spacer=true,small=true,text=''},
            {itemID=3,quantity=5,share=50,unit=100,value=500,source='Peacebloom'},
            {summary=true,spacer=true,text=''},{summary=true,title=true,text='Fishing',gold=true},
            {itemID=4,quantity=2,share=100,unit=50,value=100,source='Vendor'}}
    end}
    ns.Reports.ItemSources=function(owner,itemID,character)ns.sourcesAsked={itemID,character}end
    view.panel.SetView('gathered')
    eq(view.panel.view,'gathered');eq(asked[#asked][2],nil,'all gathering professions at first');eq(asked[#asked][3],'quantity')
    eq(#view.panel.data,7,'the small spacer is left out, the one between two professions stays, each profession has its column names')
    eq(view.panel.lines[4].cells[1].text,'');assert(view.panel.lines[5].cells[1].text:find('Fishing',1,true))
    eq(view.panel.lines[2].cells[1].text,ns.Style.Label('Item'));eq(view.panel.lines[2].cells[5].text,ns.Style.Label('Total value'))
    eq(view.panel.lines[6].cells[2].text,ns.Style.Label('Quantity'),'every profession repeats the column names')
    view.panel.SelectKind('Herbs');eq(asked[#asked][2],'Herbs')
    view.panel.SelectKind(false);eq(asked[#asked][2],nil)
    assert(view.panel.lines[1].cells[1].text:find('Herbalism',1,true))
    eq(view.panel.lines[3].cells[1].text,'Item 3');eq(view.panel.lines[3].cells[2].text,ns.Style.Value(5))
    eq(view.panel.lines[3].cells[3].text,ns.Style.Value('50.0%'));eq(view.panel.lines[3].cells[5].text,'500c')
    eq(view.panel.head[2].text,ns.Style.Label('Quantity'));eq(view.panel.head[5].text,ns.Style.Label('Total value'))
    eq(view.panel.head[6].text,ns.Style.Label('Best sale'))
    view.panel.headButtons[5].scripts.OnClick();eq(asked[#asked][3],'value')
    view.panel.headButtons[2].scripts.OnClick();eq(asked[#asked][3],'quantity')
    -- Every column of the Gathered view sorts the items inside each profession; a row without a value is always last.
    ns.Yields={Available=function()return{'Herbs'}end,Rows=function(character,kind,sort)
        asked[#asked+1]={character,kind,sort}
        return {{summary=true,title=true,text='Herbalism',gold=true},{summary=true,spacer=true,small=true,text=''},
            {itemID=3,quantity=5,share=50,unit=100,value=500,source='Peacebloom'},
            {itemID=5,quantity=3,share=30,unit=300,value=900,source='Vendor'},
            {itemID=6,quantity=2,share=20},
            {summary=true,spacer=true,text=''},{summary=true,title=true,text='Fishing',gold=true},
            {itemID=7,quantity=9,share=80,unit=5,value=45,source='Auction'},
            {itemID=4,quantity=2,share=20,unit=50,value=100,source='Vendor'}}
    end}
    local function order()local ids={};for _,row in ipairs(view.panel.data)do if row.itemID then ids[#ids+1]=row.itemID end end;return table.concat(ids,',')end
    view.panel.SetView('gathered');view.panel.sorts.gathered={column=2,descending=true};ns.settings.columnSort={}
    view.panel.SetView('gathered');eq(order(),'3,5,6,7,4'..'')                     -- the order of the data: the quantity, as before
    view.panel.headButtons[5].scripts.OnClick();eq(order(),'5,3,6,4,7')            -- Total value: the highest first, no value last, per profession
    view.panel.headButtons[5].scripts.OnClick();eq(order(),'3,5,6,7,4')            -- again: the lowest first
    view.panel.headButtons[1].scripts.OnClick();eq(order(),'3,5,6,4,7')            -- Item: a to z
    view.panel.headButtons[4].scripts.OnClick();eq(order(),'5,3,6,4,7')            -- Unit value: the highest first, no price last
    view.panel.headButtons[6].scripts.OnClick();eq(order(),'3,5,6,7,4')            -- Best sale, a text: a to z (Peacebloom, Vendor, none)
    view.panel.headButtons[3].scripts.OnClick();eq(order(),'3,5,6,7,4')            -- Share, the highest first
    eq(ns.settings.columnSort.statistics_gathered.column,3);eq(ns.settings.columnSort.statistics_gathered.descending,true)
    view.panel.sorts.gathered={column=2,descending=true};ns.settings.columnSort={}
    view.panel.lines[3].scripts.OnClick(view.panel.lines[3]);eq(ns.sourcesAsked[1],3)
    ns.sourcesAsked=nil;view.panel.lines[2].scripts.OnClick(view.panel.lines[2]);eq(ns.sourcesAsked,nil,'the column names are not an item')
    local gatheredOptions=view.KindOptions(view.panel)
    eq(#gatheredOptions,2);eq(gatheredOptions[1].value,false);eq(gatheredOptions[1].label,'All gathering');eq(gatheredOptions[2].value,'Herbs')
    view.panel.SetView('attempts')
    eq(view.panel.view,'attempts');eq(view.panel.head[2].text,ns.Style.Label('Attempts'))
    view.panel.SetView('materials')
    ns.Yields=nil
    -- The native pages under the panel are made transparent while it is open (their skill bars drew over it) and are
    -- restored when it closes.
    eq(page.alpha,0);eq(book.alpha,0)
    view.panel:Hide();eq(page.alpha,1);eq(book.alpha,1)
    view.tab.scripts.OnClick();assert(view.panel:IsShown());eq(page.alpha,0)
    -- A click on any tab of a profession (the buttons beside the window) closes the panel.
    assert(tabOne.hookedScripts and tabOne.hookedScripts.OnClick,'the first tab is hooked')
    assert(tabTwo.hookedScripts and tabTwo.hookedScripts.OnClick,'the second tab is hooked')
    eq(insideButton.hookedScripts,nil)
    tabTwo.hookedScripts.OnClick();assert(not view.panel:IsShown());eq(page.alpha,1)
    view.tab.scripts.OnClick();assert(view.panel:IsShown())
    -- A change of the profession (an event of the client) closes it as well; the same profession does not.
    local listener
    for _,control in ipairs(created)do if control.scripts.OnEvent and control.events==nil then listener=control end end
    local previousTimer=C_Timer;C_Timer={After=function(_,fn)fn()end}
    ns.IsPublic=function()return true end
    view.listener.scripts.OnEvent(view.listener,'TRADE_SKILL_DATA_SOURCE_CHANGED')
    assert(view.panel:IsShown(),'the same profession keeps the panel')
    page.professionInfo={professionID=164}
    view.listener.scripts.OnEvent(view.listener,'TRADE_SKILL_DATA_SOURCE_CHANGED')
    assert(not view.panel:IsShown(),'another profession closes it');eq(page.alpha,1)
    page.professionInfo={professionID=185};C_Timer=previousTimer
    -- A profession that could not be read when the panel opened is adopted later instead of closing the panel.
    page.professionInfo=nil;view.tab.scripts.OnClick();assert(view.panel:IsShown())
    page.professionInfo={professionID=185};C_Timer={After=function(_,fn)fn()end}
    view.listener.scripts.OnEvent(view.listener,'TRADE_SKILL_DATA_SOURCE_CHANGED')
    assert(view.panel:IsShown(),'the late reading is adopted');C_Timer=previousTimer
    view.panel:Hide();page.professionInfo={professionID=185}
    view.tab.scripts.OnClick()
    ProfessionsFrame:Hide();assert(not view.panel:IsShown());assert(not view.tab.highlighted)
    ProfessionsFrame,ScrollUtil,CreateFrame=nil,nil,base
end)
test('the statistics panel is raised above every frame of the native window and every frame anchored to it',function()
    local function fake(name,strata,level,children,anchor)
        local f={name=name,strata=strata,level=level,children=children or{},anchor=anchor,shown=true}
        function f:GetName()return self.name end
        function f:GetObjectType()return 'Frame' end
        function f:GetChildren()return unpack(self.children)end
        function f:GetFrameStrata()return self.strata end
        function f:GetFrameLevel()return self.level end
        function f:SetFrameStrata(v)self.strata=v end
        function f:SetFrameLevel(v)self.level=v end
        function f:GetNumPoints()return self.anchor and 1 or 0 end
        function f:GetPoint()return 'TOP',self.anchor,'BOTTOM',0,0 end
        return f
    end
    local view=ns.ProfessionStats
    local label=fake('Label','MEDIUM',506)
    local panel=fake('Panel','MEDIUM',505,{label})
    local deepBar=fake('DeepBar','HIGH',700)
    local page=fake('Page','MEDIUM',20,{deepBar})
    local host=fake('Host','MEDIUM',5,{page,panel})
    local outside=fake('OutsideBar','DIALOG',1200,{},host)             -- another add-on's bar anchored to the window
    local unrelated=fake('Chat','TOOLTIP',9000)
    UIParent=fake('UIParent','MEDIUM',0,{outside,unrelated,host})
    ns.db={professionLog={}}
    view.layerSeen=0
    view.Raise(panel,host)
    eq(panel.strata,'DIALOG');assert(panel.level>1200,'above the bar of the other add-on')
    eq(label.level,506+(panel.level-505))                              -- the children of the panel move with it
    assert(panel.level<=9990)
    local row=ns.db.professionLog[1]
    eq(row.stage,'stats-layer');assert(row.highest[1]:find('OutsideBar',1,true),row.highest[1])
    -- nothing to raise when the panel is already on top
    local before=panel.level;view.Raise(panel,host);eq(panel.level,before)
    -- the strata never go above FULLSCREEN: the menus of the client stay over the panel
    host.children={page,panel,fake('Tip','TOOLTIP',50)};panel.strata='MEDIUM';panel.level=1
    view.Raise(panel,host);eq(panel.strata,'FULLSCREEN')
    -- broken frames never raise
    local ok=pcall(view.Raise,nil,host);assert(ok)
    UIParent=frame()
end)
print('PASS '..passed..' history/report window checks')
