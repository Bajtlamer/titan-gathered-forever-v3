local _, ns = ...
local History = {}; History.__index = History; ns.History = History

function History.New(saved)
    if type(saved.characters) ~= 'table' then saved.characters = {} end
    return setmetatable({ saved = saved, revision = 0 }, History)
end

local function groupKey(e) return table.concat({e.kind, tostring(e.mapID or 0), tostring(e.source or 'unknown'), e.instanceType or 'none'}, ':') end

-- Source receipts are aggregated, not stored as an unlimited event journal.
function History:Observe(character, name, e)
    if not character or not e.id or type(e.items) ~= 'table' then return false end
    local c = self.saved.characters[character]
    if not c then c = { name=name, groups={}, items={}, recent={}, order={} }; self.saved.characters[character]=c end
    c.name = name
    c.scopes = c.scopes or {}
    local policy = e.policy or { key='all', all=true }
    c.scopes[policy.key] = c.scopes[policy.key] or policy
    local receipt = c.recent[e.id]
    if receipt and receipt.complete then return false end
    local key = receipt and receipt.key or groupKey(e)
    local g = c.groups[key]
    if not g then
        g = { kind=e.kind, source=e.source, mapID=e.mapID or 0, trials=0, items={}, x=e.x, y=e.y, sourceName=e.sourceName, instanceType=e.instanceType or 'none' }
        c.groups[key] = g
    end
    if not receipt then
        receipt = { key=key, items={}, policy=policy.key }; c.recent[e.id]=receipt; c.order[#c.order+1]=e.id
        if #c.order > 1024 then c.recent[table.remove(c.order,1)] = nil end
    end
    if receipt.policy ~= policy.key then receipt.scopeChanged = true end
    g.trialScopes = g.trialScopes or { all=g.trials }
    for itemID, quantity in pairs(e.items) do
        if type(itemID)=='number' and itemID>0 and type(quantity)=='number' and quantity>0 then
            local item = c.items[itemID] or { quantity=0 }; c.items[itemID]=item
            item.quantity, item.lastSeen, item.mapID, item.x, item.y = item.quantity+quantity, e.at, e.mapID, e.x, e.y
            local output = g.items[itemID] or { hits=0, quantity=0 }; g.items[itemID]=output
            output.quality = (e.qualities and e.qualities[itemID]) or output.quality
            receipt.items[itemID] = (receipt.items[itemID] or 0)+quantity
        end
    end
    if e.complete and not receipt.scopeChanged then
        g.trialScopes[receipt.policy] = (g.trialScopes[receipt.policy] or 0)+1
        g.trials = g.trials+1
        for itemID, quantity in pairs(receipt.items) do
            local output = g.items[itemID]
            output.hits, output.quantity = output.hits+1, output.quantity+quantity
        end
    end
    if e.complete then receipt.complete=true end
    if e.sourceName then g.sourceName=e.sourceName end
    g.lastSeen=e.at; self.revision=self.revision+1
    return true
end

function History:InvalidatePending(character)
    local c=self.saved.characters[character]
    if c then for _,receipt in pairs(c.recent)do if not receipt.complete then receipt.scopeChanged=true end end end
end

function History:Totals(character)
    local items={}
    for id,c in pairs(self.saved.characters) do
        if not character or character==id then
            for itemID,item in pairs(c.items) do
                local row=items[itemID] or { itemID=itemID, quantity=0, lastSeen=0 }; items[itemID]=row
                row.quantity=row.quantity+item.quantity
                if (item.lastSeen or 0)>=row.lastSeen then
                    row.lastSeen,row.mapID,row.x,row.y=item.lastSeen or 0,item.mapID,item.x,item.y
                end
            end
        end
    end
    local rows={}; for _,row in pairs(items) do rows[#rows+1]=row end
    table.sort(rows,function(a,b) return a.itemID<b.itemID end)
    return rows
end

function History:Total(character,itemID)
    local quantity=0
    for id,c in pairs(self.saved.characters)do
        if (not character or id==character)and c.items[itemID]then quantity=quantity+c.items[itemID].quantity end
    end
    return quantity
end

function History:Rates(character, wantedItem)
    local groups={}
    for id,c in pairs(self.saved.characters) do
        if not character or character==id then
            for key,g in pairs(c.groups) do
                if g.trials>0 then
                    local target=groups[key]
                    if not target then
                        target={kind=g.kind,source=g.source,mapID=g.mapID,items={},parts={},x=g.x,y=g.y,
                            sourceName=g.sourceName,instanceType=g.instanceType}
                        groups[key]=target
                    end
                    target.parts[#target.parts+1]={group=g,character=c}
                    for itemID,output in pairs(g.items) do
                        if not wantedItem or itemID==wantedItem then
                            local t=target.items[itemID] or {hits=0,quantity=0}; target.items[itemID]=t
                            t.hits,t.quantity=t.hits+output.hits,t.quantity+output.quantity
                            t.quality=output.quality or t.quality
                        end
                    end
                end
            end
        end
    end
    local rows={}
    for _,g in pairs(groups) do
        for itemID,output in pairs(g.items) do
            local trials=0
            for _,part in ipairs(g.parts) do
                local scopes=part.group.trialScopes
                if not scopes then trials=trials+part.group.trials
                else
                    for key,count in pairs(scopes)do
                        local policy=part.character.scopes and part.character.scopes[key]
                        if key=='all' or (policy and (policy.all or (policy.items and policy.items[itemID])
                            or (policy.rare and output.quality and output.quality>=3
                                and not (policy.knownItems and policy.knownItems[itemID]))))then trials=trials+count end
                    end
                end
            end
            if trials>0 and output.hits>0 then
                rows[#rows+1]={itemID=itemID,kind=g.kind,source=g.source,sourceName=g.sourceName,
                    instanceType=g.instanceType,mapID=g.mapID,x=g.x,y=g.y,hits=output.hits,
                    quantity=output.quantity,trials=trials,percent=output.hits/trials*100}
            end
        end
    end
    table.sort(rows,function(a,b)
        if a.itemID~=b.itemID then return a.itemID<b.itemID end
        if a.kind~=b.kind then return a.kind<b.kind end
        if a.mapID~=b.mapID then return a.mapID<b.mapID end
        if a.source~=b.source then return tostring(a.source)<tostring(b.source) end
        return tostring(a.instanceType)<tostring(b.instanceType)
    end)
    return rows
end

function History:ItemsFor(kind,character)
    local result={}
    for characterID,c in pairs(self.saved.characters) do
        if not character or characterID==character then
            for _,g in pairs(c.groups) do if g.kind==kind then for id in pairs(g.items) do result[id]=true end end end
        end
    end
    return result
end
