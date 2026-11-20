local _, ns = ...
-- Every zone, subzone and instance name the player enters, with its map and parent map. The current area key is kept so
-- that other records can say where they were seen.
local Area = {}
ns.Area = Area

function Area.Changed()
    local zone = ns.api.Zone()
    if type(zone) ~= 'table' then return end
    local named = zone.mapID or (zone.realZone and zone.realZone ~= '') or (zone.zone and zone.zone ~= '')
        or (zone.subZone and zone.subZone ~= '') or zone.instanceName
    if not named then return end
    local key = table.concat({ zone.mapID or 0, zone.realZone or '', zone.zone or '', zone.subZone or '', zone.instanceName or '' }, '|')
    if key == ns.state.areaKey then return end
    ns.state.areaKey = key
    local record = ns.Records.Touch(ns.db.data.areas, key, ns.Records.Context())
    record.mapID, record.parentMapID = zone.mapID, zone.parentMapID
    record.realZone, record.zone, record.subZone = zone.realZone, zone.zone, zone.subZone
    record.instanceName, record.instanceType = zone.instanceName, zone.instanceType
end
