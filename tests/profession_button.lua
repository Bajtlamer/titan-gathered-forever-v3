local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function eq(actual, expected) assert(actual == expected, 'expected ' .. tostring(expected) .. ', got ' .. tostring(actual)) end

local function frame()
    local f = { scripts = {}, events = {}, calls = {} }
    function f:SetScript(name, fn) self.scripts[name] = fn end
    function f:SetSize(...) self.calls.size = { ... } end
    function f:SetText(v) self.text = v end
    function f:SetPoint(...) self.calls.point = { ... } end
    function f:ClearAllPoints() self.calls.cleared = (self.calls.cleared or 0) + 1 end
    function f:IsShown() return self.shownState end
    function f:HookScript(name, fn) self.hooked = self.hooked or {}; self.hooked[name] = fn end
    function f:GetFrameLevel() return self.level or 5 end
    function f:SetFrameLevel(level) self.level = level end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:GetFrameStrata() return self.strata or 'MEDIUM' end
    function f:SetShown(value) self.shownState = value end
    function f:IsVisible() return self.shownState == true end
    function f:GetLeft() return 100.123 end
    function f:GetTop() return 50 end
    function f:GetWidth() return 80 end
    function f:GetEffectiveScale() return 1 end
    function f:RegisterEvent(e) self.events[#self.events + 1] = e end
    return f
end
local function fresh()
    local ns = { IsPublic = function() return true end, printed = {}, shown = {} }
    ns.Print = function(message) ns.printed[#ns.printed + 1] = message end
    ns.Crafting = { Resolve = function(info) return info.recipeID end }
    ns.CraftingView = { Show = function(id, operations) ns.shown[#ns.shown + 1] = { id, operations } end }
    CreateFrame = function(_, _, parent) local f = frame(); f.parent = parent; return f end
    C_Timer = { After = function() end }
    GameTooltip = { SetOwner = function() end, AddLine = function() end, Show = function() end, Hide = function() end }
    Menu = nil
    assert(loadfile('TitanGatheredForeverV3/ProfessionButton.lua'))('TitanGatheredForeverV3', ns)
    return ns
end
local function professionFrame(crafts, maximize, withPage)
    local page = withPage ~= false and { CreateMultipleInputBox = { GetNumber = function() return crafts end }, shownState = true } or nil
    if page then
        page.HookScript = function(self, name, fn) self.hooked = self.hooked or {}; self.hooked[name] = fn end
        page.IsShown = function(self) return self.shownState end
    end
    local frame_ = { CraftingPage = page, CloseButton = frame(), shownState = true, level = 3 }
    frame_.HookScript = function(self, name, fn) self.hooked = self.hooked or {}; self.hooked[name] = fn end
    frame_.IsShown = function(self) return self.shownState end
    frame_.GetFrameLevel = function(self) return self.level end
    if maximize then frame_.MaximizeMinimize = frame(); frame_.MaximizeMinimize.shownState = maximize == 'shown' end
    _G.ProfessionsFrame = frame_
    return frame_
end

test('the button belongs to the screen, sits left of the close button when the maximize button is hidden, and is raised', function()
    local ns = fresh()
    ns.db = { professionLog = {} }
    UIParent = {}
    _G.ProfessionsFrame = nil
    eq(ns.ProfessionButton.Attach(), false)                 -- the profession addon is not loaded yet
    local window = professionFrame(1, 'hidden')
    eq(ns.ProfessionButton.Attach(), true)
    local button = ns.ProfessionButton.button
    eq(button.text, 'Reagents'); eq(button.calls.point[1], 'RIGHT'); eq(button.calls.point[2], window.CloseButton)
    eq(button.calls.point[3], 'LEFT'); eq(button.parent, UIParent)                       -- nothing in the window can clip or cover it
    eq(button.strata, 'HIGH'); eq(button.level, 53)                                      -- above the window
    eq(button.shownState, true)
    eq(ns.ProfessionButton.Attach(), true); eq(ns.ProfessionButton.button, button)
    local entry = ns.db.professionLog[#ns.db.professionLog]
    eq(entry.stage, 'attached'); eq(entry.maximizeShown, false); eq(entry.parent, 'screen')
end)

test('the button follows the window and its recipes page and is placed again whenever one is shown', function()
    local ns = fresh()
    local window = professionFrame(1, 'shown')
    ns.ProfessionButton.Attach()
    local button = ns.ProfessionButton.button
    eq(button.calls.point[2], window.MaximizeMinimize)
    window.MaximizeMinimize.shownState = false               -- the other tab hides it
    window.CraftingPage.hooked.OnShow()
    eq(button.calls.point[2], window.CloseButton); eq(button.shownState, true)
    window.CraftingPage.shownState = false; window.CraftingPage.hooked.OnHide()
    eq(button.shownState, false)                             -- another page of the window: no button
    window.CraftingPage.shownState = true; window.CraftingPage.hooked.OnShow(); eq(button.shownState, true)
    window.shownState = false; window.hooked.OnHide(); eq(button.shownState, false)   -- the window is closed
end)

test('a second look is logged with where the button is and whether it is visible', function()
    local ns = fresh()
    ns.db = { professionLog = {} }
    local timers = {}
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    local window = professionFrame(1, 'hidden')
    ns.ProfessionButton.Attach()
    eq(#timers, 1); timers[1]()
    local entry = ns.db.professionLog[#ns.db.professionLog]
    eq(entry.stage, 'placed'); eq(entry.visible, true); eq(entry.left, 100.1); eq(entry.strata, 'HIGH')
    eq(entry.frameShown, true); eq(entry.pageShown, true); eq(entry.closeLeft, 100.1)
end)

test('without a recipes page only the window decides; without any neighbour nothing is made and it is logged once', function()
    local ns = fresh()
    ns.db = { professionLog = {} }
    local window = professionFrame(1, nil, false)
    eq(ns.ProfessionButton.Attach(), true); eq(ns.ProfessionButton.button.shownState, true)
    ns = fresh(); ns.db = { professionLog = {} }
    _G.ProfessionsFrame = { }
    eq(ns.ProfessionButton.Attach(), false); eq(ns.ProfessionButton.button, nil)
    eq(ns.db.professionLog[1].stage, 'no-frame'); eq(ns.db.professionLog[1].frame, true); eq(ns.db.professionLog[1].close, false)
    ns.ProfessionButton.Attach(); eq(#ns.db.professionLog, 1)                          -- logged once, not at every event
end)

test('a click opens the selected recipe with the number of crafts typed in the profession window', function()
    local ns = fresh()
    professionFrame(12, 'hidden')
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
    C_Timer = { After = function(_, fn) fn() end }
    _G.ProfessionsFrame = nil
    ns.ProfessionButton.Initialize()
    local events = ns.ProfessionButton.frame.events
    eq(#events, 3); eq(events[1], 'ADDON_LOADED')
    local onEvent = ns.ProfessionButton.frame.scripts.OnEvent
    onEvent(nil, 'ADDON_LOADED', 'SomeOtherAddon'); eq(ns.ProfessionButton.button, nil)
    professionFrame(1, 'hidden')
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
