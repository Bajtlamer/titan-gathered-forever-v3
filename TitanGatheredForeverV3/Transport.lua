local _, ns = ...
local Transport = {}
ns.Transport = Transport

-- Boat and zeppelin routes of WoW Forever (source: the Method.gg travel route guide). The client does not report
-- dock positions, so each dock is recorded in game with /tgf dock <name> and stored in ns.db.docks.
Transport.docks = {
    'Stormwind Harbour', 'Auberdine', 'Menethil Harbor', 'Southshore', 'Theramore Isle', "Rut'theran Village",
    'Feathermoon Stronghold', 'Forgotten Coast', 'Orgrimmar', 'Undercity', "Grom'gol", 'Ratchet', 'Booty Bay',
    'Steamwheedle Port', 'Powderfuse Port',
}
Transport.routes = {
    { 'Stormwind Harbour', 'Auberdine', 'Alliance', 'boat' },
    { 'Auberdine', 'Menethil Harbor', 'Alliance', 'boat' },
    { 'Menethil Harbor', 'Southshore', 'Alliance', 'boat' },
    { 'Southshore', 'Auberdine', 'Alliance', 'boat' },
    { 'Menethil Harbor', 'Theramore Isle', 'Alliance', 'boat' },
    { "Rut'theran Village", 'Auberdine', 'Alliance', 'boat' },
    { 'Feathermoon Stronghold', 'Forgotten Coast', 'Alliance', 'boat' },
    { 'Orgrimmar', 'Undercity', 'Horde', 'zeppelin' },
    { 'Undercity', "Grom'gol", 'Horde', 'zeppelin' },
    { 'Orgrimmar', "Grom'gol", 'Horde', 'zeppelin' },
    { 'Ratchet', 'Booty Bay', 'Neutral', 'boat' },
    { 'Steamwheedle Port', 'Powderfuse Port', 'Neutral', 'boat' },
}
Transport.colors = { Alliance = { .25, .55, 1 }, Horde = { 1, .25, .25 }, Neutral = { 1, .82, .2 } }

local function number(value)
    return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
end

function Transport.Dock(name)
    local saved = ns.db and type(ns.db.docks) == 'table' and ns.db.docks[name]
    if type(saved) == 'table' and number(saved.map) and number(saved.x) and number(saved.y) then return saved end
end

-- Resolve a typed name (case-insensitive, unique prefix) to a dock name.
function Transport.Match(text)
    text = (text or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return nil, 'empty' end
    local found
    for _, name in ipairs(Transport.docks) do
        local lower = name:lower()
        if lower == text then return name end
        if lower:sub(1, #text) == text then
            if found then return nil, 'ambiguous' end
            found = name
        end
    end
    if found then return found end
    return nil, 'unknown'
end

function Transport.Record(name, mapID, x, y)
    if not ns.db or not number(mapID) or not number(x) or not number(y) or x < 0 or x > 1 or y < 0 or y > 1 then return false end
    if type(ns.db.docks) ~= 'table' then ns.db.docks = {} end
    ns.db.docks[name] = { map = mapID, x = x, y = y }
    if Transport.instance then Transport.instance.dirty = true end
    return true
end

function Transport.Forget(name)
    if ns.db and type(ns.db.docks) == 'table' then ns.db.docks[name] = nil end
    if Transport.instance then Transport.instance.dirty = true end
end

function Transport.Here()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
    local mapID = C_Map.GetBestMapForUnit('player')
    if not number(mapID) then return end
    local position = C_Map.GetPlayerMapPosition(mapID, 'player')
    if not position or not position.GetXY then return end
    local x, y = position:GetXY()
    if number(x) and number(y) then return mapID, x, y end
end

-- Convert a point of a map to the coordinates of an ancestor map by walking up the parents.
function Transport.ToMap(mapID, x, y, target)
    local guard = 0
    while mapID ~= target do
        guard = guard + 1
        if guard > 8 or not C_Map or not C_Map.GetMapInfo or not C_Map.GetMapRectOnMap then return end
        local info = C_Map.GetMapInfo(mapID)
        local parent = info and info.parentMapID
        if not number(parent) or parent <= 0 then return end
        local left, right, top, bottom = C_Map.GetMapRectOnMap(mapID, parent)
        if not (number(left) and number(right) and number(top) and number(bottom)) or right <= left or bottom <= top then return end
        x, y = left + x * (right - left), top + y * (bottom - top)
        mapID = parent
    end
    return x, y
end

-- Dashes along a segment in pixels. Returns a list of { x1, y1, x2, y2 }.
function Transport.Dashes(x1, y1, x2, y2, dash, gap)
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local result = {}
    if length <= 0 then return result end
    local step, at = dash + gap, 0
    while at < length and #result < 400 do
        local to = math.min(at + dash, length)
        result[#result + 1] = { x1 + dx * at / length, y1 + dy * at / length, x1 + dx * to / length, y1 + dy * to / length }
        at = at + step
    end
    return result
end

-- What to draw on a map: docks that fall on it and routes whose two ends both fall on it.
function Transport.Layout(mapID)
    local points, lines = {}, {}
    for _, name in ipairs(Transport.docks) do
        local dock = Transport.Dock(name)
        if dock then
            local x, y = Transport.ToMap(dock.map, dock.x, dock.y, mapID)
            if x then points[name] = { x = x, y = y, name = name, routes = {} } end
        end
    end
    for _, route in ipairs(Transport.routes) do
        local a, b = points[route[1]], points[route[2]]
        if a then a.routes[#a.routes + 1] = route end
        if b then b.routes[#b.routes + 1] = route end
        if a and b then lines[#lines + 1] = { a = a, b = b, route = route } end
    end
    return points, lines
end

local R = {}
R.__index = R

local function pointColor(point)
    local first = point.routes[1]
    local color = Transport.colors[first and first[3] or 'Neutral']
    for _, route in ipairs(point.routes) do if route[3] ~= first[3] then color = Transport.colors.Neutral end end
    return color
end

local function showTooltip(pin)
    local point = pin.point
    GameTooltip:SetOwner(pin, 'ANCHOR_RIGHT')
    GameTooltip:AddLine(point.name)
    for _, route in ipairs(point.routes) do
        local other = route[1] == point.name and route[2] or route[1]
        local oneWay = route[1] == point.name and ' to ' or ' from '
        GameTooltip:AddLine(route[3] .. ' ' .. route[4] .. oneWay .. other)
    end
    GameTooltip:Show()
end

function R:Hide()
    self.overlay:Hide()
    for _, line in ipairs(self.lines) do line:Hide() end
    for _, pin in ipairs(self.pins) do pin:Hide() end
end

function R:Refresh(force)
    local world = self.world
    if ns.settings.transportRoutes == false or not world:IsShown() then self:Hide(); return end
    local mapID, canvas = world:GetMapID(), world:GetCanvas()
    if not number(mapID) or not canvas then self:Hide(); return end
    local width, height = canvas:GetWidth(), canvas:GetHeight()
    if not number(width) or not number(height) or width <= 0 or height <= 0 then self:Hide(); return end
    if canvas ~= self.canvas then
        self.canvas = canvas
        self.overlay:SetParent(canvas)
        self.overlay:SetAllPoints(canvas)
        self.overlay:SetFrameLevel(canvas:GetFrameLevel() + 4)
    end
    if not (force or self.dirty or mapID ~= self.mapID or width ~= self.width or height ~= self.height) then return end
    self.mapID, self.width, self.height, self.dirty = mapID, width, height, nil
    local points, lines = Transport.Layout(mapID)
    self.overlay:Show()
    local scale = canvas:GetEffectiveScale()
    local dash, gap = 7 * (world:GetEffectiveScale() / scale), 6 * (world:GetEffectiveScale() / scale)
    local used = 0
    for _, entry in ipairs(lines) do
        local color = Transport.colors[entry.route[3]]
        for _, d in ipairs(Transport.Dashes(entry.a.x * width, entry.a.y * height, entry.b.x * width, entry.b.y * height, dash, gap)) do
            used = used + 1
            local line = self.lines[used]
            if not line then line = self.overlay:CreateLine(nil, 'ARTWORK'); self.lines[used] = line end
            line:SetThickness(2 * (world:GetEffectiveScale() / scale))
            line:SetColorTexture(color[1], color[2], color[3], .9)
            line:SetStartPoint('TOPLEFT', self.overlay, d[1], -d[2])
            line:SetEndPoint('TOPLEFT', self.overlay, d[3], -d[4])
            line:Show()
        end
    end
    for index = used + 1, #self.lines do self.lines[index]:Hide() end
    local count = 0
    local size = 9 * (world:GetEffectiveScale() / scale)
    for _, name in ipairs(Transport.docks) do
        local point = points[name]
        if point and #point.routes > 0 then
            count = count + 1
            local pin = self.pins[count]
            if not pin then
                pin = CreateFrame('Button', nil, self.overlay)
                pin.texture = pin:CreateTexture(nil, 'OVERLAY')
                pin.texture:SetAllPoints()
                pin:SetScript('OnEnter', showTooltip)
                pin:SetScript('OnLeave', function() GameTooltip:Hide() end)
                self.pins[count] = pin
            end
            local color = pointColor(point)
            pin.point = point
            pin:SetSize(size, size)
            pin.texture:SetColorTexture(color[1], color[2], color[3], 1)
            pin:ClearAllPoints()
            pin:SetPoint('CENTER', self.overlay, 'TOPLEFT', point.x * width, -point.y * height)
            pin:Show()
        end
    end
    for index = count + 1, #self.pins do self.pins[index]:Hide() end
    self.lineCount, self.pinCount = #lines, count
end

function Transport.New(world)
    local self = setmetatable({ world = world, lines = {}, pins = {} }, R)
    self.overlay = CreateFrame('Frame', nil, world:GetCanvas())
    local elapsed = 0
    self.overlay:SetScript('OnUpdate', function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= 0.25 then elapsed = 0; self:Refresh() end
    end)
    world:HookScript('OnShow', function() self:Refresh(true) end)
    world:HookScript('OnHide', function() self:Hide() end)
    self:Refresh(true)
    return self
end

function Transport.Attach()
    if not ns.settings or Transport.instance or not WorldMapFrame then return end
    Transport.instance = Transport.New(WorldMapFrame)
end

function Transport.Update()
    Transport.Attach()
    if Transport.instance then Transport.instance:Refresh(true) end
end

-- /tgf dock, /tgf dock <name>, /tgf dock forget <name>
function Transport.Command(argument)
    argument = argument or ''
    local forget = argument:match('^forget%s+(.+)$')
    if argument == '' then
        local recorded = 0
        for _, name in ipairs(Transport.docks) do
            local here = Transport.Dock(name)
            if here then recorded = recorded + 1 end
            ns.Print((here and 'recorded  ' or 'missing   ') .. name)
        end
        ns.Print(recorded .. ' of ' .. #Transport.docks .. ' docks recorded. Stand at the dock or tower and type /tgf dock <name>.')
        return
    end
    local name, problem = Transport.Match(forget or argument)
    if not name then
        ns.Print(problem == 'ambiguous' and 'More than one dock matches, type more of the name.' or 'Unknown dock. Type /tgf dock for the list.')
        return
    end
    if forget then Transport.Forget(name); ns.Print('Forgot ' .. name .. '.'); return end
    local mapID, x, y = Transport.Here()
    if not mapID or not Transport.Record(name, mapID, x, y) then ns.Print('Your position is not available here.'); return end
    ns.Print(string.format('Recorded %s: map %d, %.1f %.1f.', name, mapID, x * 100, y * 100))
end
