local _, ns = ...
local Actions = {}; Actions.__index = Actions; ns.Actions = Actions
Actions.labels={Mining='Mining',Herbs='Herbalism',Skinning='Skinning',Fishing='Fishing',Enchanting='Disenchanting'}
local spells = { [2575]='Mining', [2576]='Mining', [3564]='Mining', [10248]='Mining',
    [2366]='Herbs', [2368]='Herbs', [3570]='Herbs', [11993]='Herbs',
    [8613]='Skinning', [8617]='Skinning', [8618]='Skinning', [10768]='Skinning',
    [7620]='Fishing', [7731]='Fishing', [7732]='Fishing', [18248]='Fishing', [13262]='Enchanting' }
local starts = { UNIT_SPELLCAST_START=true, UNIT_SPELLCAST_CHANNEL_START=true }
local results = { UNIT_SPELLCAST_FAILED='failed', UNIT_SPELLCAST_INTERRUPTED='interrupted',
    UNIT_SPELLCAST_STOP='stopped', UNIT_SPELLCAST_CHANNEL_STOP='stopped' }
local fields = { 'completed', 'failed', 'interrupted', 'stopped' }
local function seal(saved)
    for _, c in pairs(saved.characters) do
        for _, receipt in pairs(c.recent) do receipt.sealed = true end
    end
end
function Actions.New(saved, api)
    if not saved.schema then saved.schema=1 end
    if saved.schema==1 then
        if type(saved.characters)~='table' then saved.characters={} end
        seal(saved)
    end
    return setmetatable({saved=saved,api=api},Actions)
end
function Actions:Pause()
    if self.saved.schema==1 then seal(self.saved) end
    self.current=nil
end
function Actions.Enabled(kind)
    local s=ns.settings
    return s and s.recordActions and Actions.labels[kind]~=nil and ns.Catalog.modules[kind]~=nil
        and s.categories[kind]~=false and s.actionProfessions[kind]~=false
end
function Actions.SettingsChanged()
    local parts={tostring(ns.settings.recordActions)}
    for _,kind in ipairs({'Mining','Herbs','Skinning','Fishing','Enchanting'}) do
        parts[#parts+1]=tostring(Actions.Enabled(kind))
    end
    local signature=table.concat(parts,':')
    if Actions.signature and Actions.signature~=signature and ns.actions then ns.actions:Pause() end
    Actions.signature=signature
end
function Actions:Change(c, receipt, outcome)
    if receipt.outcome=='completed' or receipt.outcome==outcome then return end
    -- A stop is provisional. It must not overwrite a specific failure/interrupt.
    if outcome=='stopped' and receipt.outcome then return end
    if outcome~='completed' and receipt.outcome and receipt.outcome~='stopped' then return end
    local row=c.kinds[receipt.kind]
    if receipt.outcome then row[receipt.outcome]=row[receipt.outcome]-1 end
    receipt.outcome=outcome; row[outcome]=row[outcome]+1
end
function Actions:Supersede(guid)
    local current=self.current
    if current and current.guid~=guid then
        local c=self.saved.characters[current.character]
        if c and c.recent[current.guid] then c.recent[current.guid].catchClosed=true end
        self.current=nil
    end
end
function Actions:Cast(event, unit, guid, spell)
    if self.saved.schema~=1 or unit~='player' then return end
    if type(guid)~='string' or guid=='' then return end
    local character=self.api.Character(); if not character then return end
    local c=self.saved.characters[character]
    local receipt=c and c.recent[guid]
    if receipt and (receipt.sealed or (receipt.catchClosed and starts[event])) then return end
    if starts[event] then self:Supersede(guid) end
    local kind=spells[spell]
    if not kind or not self.api.Enabled(kind) then return end
    if not starts[event] and not results[event] and event~='UNIT_SPELLCAST_SUCCEEDED' then return end
    if not c then c={name=self.api.Name(),kinds={},recent={},order={}};self.saved.characters[character]=c end
    if receipt and (receipt.sealed or receipt.kind~=kind) then return end
    local at=self.api.Timestamp()
    if not receipt then
        if results[event]=='stopped' then return end
        self:Supersede(guid)
        local row=c.kinds[kind]
        if not row then
            row={kind=kind,began=at,attempts=0,completed=0,failed=0,interrupted=0,stopped=0}
            c.kinds[kind]=row
        end
        receipt={kind=kind,at=self.api.Now()};c.recent[guid]=receipt;c.order[#c.order+1]=guid
        row.attempts=row.attempts+1
        if #c.order>1024 then c.recent[table.remove(c.order,1)]=nil end
    end
    c.name=self.api.Name();c.kinds[kind].lastSeen=at
    if kind=='Fishing' and not receipt.catchClosed and (starts[event] or event=='UNIT_SPELLCAST_SUCCEEDED') then
        self.current={character=character,guid=guid}
    end
    if event=='UNIT_SPELLCAST_SUCCEEDED' and kind~='Fishing' then self:Change(c,receipt,'completed')
    elseif results[event] then self:Change(c,receipt,results[event]) end
    if self.api.Changed then self.api.Changed() end
end
function Actions:FishingLoot()
    local current=self.current; if not current or not self.api.Enabled('Fishing') then return end
    if current.character~=self.api.Character() then self.current=nil;return end
    local c=self.saved.characters[current.character]
    local receipt=c and c.recent[current.guid]
    if not receipt or receipt.sealed or self.api.Now()-receipt.at>45 then self.current=nil;return end
    self:Change(c,receipt,'completed');c.kinds.Fishing.lastSeen=self.api.Timestamp()
    if self.api.Changed then self.api.Changed() end
end
function Actions:Rows(character)
    local combined={}
    if self.saved.schema~=1 then return {} end
    for id,c in pairs(self.saved.characters) do
        if not character or character==id then
            for kind,source in pairs(c.kinds) do
                local row=combined[kind]
                if not row then
                    row={kind=kind,began=source.began,lastSeen=0,attempts=0,completed=0,failed=0,interrupted=0,stopped=0}
                    combined[kind]=row
                end
                row.began=math.min(row.began,source.began);row.lastSeen=math.max(row.lastSeen,source.lastSeen or 0)
                row.attempts=row.attempts+source.attempts
                for _,field in ipairs(fields) do row[field]=row[field]+source[field] end
            end
        end
    end
    local rows={}
    for _,row in pairs(combined) do
        row.unresolved=row.attempts-row.completed-row.failed-row.interrupted-row.stopped
        rows[#rows+1]=row
    end
    table.sort(rows,function(a,b)return a.kind<b.kind end)
    return rows
end
