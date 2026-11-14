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
    local ns = { IsPublic = function() return true end, printed = {}, shown = {} }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.Crafting = { Resolve = function(info) return info.recipeID end }
    ns.CraftingView = { Show = function(id, operations) ns.shown[#ns.shown + 1] = { id, operations } end }
    CreateFrame = function(_, _, parent) local f = frame(); f.parent = parent; return f end
    C_Timer = { After = function(_, fn) fn() end }
    GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
    Menu = nil
    assert(loadfile('TitanGatheredForeverV3/ProfessionButton.lua'))('TitanGatheredForeverV3', ns)
    return ns
end
local function professionFrame(crafts, withMaximize)
    local page = { CreateMultipleInputBox = { GetNumber = function() return crafts end } }
    local frame_ = { CraftingPage = page, CloseButton = frame() }
    if withMaximize then frame_.MaximizeMinimize = frame() end
    _G.ProfessionsFrame = frame_
    return frame_
end

test('the button sits in the header left of the maximize button and belongs to the recipes tab', function()
    local ns = fresh()
    _G.ProfessionsFrame = nil
    eq(ns.ProfessionButton.Attach(), false)                 -- the profession addon is not loaded yet
    local window = professionFrame(1, true)
    eq(ns.ProfessionButton.Attach(), true)
    local button = ns.ProfessionButton.button
    eq(button.text, 'Reagents'); eq(button.calls.point[1], 'RIGHT'); eq(button.calls.point[2], window.MaximizeMinimize)
    eq(button.calls.point[3], 'LEFT'); eq(button.parent, window.MaximizeMinimize)   -- shown and hidden with it
    eq(ns.ProfessionButton.Attach(), true); eq(ns.ProfessionButton.button, button)
end)

test('without a maximize button the header button goes left of the close button', function()
    local ns = fresh()
    local window = professionFrame(1, false)
    eq(ns.ProfessionButton.Attach(), true)
    eq(ns.ProfessionButton.button.calls.point[2], window.CloseButton); eq(ns.ProfessionButton.button.parent, window)
end)

test('a click opens the selected recipe with the number of crafts typed in the profession window', function()
    local ns = fresh()
    professionFrame(12, true)
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
    professionFrame(1, true)
    onEvent(nil, 'ADDON_LOADED', 'SomeOtherAddon'); eq(ns.ProfessionButton.button, nil)   -- other addons are ignored
    onEvent(nil, 'ADDON_LOADED', 'Blizzard_Professions'); assert(ns.ProfessionButton.button)
    ns.ProfessionButton.Initialize()                        -- a second initialization changes nothing
end)

local function recipeButton(info, kind)
    local data = { recipeInfo = info }
    local node = kind == 'method' and { GetData = function() return data end } or { data = data }
    return { GetElementData = function() return node end }
end

test('the right click menu of a recipe gets a Reagents entry for that recipe', function()
    local registered = {}
    local ns = fresh()
    Menu = { ModifyMenu = function(tag, fn) registered[#registered + 1] = { tag, fn } end }
    _G.ProfessionsFrame = nil
    ns.ProfessionButton.Initialize()
    eq(#registered, 1); eq(registered[1][1], 'MENU_PROFESSIONS_RECIPE_LIST_FAVORITE')
    local entries = {}
    local root = { CreateButton = function(_, label, fn) entries[#entries + 1] = { label, fn } end }
    registered[1][2](recipeButton({ recipeID = 2550 }, 'method'), root)
    eq(#entries, 1); eq(entries[1][1], 'Reagents')
    entries[1][2](); eq(ns.shown[1][1], 2550); eq(ns.shown[1][2], 1)
    registered[1][2](recipeButton({ recipeID = 3000 }, 'field'), root)                 -- node data as a field
    eq(#entries, 2); entries[2][2](); eq(ns.shown[2][1], 3000)
    registered[1][2](nil, root); registered[1][2]({}, root); registered[1][2]({ GetElementData = function() return {} end }, root)
    eq(#entries, 2)                                                                     -- nothing to add for other owners
    ns.Crafting.Resolve = function() return nil end                                     -- an unresolved rank adds nothing
    registered[1][2](recipeButton({ recipeID = 1 }, 'method'), root); eq(#entries, 2)
    Menu = nil
end)

test('without the menu API only the button is used, and a failing registration is tolerated', function()
    local ns = fresh()
    _G.ProfessionsFrame = nil
    Menu = nil
    eq(ns.ProfessionButton.HookMenu(), false)
    Menu = { ModifyMenu = function() error('unknown tag') end }
    eq(ns.ProfessionButton.HookMenu(), false); eq(ns.ProfessionButton.menuHooked, false)
    Menu = nil
end)

for _, entry in ipairs(tests) do
    local ok, err = pcall(entry[2])
    if not ok then io.stderr:write('FAIL ' .. entry[1] .. ': ' .. tostring(err) .. '\n'); os.exit(1) end
end
print('PASS profession button ' .. #tests .. ' checks')
