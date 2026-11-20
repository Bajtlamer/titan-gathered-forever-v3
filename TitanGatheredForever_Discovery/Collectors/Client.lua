local _, ns = ...
-- The client build, so a difference seen on another build is not mistaken for an error.
local Client = {}
ns.Client = Client

function Client.Record()
    local version, build, date, interface = ns.api.Build()
    build = tostring(build)
    ns.db.meta.client = { version = version, build = build, date = date, interface = interface, locale = ns.api.Locale() }
    ns.db.meta.builds = ns.db.meta.builds or {}
    ns.db.meta.builds[build] = ns.db.meta.builds[build] or ns.api.Now()
    ns.state.build = build
end
