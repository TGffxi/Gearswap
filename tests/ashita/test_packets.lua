local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.packets'] = nil
    local loaded, packets = pcall(require, 'ashita.packets')
    a.equal(loaded, true, 'ashita.packets service must exist before Phase 3 Task 2 can pass')
    a.equal(type(packets.new), 'function', 'packets.new dependency-injection factory')

    -- Pinned evidence:
    -- Ashita/LuAshitacast incoming zone/player packet: 0x00A
    -- Ashita/LuAshitacast incoming action packet:      0x028
    -- Rahvin raw action-message/death packet:          0x029
    a.equal(packets.IDS.ZONE, 0x00A)
    a.equal(packets.IDS.ACTION, 0x028)
    a.equal(packets.IDS.ACTION_MESSAGE, 0x029)

    local calls = {zone={}, incoming={}, action={}, poll={}, target={}}
    local target_index = 41
    local handlers = {
        zone_change=function(new_zone, old_zone)
            calls.zone[#calls.zone+1] = {new_zone, old_zone}
        end,
        incoming_chunk=function(id, data, modified, injected, blocked)
            calls.incoming[#calls.incoming+1] = {id, data, modified, injected, blocked}
        end,
        action=function(decoded)
            calls.action[#calls.action+1] = decoded
        end,
        main_engine=function(e)
            calls.poll[#calls.poll+1] = e.id
        end,
        target_change=function(new_index, old_index)
            calls.target[#calls.target+1] = {new_index, old_index}
        end,
    }
    local decoder = {
        zone=function(e) return e.new_zone, e.old_zone end,
        action=function(e) return e.decoded_action end,
        target_index=function() return target_index end,
    }
    local service = packets.new(handlers, decoder)

    a.equal(service.on_incoming({id=0x1234}), false, 'unrelated incoming packet is ignored')
    a.equal(#calls.zone, 0); a.equal(#calls.incoming, 0); a.equal(#calls.action, 0)

    a.equal(service.on_incoming({id=packets.IDS.ACTION_MESSAGE,data='raw',data_modified='mod',injected=true,blocked=false}), true)
    a.deep_equal(calls.incoming[1], {0x029,'raw','mod',true,false}, 'death/action-message packet keeps Rahvin raw handler shape')

    local action={actor_id=100,category=1,param=0,targets={{id=200}}}
    a.equal(service.on_incoming({id=packets.IDS.ACTION,decoded_action=action}), true)
    a.equal(calls.action[1], action, 'decoded action packet reaches Rahvin action handler unchanged')

    a.equal(service.on_incoming({id=packets.IDS.ZONE,new_zone=300,old_zone=299}), true)
    a.deep_equal(calls.zone[1], {300,299}, 'zone packet routes reset before later target polling')

    service.on_outgoing({id=0x01A})
    a.deep_equal(calls.poll, {0x01A}, 'every outgoing packet drives Rahvin polling engine')
    a.equal(#calls.target, 0, 'first observed target establishes baseline only')

    target_index = 42
    service.on_outgoing({id=0x015})
    a.deep_equal(calls.poll, {0x01A,0x015})
    a.deep_equal(calls.target[1], {42,41}, 'changed target index reaches Rahvin target-change handler')

    service.on_outgoing({id=0x015})
    a.equal(#calls.target, 1, 'unchanged target does not duplicate target-change callbacks')
end
