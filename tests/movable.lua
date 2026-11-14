local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function window()
    local f = { hooks = {}, points = {}, calls = {}, shown = false }
    function f:SetMovable(v) self.movable = v end
    function f:EnableMouse(v) self.mouse = v end
    function f:SetClampedToScreen(v) self.clamped = v end
    function f:RegisterForDrag(button) self.drag = button end
    function f:HookScript(name, fn) self.hooks[name] = fn end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
    function f:IsShown() return self.shown end
    function f:ClearAllPoints() self.calls.cleared = (self.calls.cleared or 0) + 1 end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:GetPoint() return unpack(self.stored or {}) end
    return f
end

local function fresh()
    local ns = { db = {}, settings = {} }
    UIParent = {}
    C_Timer = { After = function(_, fn) fn() end }
    _G.ProfessionsFrame, _G.AuctionHouseFrame = nil, nil
    assert(loadfile('TitanGatheredForeverV3/Navigation.lua'))('TitanGatheredForeverV3', ns)
    assert(loadfile('TitanGatheredForeverV3/Movable.lua'))('TitanGatheredForeverV3', ns)
    return ns
end

test('a window of the client becomes movable when it exists, once', function()
    local ns = fresh()
    ns.Movable.AttachAll()                                           -- neither window exists yet: nothing happens
    eq(next(ns.db.windowPositions or {}), nil)
    local professions = window(); _G.ProfessionsFrame = professions
    ns.Movable.AttachAll()
    eq(professions.movable, true); eq(professions.mouse, true); eq(professions.clamped, true); eq(professions.drag, 'LeftButton')
    local hooks = professions.hooks
    ns.Movable.AttachAll(); eq(professions.hooks, hooks)             -- a second call does not hook again
    eq(_G.AuctionHouseFrame, nil)
end)

test('dragging moves the window and keeps its position, which is put back whenever the window is shown', function()
    local ns = fresh()
    local professions = window(); _G.ProfessionsFrame = professions
    ns.Movable.AttachAll()
    professions.hooks.OnDragStart(professions); eq(professions.moving, true)
    professions.stored = { 'TOPLEFT', UIParent, 'BOTTOMLEFT', 40, 900 }
    professions.hooks.OnDragStop(professions); eq(professions.moving, false)
    local saved = ns.db.windowPositions.professions
    eq(saved[1], 'TOPLEFT'); eq(saved[2], 'BOTTOMLEFT'); eq(saved[3], 40); eq(saved[4], 900)
    professions.points = {}
    professions.hooks.OnShow(professions)                            -- the client laid the window out again
    eq(#professions.points, 1); eq(professions.points[1][1], 'TOPLEFT'); eq(professions.points[1][4], 40)
    -- the same place is used by a window that already was on screen when it was attached
    ns = fresh(); ns.db.windowPositions = { auctionHouse = { 'CENTER', 'CENTER', 5, 6 } }
    local house = window(); house.shown = true; _G.AuctionHouseFrame = house
    ns.Movable.AttachAll(); eq(#house.points, 1); eq(house.points[1][4], 5)
end)

test('with the switch off the windows are left to the client', function()
    local ns = fresh()
    ns.settings.moveBlizzard = false
    ns.db.windowPositions = { professions = { 'CENTER', 'CENTER', 1, 2 } }
    local professions = window(); professions.shown = true; _G.ProfessionsFrame = professions
    ns.Movable.AttachAll()
    eq(#professions.points, 0)                                       -- no saved place is applied
    professions.hooks.OnDragStart(professions); eq(professions.moving, nil)
    professions.stored = { 'TOPLEFT', UIParent, 'BOTTOMLEFT', 40, 900 }
    professions.hooks.OnDragStop(professions)
    eq(ns.db.windowPositions.professions[3], 1)                      -- the old position is not overwritten
    professions.hooks.OnShow(professions); eq(#professions.points, 0)
end)

test('initializing watches for the load of the window, and the client layout hook restores the places', function()
    local ns = fresh()
    local events, scripts, layout = {}, {}, nil
    CreateFrame = function()
        local f = { }
        function f:RegisterEvent(e) events[#events + 1] = e end
        function f:SetScript(name, fn) scripts[name] = fn end
        return f
    end
    _G.UpdateUIPanelPositions = function() end
    hooksecurefunc = function(name, fn) if name == 'UpdateUIPanelPositions' then layout = fn end end
    ns.Movable.Initialize()
    eq(#events, 4); eq(events[2], 'AUCTION_HOUSE_SHOW'); assert(layout)
    local house = window(); _G.AuctionHouseFrame = house
    scripts.OnEvent(nil, 'AUCTION_HOUSE_SHOW'); eq(house.movable, true)              -- found when it opens
    ns.db.windowPositions = { auctionHouse = { 'TOP', 'TOP', 0, -50 } }
    house.shown = true; layout(); eq(#house.points, 1); eq(house.points[1][4], 0)    -- laid out again: put back
    house.shown = false; layout(); eq(#house.points, 1)                               -- a hidden window is left alone
    ns.Movable.Initialize()                                                            -- a second initialization changes nothing
    eq(#events, 4)
    _G.UpdateUIPanelPositions, hooksecurefunc, CreateFrame = nil, nil, nil
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS movable ' .. #tests .. ' checks')
