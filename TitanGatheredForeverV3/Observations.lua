local _, ns = ...
local Observations={}; Observations.__index=Observations; ns.Observations=Observations
local spells={ [2575]='Mining',[2576]='Mining',[3564]='Mining',[10248]='Mining',
    [2366]='Herbs',[2368]='Herbs',[3570]='Herbs',[11993]='Herbs',
    [8613]='Skinning',[8617]='Skinning',[8618]='Skinning',[10768]='Skinning',
    [7620]='Fishing',[7731]='Fishing',[7732]='Fishing',[18248]='Fishing',[13262]='Enchanting' }
function Observations.New(api) return setmetatable({api=api,seen={},order={},partial={},partialOrder={},serial=0},Observations) end
function Observations:Cancel(worldChanged)
    if worldChanged and (self.cast or self.loot)then self.ignoreLoot=true end
    self.cast,self.loot,self.failed=nil,nil,nil
end
function Observations:Status(message)if self.api.Trace then self.api.Trace(message)end end
function Observations:SuppressMap(mapID,kind)
    for _,pending in ipairs({self.cast or false,self.loot or false})do
        if pending and pending.position and pending.position.mapID==mapID then
            pending.suppressMaps=pending.suppressMaps or {};pending.suppressMaps[kind]=true
        end
    end
end
function Observations:Allowed(kind)
    local ok,value=pcall(self.api.CanRecord,kind);return ok and value==true
end
function Observations:Cast(event,unit,guid,spell)
    if unit~='player' then return end
    local kind=spells[spell]
    if not kind then if event=='UNIT_SPELLCAST_START' then self:Cancel()end;return end
    if event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_INTERRUPTED' then
        if kind~='Fishing' then self:Cancel();self.failed=true end;return
    end
    if not self.api.Active(kind) or not self:Allowed(kind) then self:Cancel();return end
    self.ignoreLoot=nil
    if not self.cast or self.cast.guid~=guid then
        self.cast={kind=kind,guid=guid,at=self.api.Now(),position=self.api.Position()};self.failed=nil
        if kind=='Enchanting' and self.api.Inputs then
            local ok,inputs=pcall(self.api.Inputs);if ok then self.cast.inputs=inputs end
        end
    end
    self:Status(kind .. ': ' .. event)
    if event=='UNIT_SPELLCAST_SUCCEEDED' then self.cast.succeeded=true;self:Finalize()end
end
function Observations:LootReady(fromItem)
    if self.ignoreLoot then return end
    local ok,slots=pcall(self.api.Loot);if not ok or type(slots)~='table'then return end
    if not self.loot then
        self.serial=self.serial+1
        self.loot={slots={},cast=self.cast,position=self.api.Position(),fishing=self.api.IsFishing and self.api.IsFishing(),serial=self.serial}
    end
    if fromItem then self.loot.fromItem=true end
    if self.api.IsFishing and self.api.IsFishing()then self.loot.fishing=true end
    for _,slot in ipairs(slots)do
        if type(slot.slot)=='number'then
            local prior=self.loot.slots[slot.slot]
            if not prior then self.loot.slots[slot.slot]=slot
            elseif prior.itemID==slot.itemID and type(slot.sources)=='table'and #slot.sources>0 then
                slot.cleared=prior.cleared;self.loot.slots[slot.slot]=slot
            end
        end
    end
end
function Observations:SlotCleared(slot)
    if self.loot and self.loot.slots[slot]then self.loot.slots[slot].cleared=true end
end
local function entry(guid)return guid:match('^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)')end
function Observations:LootClosed()
    if self.ignoreLoot then self.ignoreLoot=nil;return end
    if self.loot then self.loot.closed=true;self:Finalize()end
end
function Observations:Finalize()
    local loot=self.loot;if not loot or not loot.closed then return end
    local cast=loot.cast
    if cast and self.api.Now()-cast.at>45 then self:Cancel();self:Status('gathering context expired');return end
    if cast and loot.fishing then cast.succeeded=true end
    if cast and not cast.succeeded then return end
    self.loot,self.cast=nil,nil
    if loot.fromItem then
        for _,slot in pairs(loot.slots)do
            if not slot.sources or #slot.sources==0 then
                if cast and cast.kind=='Enchanting'then slot.sources={'Item-unknown-'..tostring(cast.guid)}
                else
                    slot.sources={'Item-unattributed-'..tostring(self.api.Timestamp())..':'..loot.serial}
                    slot.unattributed=true
                end
            end
        end
    end
    local sources={}
    local unreadable=false
    for _,slot in pairs(loot.slots)do if not slot.sources or #slot.sources==0 then unreadable=true end end
    for _,slot in pairs(loot.slots)do
        for _,guid in ipairs(slot.sources or {})do
            if type(guid)=='string'then
                local prior=not cast and self.partial[guid]
                local kind=prior and prior.kind or 'Loot'
                if loot.fishing then kind='Fishing'
                elseif cast and ((cast.kind=='Skinning' and guid:match('^Creature%-'))
                        or ((cast.kind=='Mining'or cast.kind=='Herbs')and guid:match('^GameObject%-'))
                        or (cast.kind=='Enchanting'and guid:match('^Item%-')))then kind=cast.kind end
                -- Do not relabel a failed/unconfirmed gather as ordinary container loot.
                local blocked=(self.failed or (cast and kind=='Loot'))and guid:match('^GameObject%-')
                if not blocked and (guid:match('^Creature%-')or guid:match('^GameObject%-')or kind=='Enchanting'or slot.unattributed)
                    and self.api.Active(kind) and self:Allowed(kind) then
                    local e=sources[guid]
                    if not e then
                        local source=prior and prior.source or entry(guid)or'unknown'
                        if kind=='Fishing'then source='catch'
                        elseif kind=='Enchanting'and not prior then
                            local input=cast and cast.inputs and cast.inputs[guid]
                            if not input and self.api.SourceItem then local ok,id=pcall(self.api.SourceItem,guid);if ok then input=id end end
                            source=tostring(input or 'unknown input')
                        end
                        local p=prior or (cast and kind==cast.kind and cast.position) or loot.position
                        e={id=prior and prior.id or guid,kind=kind,source=source,mapID=p and p.mapID,x=p and p.x,y=p and p.y,
                                at=self.api.Timestamp(),items={},qualities={},complete=true,instanceType=self.api.Context and self.api.Context()or'none'}
                        if kind=='Enchanting'then e.mapID,e.x,e.y,e.instanceType=0,nil,nil,'none' end
                        if slot.unattributed then e.mapID,e.x,e.y,e.source,e.complete=0,nil,nil,'unattributed item loot',false end
                        if kind~='Loot' and cast then e.id=guid..':'..tostring(cast.guid)
                        elseif kind=='Fishing'and not prior then e.id=guid..':catch:'..tostring(e.at)..':'..tostring(self.api.Now())..':'..loot.serial end
                        e.suppressMaps=loot.suppressMaps or (cast and cast.suppressMaps)
                        if self.api.SourceName then local ok,name=pcall(self.api.SourceName,guid);if ok then e.sourceName=name end end
                        sources[guid]=e
                    end
                    local quantity=slot.sourceQuantities and slot.sourceQuantities[guid]
                    if not quantity and #(slot.sources or{})==1 then quantity=slot.quantity end
                    if slot.unreadableItem then e.complete=false end
                    if not quantity or quantity<=0 then e.complete=false
                    elseif slot.cleared then
                        if type(slot.itemID)=='number'and (kind~='Loot'or self.api.Eligible(slot.itemID,slot.quality))then
                            e.items[slot.itemID]=(e.items[slot.itemID]or 0)+quantity
                            e.qualities[slot.itemID]=slot.quality
                        end
                    else e.complete=false end
                end
            end
        end
    end
    self.failed=nil
    if not next(sources)then self:Status('no eligible readable loot source')end
    for guid,e in pairs(sources)do
        if not self.seen[e.id]then
            if unreadable then e.complete=false end
            self.api.Commit(e)
            self:Status('recorded ' .. e.kind .. ' source ' .. tostring(e.source) .. (e.complete and '; complete sample' or '; partial loot'))
            if not e.complete then
                if not self.partial[guid]then self.partialOrder[#self.partialOrder+1]=guid end
                self.partial[guid]=e
                if #self.partialOrder>1024 then self.partial[table.remove(self.partialOrder,1)]=nil end
            else
                self.partial[guid]=nil
                self.seen[e.id]=true;self.order[#self.order+1]=e.id
                if #self.order>1024 then self.seen[table.remove(self.order,1)]=nil end
            end
        end
    end
end
