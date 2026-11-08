local f=assert(loadfile('tests/export_fixture.lua'))()
local options={scope=arg[1]=='current'and'character'or'combined',includeIdentity=arg[1]=='identity'or arg[1]=='parts'}
local payload=f.ns.Export.Encode(f.ns.Export.Build(f.sources,options))
if arg[1]=='parts'then payload=f.ns.Export.Encode(f.ns.Export.Array(f.ns.Export.Parts(payload,64)))end
if arg[1]=='boundary'then payload=f.ns.Export.Encode(f.ns.Export.Array(f.ns.Export.Parts('{"name":"Žofie"}',10)))end
io.write(payload)
