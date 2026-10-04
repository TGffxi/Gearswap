local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.packets'] = nil
    local loaded, packets = pcall(require, 'ashita.packets')
    a.equal(loaded, true, 'TH parity requires the packet bridge')

    local seen = {}
    local handlers = {
        action=function(data) seen[#seen+1]=data end,
        incoming_chunk=function() end,
        zone_change=function() end,
        main_engine=function() end,
        target_change=function() end,
        logout=function() end,
    }
    local service = packets.new(handlers, {action=function(e) return e.decoded_action end})

    -- Do not actor-filter in the adapter. Rahvin th_action itself restricts TH tagging and
    -- completion handling to player.actor_id, but intentionally keeps category 3/4
    -- skillchain and category 6 roll handling outside that actor check.
    local own={actor_id=10,category=1,param=0,targets={{id=99}}}
    local other_ws={actor_id=20,category=3,param=123,targets={{id=99}}}
    local other_spell={actor_id=21,category=4,param=456,targets={{id=99}}}
    local other_roll={actor_id=22,category=6,param=789,targets={{id=10}}}

    service.on_action(own)
    service.on_action(other_ws)
    service.on_action(other_spell)
    service.on_action(other_roll)

    a.equal(#seen,4,'packet bridge must preserve all actors for Rahvin th_action semantics')
    a.equal(seen[1],own)
    a.equal(seen[2],other_ws)
    a.equal(seen[3],other_spell)
    a.equal(seen[4],other_roll)
end
