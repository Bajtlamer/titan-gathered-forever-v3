local _, ns = ...
local View={};ns.ExportView=View
local function text(frame,font,x,y,width)
    local t=frame:CreateFontString(nil,'OVERLAY',font);t:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y)
    t:SetWidth(width);t:SetJustifyH('LEFT');return t
end
local function button(frame,label,x,y,width,callback)
    local b=CreateFrame('Button',nil,frame,'UIPanelButtonTemplate');b:SetSize(width,22)
    b:SetPoint('TOPLEFT',frame,'TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',callback);return b
end
function View.Display()
    local w=View.window;if not w then return end
    w.part=math.min(math.max(1,w.part),math.max(1,#w.parts))
    local content=w.parts[w.part]or''
    w.currentText=content;w.editor:SetText(content);w.editor:ClearFocus()
    w.editor:SetHeight(math.max(360,math.ceil(#content/60)*18))
    w.scroll:SetVerticalScroll(0)
    w.copyValid=content~=''and w.editor:GetText()==content
    w.scope:SetText(w.scopeMode=='combined'and'All characters'or'This character')
    w.identity:SetText('Include names/GUIDs: '..(w.includeIdentity and'On'or'Off'))
    if content~=''and not w.copyValid then
        w.status:SetText('The client truncated this part. Copying is disabled; do not save incomplete JSON.')
    elseif content~=''then
        w.status:SetText(string.format('Part %d / %d; %d characters; %d total JSON bytes; names/GUIDs %s.',
            w.part,#w.parts,w.characterCount,w.bytes,w.includeIdentity and'included'or'excluded'))
    end
end
function View.Generate()
    local w=View.window
    local ok,parts,bytes,count=pcall(function()
        local document=ns.Export.Current({scope=w.scopeMode,includeIdentity=w.includeIdentity})
        local payload=ns.Export.Encode(document)
        return ns.Export.Parts(payload),#payload,document.selection.characterCount
    end)
    w.parts,w.part,w.bytes,w.characterCount={},1,0,0
    if ok then
        w.parts,w.bytes,w.characterCount=parts,bytes,count
        View.Display()
    else
        View.Display();w.status:SetText('Export unavailable: '..tostring(parts))
    end
end
function View.Show()
    local w=View.window
    if not w then
        local name='TitanGatheredForeverV3ExportWindow'
        w=CreateFrame('Frame',name,UIParent,'BasicFrameTemplateWithInset');View.window=w
        if UISpecialFrames then table.insert(UISpecialFrames,name)end
        w:SetSize(820,650);w:SetPoint('CENTER',UIParent,'CENTER',0,0)
        w:SetClampedToScreen(true);w:SetMovable(true);w:EnableMouse(true);w:RegisterForDrag('LeftButton')
        w:SetScript('OnDragStart',function(self)self:StartMoving()end)
        w:SetScript('OnDragStop',function(self)self:StopMovingOrSizing()end)
        w.TitleText:SetText('TGF v3 Export statistics')
        local note=text(w,'GameFontHighlightSmall',15,-35,785)
        note:SetText('JSON snapshot for manual copying. Names/GUIDs are off by default; item IDs, map IDs and gameplay timestamps remain.\nNothing is sent. Counts stay separate: acquisitions, complete-source samples, actions and crafting.')
        w.scope=button(w,'This character',15,-90,145,function()
            w.scopeMode=w.scopeMode=='character'and'combined'or'character';View.Generate()
        end)
        w.identity=button(w,'Include names/GUIDs: Off',170,-90,240,function()
            w.includeIdentity=not w.includeIdentity;View.Generate()
        end)
        w.generate=button(w,'Generate',420,-90,100,View.Generate)
        w.copy=button(w,'Select text',530,-90,110,function()
            if w.copyValid then w.editor:SetFocus();w.editor:HighlightText()end
        end)
        w.status=text(w,'GameFontHighlightSmall',15,-130,785)
        w.scroll=CreateFrame('ScrollFrame',nil,w,'UIPanelScrollFrameTemplate')
        w.scroll:SetPoint('TOPLEFT',w,'TOPLEFT',15,-160);w.scroll:SetSize(760,370)
        w.editor=CreateFrame('EditBox',nil,w.scroll);w.editor:SetWidth(740);w.editor:SetMultiLine(true)
        w.editor:SetFontObject('ChatFontNormal');w.editor:SetAutoFocus(false);w.editor:EnableMouse(true)
        w.editor:SetMaxLetters(32768);w.editor:SetMaxBytes(32768)
        if w.editor.SetVisibleTextByteLimit then w.editor:SetVisibleTextByteLimit(32768)end
        if w.editor.SetCountInvisibleLetters then w.editor:SetCountInvisibleLetters(true)end
        w.editor:SetScript('OnEscapePressed',function(self)self:ClearFocus();w:Hide()end)
        w.editor:SetScript('OnTextChanged',function(_,userInput)
            if userInput then View.Display()end
        end)
        w.scroll:SetScrollChild(w.editor)
        w.previous=button(w,'Previous part',15,-555,120,function()w.part=w.part-1;View.Display()end)
        w.next=button(w,'Next part',145,-555,120,function()w.part=w.part+1;View.Display()end)
        local instructions=text(w,'GameFontHighlightSmall',15,-590,785)
        instructions:SetText('Select text, then copy with Ctrl+C or Cmd+C. Save every part to a separate UTF-8 JSON file.\nFor numbered parts, reconstruct with tools/read_export.py. Generate starts a new snapshot; do not mix snapshots.')
        w:SetScript('OnHide',function()
            w.parts,w.currentText,w.includeIdentity,w.copyValid={},'',false,false
            w.scopeMode='character';w.editor:SetText('');w.editor:ClearFocus();w.status:SetText('')
        end)
    end
    w.scopeMode,w.includeIdentity='character',false;w:Show();View.Generate()
end
