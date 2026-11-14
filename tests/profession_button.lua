local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function frame()
    local f = { scripts = {}, events = {}, calls = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetSize(...) self.calls.size = { ... } end
    function f:SetText(v) self.text = v end
    function f:SetPoint(...) self.calls.point = { ... } end
    function f:RegisterEvent(e) self.events[#self.events + 1] = e end
    return f
end
local function fresh()
    local ns = { IsPublic = function() return true end, printed = {}, Crafting = {}, shown = {} }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.CraftingView = { Show = function(id, operations) ns.shown[#ns.shown + 1] = { id, operations } end }
    CreateFrame = function() return frame() end
    C_Timer = { After = function(_, fn) fn() end }
    GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
    assert(loadfile('TitanGatheredForeverV3/ProfessionButton.lua'))('TitanGatheredForeverV3', ns)
    return ns
end
local function professionFrame(crafts)
    local anchor = frame()
    local page = { CreateAllButton = anchor, CreateMultipleInputBox = { GetNumber = function() return crafts end } }
    _G.ProfessionsFrame = { CraftingPage = page }
    return page, anchor
end

test('the button is placed left of the Create All button once the profession window exists', function()
    local ns = fresh()
    _G.ProfessionsFrame = nil
    eq(ns.ProfessionButton.Attach(), false)                 -- the profession addon is not loaded yet
    local page, anchor = professionFrame(1)
    eq(ns.ProfessionButton.Attach(), true)
    local button = ns.ProfessionButton.button
    eq(button.text, 'Reagents'); eq(button.calls.point[1], 'RIGHT'); eq(button.calls.point[2], anchor); eq(button.calls.point[3], 'LEFT')
    eq(ns.ProfessionButton.Attach(), true)                  -- a second call keeps the same button
    eq(ns.ProfessionButton.button, button)
end)

test('a click opens the selected recipe with the number of crafts typed in the profession window', function()
    local ns = fresh()
    local page = professionFrame(12)
    ns.ProfessionButton.Attach()
    ns.ProfessionButton.button.scripts.OnClick()
    eq(#ns.shown, 0); eq(ns.printed[1], 'Select a recipe in the profession window first.')
    ns.Crafting.selectedID = 2536
    ns.ProfessionButton.button.scripts.OnClick()
    eq(ns.shown[1][1], 2536); eq(ns.shown[1][2], 12)
    eq(ns.ProfessionButton.Operations({ CreateMultipleInputBox = { GetNumber = function() return 0 end } }), 1)
    eq(ns.ProfessionButton.Operations(nil), 1)
    eq(ns.ProfessionButton.Operations({ CreateMultipleInputBox = { GetNumber = function() error('boom') end } }), 1)
end)

test('initializing tries again on the events around opening the profession window until the button exists', function()
    local ns = fresh()
    _G.ProfessionsFrame = nil
    ns.ProfessionButton.Initialize()
    local events = ns.ProfessionButton.frame.events
    eq(#events, 3); eq(events[1], 'ADDON_LOADED')
    local onEvent = ns.ProfessionButton.frame.scripts.OnEvent
    onEvent(nil, 'ADDON_LOADED', 'SomeOtherAddon'); eq(ns.ProfessionButton.button, nil)
    professionFrame(1)
    onEvent(nil, 'ADDON_LOADED', 'SomeOtherAddon'); eq(ns.ProfessionButton.button, nil)   -- other addons are ignored
    onEvent(nil, 'ADDON_LOADED', 'Blizzard_Professions'); assert(ns.ProfessionButton.button)
    ns.ProfessionButton.Initialize()                        -- a second initialization changes nothing
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS profession button ' .. #tests .. ' checks')
