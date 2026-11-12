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
    assert(loadfile('TitanGatheredForeverV3/Navigation.lua'))('TitanGatheredForeverV3', ns)
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
    eq(numTabs, #ns.Nav.tabs); eq(selected, 3); eq(window.tabButtons.pvp.template, 'PanelTabButtonTemplate')
    eq(#window.Tabs, 7); eq(window.Tabs[2].calls.SetID[1], 2)
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

print('PASS ' .. passed .. ' navigation checks')
