local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end
local function near(a, b) assert(math.abs(a - b) < 0.01, tostring(a) .. ' != ' .. tostring(b)) end

local frames
local function frame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, scripts = {}, shown = true, textures = {}, point = nil,
        width = 0, height = 0, scale = 1 }
    function f:SetSize(w, h) self.width, self.height = w, h end
    function f:GetWidth() return self.width end
    function f:GetHeight() return self.height end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetFrameLevel() end
    function f:ClearAllPoints() self.point = nil end
    function f:SetPoint(...) self.point = { ... } end
    function f:GetEffectiveScale() return self.scale end
    function f:GetCenter() return self.cx, self.cy end
    function f:RegisterForClicks(...) self.clicks = { ... } end
    function f:RegisterForDrag(...) self.drag = { ... } end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(value) self.shown = value and true or false end
    function f:IsShown() return self.shown end
    function f:CreateTexture()
        local t = { SetTexture = function(self, v) self.path = v end, SetSize = function() end, SetPoint = function() end,
            SetAllPoints = function() end, SetTexCoord = function() end, AddMaskTexture = function(self, m) self.mask = m end }
        self.textures[#self.textures + 1] = t
        return t
    end
    function f:CreateMaskTexture() return { SetTexture = function() end, SetAllPoints = function() end } end
    frames[#frames + 1] = f
    return f
end

local cursor = { x = 0, y = 0 }
local function env(settings)
    frames = {}
    CreateFrame = function(kind, name, parent) return frame(kind, name, parent) end
    UIParent = frame('Frame', 'UIParent')
    Minimap = frame('Frame', 'Minimap'); Minimap.width, Minimap.height, Minimap.cx, Minimap.cy = 140, 140, 500, 400
    GetCursorPosition = function() return cursor.x, cursor.y end
    local lines = {}
    GameTooltip = { SetOwner = function(_, owner, anchor) lines.owner, lines.anchor = owner, anchor end,
        AddLine = function(_, text) lines[#lines + 1] = text end, Show = function() lines.shown = true end,
        Hide = function() lines.shown = false end }
    local ns = { settings = settings or { showMinimapButton = true, minimapButtonAngle = 205 }, IsPublic = function() return true end,
        Style = { gold = 'gold', gray = 'gray', Text = function(color, text) return '<' .. color .. '>' .. text .. '</>' end },
        calls = { browser = 0 } }
    ns.RecipeBrowser = { Toggle = function() ns.calls.browser = ns.calls.browser + 1 end }
    ns.Titan = { Menu = function(owner) ns.calls.menuOwner = owner end }
    assert(loadfile('TitanGatheredForeverV3/MinimapButton.lua'))('TitanGatheredForeverV3', ns)
    return ns, lines
end

test('the button sits on the minimap edge at the saved angle', function()
    local ns = env()
    local x, y = ns.MinimapButton.Position(0, 140, 140)
    near(x, 92); near(y, 0)
    x, y = ns.MinimapButton.Position(90, 140, 140); near(x, 0); near(y, 92)
    x, y = ns.MinimapButton.Position(180, 100, 80); near(x, -72); near(y, 0)
    ns.MinimapButton.Attach()
    local button = ns.MinimapButton.button
    assert(button, 'button not created')
    eq(button.point[1], 'CENTER'); eq(button.point[2], Minimap); eq(button.point[3], 'CENTER')
    near(button.point[4], math.cos(math.rad(205)) * 92); near(button.point[5], math.sin(math.rad(205)) * 92)
    eq(button.strata, 'MEDIUM'); eq(button.width, 32)
end)

test('the angle follows the cursor around the minimap center', function()
    local ns = env()
    near(ns.MinimapButton.AngleFromCursor(600, 500, 500, 500), 0)
    near(ns.MinimapButton.AngleFromCursor(500, 600, 500, 500), 90)
    near(ns.MinimapButton.AngleFromCursor(400, 500, 500, 500), 180)
    near(ns.MinimapButton.AngleFromCursor(500, 400, 500, 500), 270)
    near(ns.MinimapButton.AngleFromCursor(600, 600, 500, 500), 45)
end)

test('left click toggles the recipes window and right click opens the menu', function()
    local ns = env()
    ns.MinimapButton.Attach()
    local button = ns.MinimapButton.button
    eq(button.clicks[1], 'LeftButtonUp'); eq(button.clicks[2], 'RightButtonUp'); eq(button.drag[1], 'LeftButton')
    button.scripts.OnClick(button, 'LeftButton'); eq(ns.calls.browser, 1)
    button.scripts.OnClick(button, 'LeftButton'); eq(ns.calls.browser, 2)
    button.scripts.OnClick(button, 'RightButton'); eq(ns.calls.menuOwner, button); eq(ns.calls.browser, 2)
end)

test('the tooltip explains the clicks', function()
    local ns, lines = env()
    ns.MinimapButton.Attach()
    local button = ns.MinimapButton.button
    button.scripts.OnEnter(button)
    eq(lines.owner, button); eq(lines.shown, true)
    eq(lines[1], '<gold>Titan Gathered Forever v3</>')
    local text = table.concat(lines, '|')
    assert(text:find('Left click', 1, true) and text:find('unlearned recipes', 1, true))
    assert(text:find('Right click', 1, true) and text:find('Drag', 1, true))
    button.scripts.OnLeave(button); eq(lines.shown, false)
end)

test('dragging moves the button around the edge and saves the angle', function()
    local ns = env()
    ns.MinimapButton.Attach()
    local button = ns.MinimapButton.button
    button.scripts.OnDragStart(button)
    assert(button.scripts.OnUpdate, 'dragging does not follow the cursor')
    cursor.x, cursor.y = 500, 800   -- straight above the minimap center (500, 400)
    button.scripts.OnUpdate(button)
    near(ns.settings.minimapButtonAngle, 90)
    near(button.point[4], 0); near(button.point[5], 92)
    button.scripts.OnDragStop(button)
    eq(button.scripts.OnUpdate, nil)
    cursor.x, cursor.y = 0, 0
    near(ns.settings.minimapButtonAngle, 90)
end)

test('the button can be hidden from the menu setting', function()
    local ns = env({ showMinimapButton = false, minimapButtonAngle = 205 })
    ns.MinimapButton.Attach()
    eq(ns.MinimapButton.button.shown, false)
    ns.settings.showMinimapButton = true; ns.MinimapButton.Update()
    eq(ns.MinimapButton.button.shown, true)
    ns.settings.showMinimapButton = false; ns.MinimapButton.Update()
    eq(ns.MinimapButton.button.shown, false)
end)

test('nothing is created without a minimap', function()
    local ns = env()
    Minimap = nil
    ns.MinimapButton.Attach()
    eq(ns.MinimapButton.button, nil)
    ns.MinimapButton.Update()
end)

test('settings defaults keep explicit choices and repair invalid angles', function()
    local ns = {}
    assert(loadfile('TitanGatheredForeverV3/Settings.lua'))('TitanGatheredForeverV3', ns)
    local _, settings = ns.Settings.Initialize({ schema = 1 })
    eq(settings.showMinimapButton, true); eq(settings.minimapButtonAngle, 205)
    _, settings = ns.Settings.Initialize({ schema = 1, settings = { showMinimapButton = false, minimapButtonAngle = 33 } })
    eq(settings.showMinimapButton, false); eq(settings.minimapButtonAngle, 33)
    _, settings = ns.Settings.Initialize({ schema = 1, settings = { minimapButtonAngle = 'bad' } })
    eq(settings.minimapButtonAngle, 205)
    _, settings = ns.Settings.Initialize({ schema = 1, settings = { minimapButtonAngle = 1 / 0 } })
    eq(settings.minimapButtonAngle, 205)
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS minimap button ' .. #tests .. ' checks')
