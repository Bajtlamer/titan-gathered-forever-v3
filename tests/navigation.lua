local passed = 0
local function eq(a, b) assert(a == b, 'expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
local function test(name, fn) local ok, err = pcall(fn); if not ok then error(name .. ': ' .. err) end; passed = passed + 1 end

local function frame(template)
    local f = { scripts = {}, template = template, shown = true, calls = {} }
    for _, m in ipairs({ 'SetSize', 'SetPoint', 'SetWidth', 'SetID', 'LockHighlight', 'ClearAllPoints' }) do
        f[m] = function(self, ...) self.calls[m] = { ... } end
    end
    function f:SetText(v) self.text = v end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:Hide() self.shown = false end
    function f:Show() self.shown = true end
    return f
end
local function load()
    local ns = {}
    assert(loadfile('TitanGatheredForever/Navigation.lua'))('TitanGatheredForever', ns)
    return ns
end
local state = { choice = false }
local function options() return { { value = false, label = 'All professions' }, { value = 'Alchemy', label = 'Alchemy' } } end

test('the combo box uses the Blizzard drop down with one radio choice per option', function()
    local menus = {}
    CreateFrame = function(kind, _, _, template)
        local f = frame(template)
        if template == 'WowStyle1DropdownTemplate' then
            function f:SetupMenu(builder)
                local root = { radios = {} }
                function root:CreateRadio(label, selected, set) self.radios[#self.radios + 1] = { label, selected, set } end
                builder(self, root); menus[#menus + 1] = root
            end
            function f:GenerateMenu() self.generated = (self.generated or 0) + 1 end
        end
        return f
    end
    local ns = load()
    local chosen
    local drop = ns.Nav.Dropdown(frame(), 175, -65, 190, options, function() return state.choice end, function(v) chosen = v end)
    eq(drop.template, 'WowStyle1DropdownTemplate'); eq(drop.calls.SetWidth[1], 190)
    local radios = menus[1].radios
    eq(#radios, 2); eq(radios[1][1], 'All professions'); eq(radios[1][2](), true); eq(radios[2][2](), false)
    radios[2][3](); eq(chosen, 'Alchemy')
    drop.Sync(); eq(drop.generated, 1)
end)

test('without the drop down template the combo box is a button with a context menu', function()
    CreateFrame = function(kind, _, _, template)
        if template == 'WowStyle1DropdownTemplate' then error('unknown template') end
        return frame(template)
    end
    local clicked
    MenuUtil = { CreateContextMenu = function(owner, fn)
        fn(owner, { CreateButton = function(_, label, cb) clicked = clicked or {}; clicked[label] = cb end }) end }
    local ns = load()
    state.choice = 'Alchemy'
    local picked
    local button = ns.Nav.Dropdown(frame(), 0, 0, 100, options, function() return state.choice end, function(v) picked = v; state.choice = v end)
    eq(button.text, 'Alchemy')
    button.scripts.OnClick(button); clicked['All professions'](); eq(picked, false); eq(button.text, 'All professions')
end)

test('tabs use the classic panel tab template and select the active tab', function()
    local numTabs, selected
    PanelTemplates_SetNumTabs = function(_, n) numTabs = n end
    PanelTemplates_SetTab = function(_, i) selected = i end
    CreateFrame = function(_, _, _, template) return frame(template) end
    local ns = load()
    ns.RecipeBrowser, ns.Reports = nil, nil
    local window = frame()
    ns.Nav.Tabs(window, 'chances')
    eq(numTabs, #ns.Nav.tabs); eq(selected, 5); eq(ns.Nav.tabs[1].id, 'materials'); eq(window.tabButtons.pvp.template, 'PanelTabButtonTemplate')
    eq(#window.Tabs, #ns.Nav.tabs); eq(window.Tabs[2].calls.SetID[1], 2)
    eq(window.tabButtons.economy.text, 'Economy')
    eq(window.tabButtons.production, nil)
    -- Tab widths are measured again when the window is shown, right away and a moment later.
    local resized, timers = 0, {}
    local textWidth
    PanelTemplates_TabResize = function(tab, _, _, _, _, width) resized = resized + 1; if tab == window.Tabs[1] then textWidth = width end end
    local order = {}
    window.Tabs[1].Text = { SetWidth = function(_, w) order[#order + 1] = 'set' .. w end,
        GetStringWidth = function() order[#order + 1] = 'get'; return 77 end }
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    window.IsShown = function() return true end
    resized, timers = 0, {}
    window.scripts.OnShow()
    eq(resized, #ns.Nav.tabs); eq(textWidth, 77)
    eq(order[1], 'set0'); eq(order[2], 'get')                -- the fixed text width goes first, then the measuring; eq(#timers, 3)
    timers[1](); eq(resized, 2 * #ns.Nav.tabs)
    timers[3](); eq(resized, 3 * #ns.Nav.tabs)
    PanelTemplates_TabResize, C_Timer = nil, nil
    -- A frame that is already shown never fires OnShow for its first Show, so the tabs measure at creation too.
    local created = 0
    PanelTemplates_TabResize = function() created = created + 1 end
    C_Timer = { After = function() end }
    local fresh = frame(); fresh.IsShown = function() return true end
    ns.Nav.Tabs(fresh, 'recipes')
    eq(created, #ns.Nav.tabs)
    PanelTemplates_TabResize, C_Timer = nil, nil
end)

test('tabs fall back to buttons when the panel tab template is missing', function()
    PanelTemplates_SetNumTabs, PanelTemplates_SetTab = function() end, function() end
    CreateFrame = function(_, _, _, template)
        if template == 'PanelTabButtonTemplate' then error('unknown template') end
        return frame(template)
    end
    local ns = load()
    local window = frame()
    ns.Nav.Tabs(window, 'history')
    eq(window.tabButtons.history.template, 'UIPanelButtonTemplate'); eq(window.tabButtons.pvp.template, 'UIPanelButtonTemplate')
    PanelTemplates_SetNumTabs, PanelTemplates_SetTab = nil, nil
    window = frame(); ns.Nav.Tabs(window, 'history')
    eq(window.tabButtons.history.template, 'UIPanelButtonTemplate')
end)

test('a moved window is saved with its position and put back where it was left, also in the saved variables', function()
    UIParent = {}
    local ns = load()
    ns.db = {}
    local function movable()
        local f = frame()
        f.points = {}
        function f:GetPoint() return unpack(self.stored or {}) end
        function f:SetPoint(point, relativeTo, relativePoint, x, y) self.points[#self.points + 1] = { point, relativeTo, relativePoint, x, y } end
        function f:StartMoving() self.moving = true end
        function f:StopMovingOrSizing() self.moving = false end
        return f
    end
    local window = movable()
    ns.Nav.Draggable(window, 'recipe')
    eq(#window.points, 0)                                                     -- nothing saved yet: the window keeps its default place
    window.scripts.OnDragStart(window); eq(window.moving, true)
    window.stored = { 'TOPLEFT', UIParent, 'BOTTOMLEFT', 120.5, 800 }
    window.scripts.OnDragStop(window); eq(window.moving, false)
    local saved = ns.db.windowPositions.recipe
    eq(saved[1], 'TOPLEFT'); eq(saved[2], 'BOTTOMLEFT'); eq(saved[3], 120.5); eq(saved[4], 800)
    local reopened = movable()                                                  -- a new window of the next session
    ns.Nav.Draggable(reopened, 'recipe')
    eq(#reopened.points, 1); eq(reopened.points[1][1], 'TOPLEFT'); eq(reopened.points[1][2], UIParent)
    eq(reopened.points[1][3], 'BOTTOMLEFT'); eq(reopened.points[1][4], 120.5); eq(reopened.points[1][5], 800)
    local other = movable(); ns.Nav.Draggable(other, 'export'); eq(#other.points, 0)   -- every window has its own place
    ns.db.windowPositions.broken = { 'CENTER', 'CENTER', 'x', 0 }
    local third = movable(); eq(ns.Nav.RestorePosition('broken', third), false); eq(#third.points, 0)
    eq(ns.Nav.RestorePosition('recipe', movable()), true)
    ns.Nav.ResetPositions()
    eq(next(ns.db.windowPositions), nil); eq(ns.Nav.RestorePosition('recipe', movable()), false)
    UIParent = nil
end)

test('every window gets a solid background behind its art and is raised by a click', function()
    UIParent = {}
    local ns = load()
    ns.db = {}
    local drawn = {}
    local window = frame()
    function window:CreateTexture(name, layer, template, sublevel)
        local texture = { points = {} }
        function texture:SetPoint(...) self.points[#self.points + 1] = { ... } end
        function texture:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
        drawn[#drawn + 1] = { layer = layer, sublevel = sublevel, texture = texture }
        return texture
    end
    function window:SetToplevel(value) self.toplevel = value end
    function window:GetPoint() end
    ns.Nav.Draggable(window, 'recipe')
    eq(#drawn, 1); eq(drawn[1].layer, 'BACKGROUND'); eq(drawn[1].sublevel, -8)       -- under the template art
    local texture = drawn[1].texture
    eq(texture.color[4], 1)                                                           -- fully opaque
    eq(texture.points[1][1], 'TOPLEFT'); eq(texture.points[2][1], 'BOTTOMRIGHT')
    eq(window.toplevel, true); eq(window.solidBackground, texture)
    local plain = frame(); ns.Nav.Solid(plain)                                        -- a frame without textures is left alone
    UIParent = nil
end)

test('the tab windows share one saved position and take it over when they open', function()
    UIParent = {}
    local ns = load()
    ns.db = {}
    ns.RecipeBrowser, ns.Reports = nil, nil
    local function movable()
        local f = frame(); f.points = {}
        function f:GetPoint() return unpack(self.stored or {}) end
        function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
        return f
    end
    local window = movable()
    window.stored = { 'CENTER', UIParent, 'CENTER', 33, -44 }
    ns.Nav.Remember(window)
    eq(ns.db.windowPositions.nav[3], 33)
    local next_ = movable(); ns.Nav.Activate('history', next_)
    eq(#next_.points, 1); eq(next_.points[1][4], 33); eq(next_.points[1][5], -44)
    UIParent = nil
end)

print('PASS ' .. passed .. ' navigation checks')
