local f=assert(loadfile('tests/export_fixture.lua'))()
local ns=f.ns
local passed=0
local function eq(a,b)assert(a==b,tostring(a)..' != '..tostring(b))end
local function test(n,fn)local ok,e=pcall(fn);if not ok then error(n..': '..e)end;passed=passed+1 end
test('current scope excludes other characters and retains partial lifetime quantities',function()
 local d=ns.Export.Build(f.sources,{})
 eq(d.schemaVersion,1);eq(d.selection.scope,'character');eq(#d.characters,1)
 local h=d.characters[1].history;eq(h.items[1].itemID,1210);eq(h.items[1].quantity,3)
 eq(h.rates[1].itemID,2770);eq(h.rates[1].hits,1);eq(h.rates[1].eligibleCompleteSources,2)
 eq(h.sourceGroups[1].completeSources,2);eq(h.sourceGroups[1].outcomes[1].quantity,0)
end)
test('default privacy excludes nested keys labels receipts positions and identity',function()
 local text=ns.Export.Encode(ns.Export.Build(f.sources,{scope='combined'}))
 for _,value in ipairs({'Player-private','Private','private-','0.123','0.456','recent','sealed','itemGUID','castGUID'})do
  assert(not text:find(value,1,true),'Leaked '..value)
 end
 local d=ns.Export.Build(f.sources,{scope='combined'});eq(d.selection.includeIdentity,false)
 eq(d.characters[1].ref,'character-1');eq(d.characters[1].identity,nil);eq(d.selection.characterCount,2)
end)
test('identity is exported only with explicit boolean opt in',function()
 local d=ns.Export.Build(f.sources,{includeIdentity=true});eq(d.characters[1].identity.guid,'Player-private-A')
 assert(d.characters[1].identity.name:find('Žofie',1,true))
 eq(ns.Export.Build(f.sources,{includeIdentity='true'}).characters[1].identity,nil)
end)
test('combined source rates sum eligible trials instead of averaging percentages',function()
 local d=ns.Export.Build(f.sources,{scope='combined'});local r=d.combined.history.rates[1]
 eq(r.hits,2);eq(r.eligibleCompleteSources,3);eq(r.quantity,3)
 eq(d.combined.actions.rows[1].attempts,2);eq(d.combined.actions.rows[1].completed,1)
end)
test('policies preserve eligibility with export local references',function()
 local h=ns.Export.Build(f.sources,{}).characters[1].history
 local selected
 for _,p in ipairs(h.policies)do if #p.items>0 then selected=p end end
 assert(selected);eq(selected.items[1],2770);eq(selected.knownItems[1],2770)
 eq(selected.rare,false);eq(h.sourceGroups[1].trialPolicies[1].completeSources,0)
 local found=false
 for _,policy in ipairs(h.sourceGroups[1].trialPolicies)do
  if policy.policyRef==selected.ref then eq(policy.completeSources,2);found=true end
 end
 assert(found)
end)
test('coverage does not invent history start times or continuous intervals',function()
 local d=ns.Export.Build(f.sources,{});eq(d.definitions.coverageIntervalsRecorded,false)
 eq(d.characters[1].history.startTimestampRecorded,false)
 eq(d.characters[1].actions.rows[1].began,100);eq(d.characters[1].actions.rows[1].unresolved,1)
end)
test('production retains matched denominators explicit flags and output distributions',function()
 local p=ns.Export.Build(f.sources,{}).characters[1].production;local r=p.recipes[1]
 eq(r.attempts,3);eq(r.completed,2);eq(r.matched,2);eq(r.quantity,6);eq(r.unresolved,1)
 eq(r.multicraftKnown,2);eq(r.multicraftHits,1);eq(r.bonusKnown,2);eq(r.bonusHits,1)
 eq(r.outputs[1].itemID,2680);eq(r.outputs[1].distribution[1].quantity,2);eq(r.outputs[1].distribution[2].operations,1)
end)
test('snapshot creation and encoding never seal collectors or mutate saved state',function()
 local before=f.saved.actions.characters['Player-private-A'].recent['private-cast-pending']
 local pending=f.saved.production.characters['Player-private-A'].recent['private-production-pending']
 ns.Export.Encode(ns.Export.Build(f.sources,{scope='combined'}))
 eq(before.sealed,nil);eq(pending.sealed,nil)
 eq(f.saved.history.characters['Player-private-A'].recent['private-receipt-partial'].complete,nil)
end)
test('future feature schemas are unavailable rather than fabricated empty coverage',function()
 local old=f.saved.actions.schema;f.saved.actions.schema=2
 local a=ns.Export.Build(f.sources,{}).characters[1].actions
 eq(a.status,'unsupported_schema');eq(a.sourceSchema,2);eq(#a.rows,0)
 f.saved.actions.schema=old
end)
test('JSON encoding distinguishes arrays escapes text and rejects invalid values',function()
 eq(ns.Export.Encode(ns.Export.Array({})),'[]');eq(ns.Export.Encode({}),'{}')
 eq(ns.Export.Encode({z=true,a='line\n"\\\0'}),'{"a":"line\\n\\"\\\\\\u0000","z":true}')
 assert(not pcall(ns.Export.Encode,0/0));assert(not pcall(ns.Export.Encode,math.huge))
 local cyclic={};cyclic.self=cyclic;assert(not pcall(ns.Export.Encode,cyclic))
end)
test('export parts preserve UTF8 boundaries and identify the complete byte payload',function()
 local payload=ns.Export.Encode(ns.Export.Build(f.sources,{includeIdentity=true}))
 local parts=ns.Export.Parts(payload,64);assert(#parts>1)
 eq(#ns.Export.Parts('{}',64),1);eq(ns.Export.Parts('{}',64)[1],'{}')
 eq(ns.Export.Checksum('Wikipedia'),'11e60398')
 assert(not pcall(ns.Export.Parts,payload,1))
end)
test('invalid selection scope cannot silently export every character',function()
 assert(not pcall(ns.Export.Build,f.sources,{scope='alll'}))
end)
test('identity opt in does not inspect unavailable future feature stores',function()
 local model=ns.Actions.New({schema=2},{})
 local d=ns.Export.Build({character='Player-empty',timestamp=300,actions=model},{includeIdentity=true})
 eq(d.characters[1].identity.guid,'Player-empty');eq(d.characters[1].identity.name,nil)
 eq(d.characters[1].actions.status,'unsupported_schema');eq(#d.characters[1].actions.rows,0)
end)
test('malformed future version labels cannot leak free form saved strings',function()
 local model=ns.Actions.New({schema='PrivateFutureLabel'},{})
 local d=ns.Export.Build({character='Player-empty',timestamp=300,actions=model},{})
 assert(not ns.Export.Encode(d):find('PrivateFutureLabel',1,true))
end)
print('PASS '..passed..' statistics export checks')
