local f=assert(loadfile('tests/export_fixture.lua'))()
local ns=f.ns
local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,fn)local ok,e=pcall(fn);if not ok then error(n..': '..e)end;passed=passed+1 end
local function region()return{SetPoint=function()end,SetWidth=function()end,SetJustifyH=function()end,SetText=function(self,v)self.text=v end}end
local function frame()
 local obj={scripts={},shown=false,TitleText=region()}
 for _,method in ipairs({'SetSize','SetPoint','SetWidth','SetHeight','SetClampedToScreen','SetMovable','EnableMouse',
  'RegisterForDrag','StartMoving','StopMovingOrSizing','SetMultiLine','SetAutoFocus','SetFontObject',
  'SetMaxLetters','SetMaxBytes','SetVisibleTextByteLimit','SetCountInvisibleLetters','SetScrollChild','SetVerticalScroll'})do obj[method]=function()end end
 function obj:SetScript(event,fn)self.scripts[event]=fn end
 function obj:CreateFontString()return region()end
 function obj:SetText(text)
  self.text=self.truncate and text:sub(1,3)or text
  if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false)end
 end
 function obj:GetText()return self.text end
 function obj:SetFocus()self.focus=true end
 function obj:ClearFocus()self.focus=false end
 function obj:HighlightText()self.highlighted=true end
 function obj:Show()self.shown=true end
 function obj:Hide()self.shown=false;if self.scripts.OnHide then self.scripts.OnHide(self)end end
 function obj:IsShown()return self.shown end
 return obj
end
CreateFrame=function()return frame()end;UIParent=frame();UISpecialFrames={}
local generated=0
ns.Export.Current=function(options)generated=generated+1;return ns.Export.Build(f.sources,options)end
assert(loadfile('TitanGatheredForeverV3/ExportView.lua'))('TGF v3',ns)
test('opening exports current character with identity off and no collector mutation',function()
 ns.ExportView.Show();local w=ns.ExportView.window
 assert(w:IsShown());eq(w.scopeMode,'character');eq(w.includeIdentity,false)
 assert(not table.concat(w.parts):find('Player-private',1,true));assert(w.copyValid)
 eq(f.saved.actions.characters['Player-private-A'].recent['private-cast-pending'].sealed,nil)
 eq(#UISpecialFrames,1)
end)
test('scope and identity controls regenerate selected snapshots explicitly',function()
 local w=ns.ExportView.window
 w.scope.scripts.OnClick();eq(w.scopeMode,'combined')
 assert(table.concat(w.parts):find('combined',1,true))
 w.identity.scripts.OnClick();eq(w.includeIdentity,true);assert(table.concat(w.parts):find('Player-private-A',1,true))
 w.identity.scripts.OnClick();assert(not table.concat(w.parts):find('Player-private',1,true))
end)
test('paging copy selection and accidental editing preserve the generated part',function()
 local w=ns.ExportView.window;local original=ns.Export.Parts
 ns.Export.Parts=function(payload)return original(payload,64)end
 w.generate.scripts.OnClick();assert(#w.parts>1);eq(w.part,1)
 w.next.scripts.OnClick();eq(w.part,2);eq(w.editor:GetText(),w.parts[2])
 w.copy.scripts.OnClick();eq(w.editor.focus,true);eq(w.editor.highlighted,true)
 w.editor.text='accidental edit';w.editor.scripts.OnTextChanged(w.editor,true);eq(w.editor:GetText(),w.parts[2])
 w.previous.scripts.OnClick();eq(w.part,1)
 ns.Export.Parts=original
end)
test('snapshots remain stable until the user generates again',function()
 local w=ns.ExportView.window;local before=table.concat(w.parts);local count=generated
 f.sources.timestamp=301;ns.ExportView.Display()
 eq(table.concat(w.parts),before);eq(generated,count)
 w.generate.scripts.OnClick();assert(table.concat(w.parts)~=before)
end)
test('hide clears copy data and identity and reopening returns to safe defaults',function()
 local w=ns.ExportView.window;w.identity.scripts.OnClick();assert(w.includeIdentity)
 w:Hide();eq(w.editor:GetText(),'');eq(#w.parts,0);eq(w.includeIdentity,false);eq(w.editor.focus,false)
 ns.ExportView.Show();eq(w.scopeMode,'character');eq(w.includeIdentity,false)
 assert(not table.concat(w.parts):find('Player-private',1,true))
end)
test('native truncation disables copying rather than offering incomplete JSON',function()
 local w=ns.ExportView.window;w.editor.truncate=true;w.generate.scripts.OnClick()
 eq(w.copyValid,false);assert(w.status.text:find('truncated',1,true))
 w.editor.focus=false;w.copy.scripts.OnClick();eq(w.editor.focus,false)
 w.editor.truncate=false;w.generate.scripts.OnClick();assert(w.copyValid)
end)
test('generation errors clear previous sensitive content',function()
 local w=ns.ExportView.window;w.identity.scripts.OnClick();local original=ns.Export.Current
 ns.Export.Current=function()error('bad data')end;w.generate.scripts.OnClick()
 eq(#w.parts,0);eq(w.editor:GetText(),'');eq(w.copyValid,false)
 ns.Export.Current=original
end)
print('PASS '..passed..' export copy window checks')
