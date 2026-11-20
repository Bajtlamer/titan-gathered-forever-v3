local _, ns = ...
-- Loading, saved data, login checks and the slash command. Milestone 1 listens to ADDON_LOADED and PLAYER_LOGIN only.
local Main = {}
ns.Main = Main

local FOLDER = 'TitanGatheredForever_Discovery'

local function metadata(addon, field)
    local read = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not read then return nil end
    local ok, value = pcall(read, addon, field)
    return ok and value or nil
end

local function realEnv()
    return {
        now = time, date = date, build = GetBuildInfo,
        moduleVersion = metadata(FOLDER, 'Version') or 'unknown',
        coreVersion = function() return metadata('TitanGatheredForever', 'Version') end,
    }
end

local function isLoaded(name)
    local check = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return check and check(name)
end

local function onAddonLoaded()
    ns.Print = ns.Print or function(message) DEFAULT_CHAT_FRAME:AddMessage(message) end
    ns.env = ns.env or realEnv()
    ns.runtime = { scout = {} }
    local status
    _G.TitanGatheredForeverDiscoveryDB, status = ns.Database.Init(_G.TitanGatheredForeverDiscoveryDB, ns.env.moduleVersion, ns.env.now())
    ns.db = _G.TitanGatheredForeverDiscoveryDB
    ns.runtime.schemaBlocked = status == 'newer'
    _G.SLASH_TGFD1 = '/tgfd'
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList.TGFD = function(message) ns.Commands.Handle(message) end
    ns.frame:RegisterEvent('PLAYER_LOGIN')
end

local function onLogin()
    local Text = ns.Text
    ns.runtime.scout = ns.Scout.Found(isLoaded)
    if #ns.runtime.scout > 0 then
        ns.Print(Text.Label('Discovery is off: ') .. Text.Value(table.concat(ns.runtime.scout, ', ')) .. Text.Label(' is loaded. Only one of the two may run. Disable one and reload.'))
    end
    if ns.runtime.schemaBlocked then
        ns.Print(Text.Label('Discovery is off: the saved data are from a newer version of this module and are left untouched. Update the module.'))
    end
    if #ns.runtime.scout > 0 or ns.runtime.schemaBlocked then return end
    local state = ns.Consent.State(ns.db, ns.runtime)
    if state == 'unaccepted' then
        ns.Print(Text.Label('Discovery records nothing until you read and accept its notice. Type ') .. Text.Value('/tgfd') .. Text.Label('.'))
    else
        ns.Print(Text.Label('Discovery: ') .. Text.Value(state == 'paused' and 'Paused' or 'Collecting') .. Text.Label('. Type ') .. Text.Value('/tgfd status') .. Text.Label('.'))
    end
end

function Main.Start()
    ns.frame = CreateFrame('Frame')
    ns.frame:RegisterEvent('ADDON_LOADED')
    ns.frame:SetScript('OnEvent', function(_, event, name)
        if event == 'ADDON_LOADED' then
            if name == FOLDER then onAddonLoaded() end
        elseif event == 'PLAYER_LOGIN' then
            onLogin()
        end
    end)
end
