local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.platform'] = nil
    local loaded, platform_mod = pcall(require, 'ashita.platform')
    a.equal(loaded, true, 'production runtime requires ashita.platform composition adapter')
    a.equal(type(platform_mod.new), 'function', 'platform.new must expose dependency injection')

    local calls = {}
    local function log(name, ...)
        calls[#calls + 1] = {name=name, args={...}}
        return true
    end

    local inventory = {
        iter_bag=function(bag)
            log('inventory.iter_bag', bag)
            return {{id=100, status=5, bag=bag, index=1, raw={Id=100, Status=5}}}
        end,
    }
    local recasts = {
        abilities=function() log('recasts.abilities'); return {[5]=12.5} end,
        spells=function() log('recasts.spells'); return {[144]=3.0} end,
    }

    local ipc_listener
    local ipc = {
        subscribe=function(fn) ipc_listener=fn; return log('ipc.subscribe') end,
        unsubscribe=function(fn)
            a.equal(fn, ipc_listener, 'detach must unsubscribe the exact registered listener')
            ipc_listener=nil
            return log('ipc.unsubscribe')
        end,
        send_rahvin=function(message, sender, timestamp)
            log('ipc.send_rahvin', message, sender, timestamp)
            return true
        end,
    }

    local p = platform_mod.new({
        inventory=inventory,
        recasts=recasts,
        ipc_to_rahvin=function(payload)
            if payload.kind == 'SPELL' then return 'RAHVIN|SPELL|Alice|Bob|20|1000' end
            return nil
        end,
    })

    a.equal(type(p.register_event), 'function')
    a.equal(type(p.emit), 'function')
    a.equal(type(p.attach_ipc), 'function')
    a.equal(type(p.detach_ipc), 'function')
    a.equal(type(p.send_ipc), 'function')
    a.equal(type(p.get_items), 'function')
    a.equal(type(p.get_ability_recasts), 'function')
    a.equal(type(p.get_spell_recasts), 'function')

    local seen = {}
    p:register_event('target change', function(new, old) seen[#seen+1]={'target',new,old} end)
    p:register_event('target change', function(new, old) seen[#seen+1]={'target2',new,old} end)
    p:register_event('ipc message', function(message) seen[#seen+1]={'ipc',message} end)

    a.equal(p:emit('target change', 7, 4), 2, 'all handlers for one Windower event must run')
    a.deep_equal(seen[1], {'target',7,4})
    a.deep_equal(seen[2], {'target2',7,4})
    a.equal(p:emit('unknown event', 1), 0, 'unknown event dispatch must be a no-op')

    a.equal(p:attach_ipc(ipc), true)
    a.equal(type(ipc_listener), 'function', 'attach_ipc must subscribe to current transport')
    ipc_listener({v=1, sender='Alice', kind='SPELL', phase='START', action='20', target='Bob', timestamp=1000})
    a.deep_equal(seen[3], {'ipc','RAHVIN|SPELL|Alice|Bob|20|1000'},
        'incoming Ashita IPC payload must reach unchanged Rahvin ipc message handler')

    a.equal(p:send_ipc('RAHVIN|ROLLQ|Bob', 'Alice', 2000), true)
    a.equal(calls[#calls].name, 'ipc.send_rahvin')
    a.deep_equal(calls[#calls].args, {'RAHVIN|ROLLQ|Bob','Alice',2000})

    local bag = p:get_items(8)
    a.equal(bag[1].id, 100)
    a.equal(bag[1].status, 5)
    a.equal(bag[1].raw.Id, 100)
    a.equal(p:get_ability_recasts()[5], 12.5)
    a.equal(p:get_spell_recasts()[144], 3.0)

    -- Logout/login replaces the IPC object. The old service must be detached before a new
    -- one is attached, otherwise one Rahvin message can be delivered twice after reload.
    a.equal(p:detach_ipc(), true)
    a.equal(ipc_listener, nil)
    a.equal(p:detach_ipc(), true, 'repeated detach must be harmless')
    local sent_without_ipc, reason = p:send_ipc('x')
    a.equal(sent_without_ipc, false)
    a.equal(reason, 'ipc_unavailable')

    -- Handler registry can be cleared by the owning lifecycle generation without leaving
    -- stale callbacks from the previous character/profile load.
    a.equal(type(p.clear_events), 'function')
    a.equal(p:clear_events(), 3)
    a.equal(p:emit('target change', 8, 7), 0)
end
