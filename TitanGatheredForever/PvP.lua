local _, ns = ...
local PvP={};PvP.__index=PvP;ns.PvP=PvP
local function public(value)return not ns.IsPublic or ns.IsPublic(value)end

local function integer(value)
    return type(value)=='number' and value==value and value>0 and value<math.huge and value==math.floor(value)
end
local function count(value)
    return type(value)=='number' and value==value and value>=0 and value<math.huge and value==math.floor(value)
end
local function escape(value)return(value:gsub('([%(%)%.%%%+%-%*%?%[%]%^%$])','%%%1'))end
local function formatPattern(formatString)
    if type(formatString)~='string'or formatString==''then return end
    local parts={'^'};local index=1
    while index<=#formatString do
        local char=formatString:sub(index,index)
        if char=='%'then
            local conversion=formatString:sub(index+1,index+1)
            if conversion=='s'then parts[#parts+1]='(.+)'
            elseif conversion=='d'or conversion=='i'then parts[#parts+1]='(%d+)'
            else return end
            index=index+2
        else
            local nextPercent=formatString:find('%',index,true)
            local finish=nextPercent and nextPercent-1 or #formatString
            parts[#parts+1]=escape(formatString:sub(index,finish));index=finish+1
        end
    end
    parts[#parts+1]='$'
    return table.concat(parts)
end

function PvP.ParseHonorMessage(message)
    local pattern=formatPattern(COMBATLOG_HONORGAIN)
    if type(message)~='string'or not pattern then return end
    local victim,rank,amount=message:match(pattern)
    amount=tonumber(amount)
    if type(victim)~='string'or victim==''or type(rank)~='string'or rank==''
        or not amount or amount<0 or amount~=math.floor(amount)then return end
    return victim,rank,amount
end
local contexts={none='world',pvp='battleground',arena='arena'}
local function flag(flags,mask)return bit and bit.band and bit.band(flags,mask)~=0 end
local function hostilePlayer(flags)
    if not public(flags)or type(flags)~='number' or not flag(flags,0x00000040) then return false end
    if flag(flags,0x00000400) then return true end
    return flag(flags,0x00000100) and flag(flags,0x00001000+0x00002000)
end
local function validPosition(position)
    return type(position)=='table'and integer(position.mapID)and type(position.x)=='number'and position.x==position.x
        and type(position.y)=='number'and position.y==position.y and position.x>=0 and position.x<=1 and position.y>=0 and position.y<=1
end
local function newStats(character,at)
    return {name=character,coverageBegan=at,worldKills=0,worldHonorEstimate=0,battlegroundKills=0,battlegroundHonorEstimate=0,
        arenaKills=0,arenaHonorEstimate=0,
        deaths={world=0,battleground=0,arena=0},recent={},order={}}
end
function PvP.New(saved,api)
    if type(saved)~='table'then saved={}end
    if not saved.schema then saved.schema=1 end
    if saved.schema==1 and type(saved.characters)~='table'then saved.characters={}end
    local self=setmetatable({saved=saved,api=api},PvP)
    if saved.schema==1 then self:CharacterStats(api.Character())end
    return self
end
function PvP:CharacterStats(character)
    if self.saved.schema~=1 or type(character)~='string'or character==''then return end
    local stats=self.saved.characters[character]
    if type(stats)~='table'then
        stats=newStats(self.api.Name and self.api.Name()or character,self.api.Timestamp())
        self.saved.characters[character]=stats
    end
    stats.name=self.api.Name and self.api.Name()or stats.name or character
    stats.worldKills=type(stats.worldKills)=='number'and stats.worldKills or 0
    stats.worldHonorEstimate=type(stats.worldHonorEstimate)=='number'and stats.worldHonorEstimate or 0
    stats.battlegroundKills=type(stats.battlegroundKills)=='number'and stats.battlegroundKills or 0
    stats.battlegroundHonorEstimate=type(stats.battlegroundHonorEstimate)=='number'and stats.battlegroundHonorEstimate or 0
    stats.arenaKills=type(stats.arenaKills)=='number'and stats.arenaKills or 0
    stats.arenaHonorEstimate=type(stats.arenaHonorEstimate)=='number'and stats.arenaHonorEstimate or 0
    if type(stats.deaths)~='table'then stats.deaths={}end
    for _,key in pairs(contexts)do if type(stats.deaths[key])~='number'then stats.deaths[key]=0 end end
    if type(stats.recent)~='table'then stats.recent={}end
    if type(stats.order)~='table'then stats.order={}end
    return stats
end
local function seen(stats,token)
    if type(token)~='string'or token==''then return false end
    if stats.recent[token]then return true end
    stats.recent[token]=true;stats.order[#stats.order+1]=token
    if #stats.order>128 then stats.recent[table.remove(stats.order,1)]=nil end
    return false
end
function PvP:HonorMessage(message,location)
    local victim,rank,amount=PvP.ParseHonorMessage(message)
    if not victim or type(location)~='table'then return end
    local field=location.context=='none' and 'world' or location.context=='pvp' and 'battleground' or location.context=='arena' and 'arena'
    if not field then return end
    local character=self.api.Character();local stats=self:CharacterStats(character)
    if not stats or seen(stats,location.eventToken)then return end
    local killsKey=field..'Kills';local honorKey=field..'HonorEstimate'
    stats[killsKey]=stats[killsKey]+1;stats[honorKey]=stats[honorKey]+amount
    stats.lastHonorKill=self.api.Timestamp()
    if field=='world' then stats.lastWorldKill=stats.lastHonorKill end
    if self.api.Changed then self.api.Changed()end
    return {victim=victim,rank=rank,estimatedHonor=amount,
        position=field=='world' and validPosition(location)and{mapID=location.mapID,x=location.x,y=location.y}or nil,
        context=field,at=stats.lastHonorKill}
end
function PvP:Death(eventData,context)
    if self.saved.schema~=1 or type(eventData)~='table'or eventData.playerCaused~=true
        or type(eventData.killer)~='string'or eventData.killer==''then return false end
    local key=contexts[context];if not key then return false end
    local stats=self:CharacterStats(self.api.Character());if not stats then return false end
    if seen(stats,eventData.eventToken)then return false end
    stats.deaths[key]=stats.deaths[key]+1;stats.lastDeath=self.api.Timestamp()
    if self.api.Changed then self.api.Changed()end
    return true
end
function PvP:DeathRecap(events,context,eventToken)
    if type(events)~='table'or not contexts[context] then return false end
    local lethalPlayer
    local function inspect(entry)
        if type(entry)~='table' then return end
        local overkill,sourceName=entry.overkill,entry.sourceName
        if public(overkill)and public(sourceName)and type(overkill)=='number' and overkill>=0 and hostilePlayer(entry.sourceFlags)
            and type(sourceName)=='string' and sourceName~='' then lethalPlayer=sourceName end
    end
    for _,entry in ipairs(events)do
        if type(entry)=='table' and entry.sourceFlags~=nil then inspect(entry)
        elseif type(entry)=='table' then for _,hit in ipairs(entry)do inspect(hit)end end
    end
    if not lethalPlayer then return false end
    return self:Death({playerCaused=true,killer=lethalPlayer,eventToken=eventToken},context)
end
function PvP:Snapshot(character)
    local row={worldKills=0,worldHonorEstimate=0,battlegroundKills=0,battlegroundHonorEstimate=0,
        arenaKills=0,arenaHonorEstimate=0,deaths={world=0,battleground=0,arena=0,total=0}}
    local began
    for id,stats in pairs(self.saved.characters or{})do
        if not character or id==character then
            row.worldKills=row.worldKills+(stats.worldKills or 0)
            row.worldHonorEstimate=row.worldHonorEstimate+(stats.worldHonorEstimate or 0)
            row.battlegroundKills=row.battlegroundKills+(stats.battlegroundKills or 0)
            row.battlegroundHonorEstimate=row.battlegroundHonorEstimate+(stats.battlegroundHonorEstimate or 0)
            row.arenaKills=row.arenaKills+(stats.arenaKills or 0)
            row.arenaHonorEstimate=row.arenaHonorEstimate+(stats.arenaHonorEstimate or 0)
            for _,key in pairs(contexts)do row.deaths[key]=row.deaths[key]+(stats.deaths and stats.deaths[key]or 0)end
            if stats.coverageBegan then began=math.min(began or stats.coverageBegan,stats.coverageBegan)end
        end
    end
    row.deaths.total=row.deaths.world+row.deaths.battleground+row.deaths.arena
    row.coverageBegan=began
    if (not character or character==self.api.Character()) and self.api.LifetimeStats then
        local ok,kills,rank=pcall(self.api.LifetimeStats)
        if ok and count(kills) then row.lifetimeHonorableKills=kills end
        if ok and count(rank) then
            row.highestRankID=rank
            if self.api.RankName then
                local nameOK,name=pcall(self.api.RankName,rank)
                if nameOK and type(name)=='string' and name~='' then row.highestRankName=name end
            end
        end
    end
    if (not character or character==self.api.Character()) and self.api.CurrentRank then
        local ok,rankID,rankName=pcall(self.api.CurrentRank)
        if ok and count(rankID) then row.currentRankID=rankID end
        if ok and type(rankName)=='string' and rankName~='' then row.currentRankName=rankName end
    end
    return row
end
