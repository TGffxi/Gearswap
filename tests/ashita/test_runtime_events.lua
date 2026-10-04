local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.runtime_events'] = nil
    local loaded, runtime_events = pcall(require, 'ashita.runtime_events')
    a.equal(loaded, true, 'production runtime requires ashita.runtime_events bridge')
    a.equal(type(runtime_events.new), 'function', 'runtime_events.new must expose dependency injection')

    local registered = {}
    local events = {
        register=function(event, alias, fn)
            registered[event .. ':' .. alias] = fn
            return true
        end,
    }

    local emitted = {}
    local ipc_listener
    local cleared = 0
    local platform
    platform = {
        emit=function(_, name, ...)
            emitted[#emitted + 1] = {name=name, args={...}}
            return 1
        end,
        attach_ipc=function(_, ipc)
            ipc_listener = function(payload)
                platform:emit('ipc message', 'converted:' .. tostring(payload.kind))
            end
            ipc.subscribe(ipc_listener)
            return true
        end,
        detach_ipc=function(_, ipc)
            if ipc and ipc_listener then ipc.unsubscribe(ipc_listener) end
            ipc_listener = nil
            return true
        end,
        clear_events=function() cleared=cleared+1; return true end,
    }

    local target_index = 40
    local decoder = {
        action=function(e) return e.decoded_action end,
        zone=function(e) return e.new_zone, e.old_zone end,
        target_index=function() return target_index end,
        logout=function(e) return e.is_logout == true end,
    }

    local native_logouts = 0
    local service = runtime_events.new({
        events=events,
        platform=platform,
        decoder=decoder,
        on_logout=function() native_logouts = native_logouts + 1; return true end,
    })
    a.equal(type(service.register), 'function')
    a.equal(type(service.frame), 'function')
    a.equal(type(service.logout), 'function')
    a.equal(type(service.attach_ipc), 'function')
    a.equal(type(service.detach_ipc), 'function')
    a.equal(type(service.unload), 'function')

    a.equal(service.register(), true)
    local incoming = registered['packet_in:rahvings_packet_in']
    local outgoing = registered['packet_out:rahvings_packet_out']
    a.equal(type(incoming), 'function', 'packet_in must be registered through the lifecycle event registry')
    a.equal(type(outgoing), 'function', 'packet_out must be registered through the lifecycle event registry')

    local raw = {id=0x029, data='raw', data_modified='mod', injected=true, blocked=false}
    incoming(raw)
    a.equal(emitted[#emitted].name, 'incoming chunk')
    a.deep_equal(emitted[#emitted].args, {0x029,'raw','mod',true,false},
        'raw incoming chunk must preserve Windower handler arguments')

    local action = {actor_id=123, category=6, param=77, targets={{id=456,actions={}}}}
    incoming({id=0x028, decoded_action=action})
    a.equal(emitted[#emitted].name, 'action')
    a.equal(emitted[#emitted].args[1], action,
        'decoded action must reach unchanged Rahvin action registration')

    incoming({id=0x00A, new_zone=291, old_zone=100})
    a.equal(emitted[#emitted].name, 'zone change')
    a.deep_equal(emitted[#emitted].args, {291,100})

    local emitted_before_logout_packet = #emitted
    incoming({id=0x00B, is_logout=true})
    a.equal(native_logouts, 1,
        'logout packet must invoke lifecycle ownership callback')
    a.equal(#emitted, emitted_before_logout_packet,
        'packet bridge must not emit Rahvin logical logout separately from lifecycle')

    outgoing({id=0x015, data='move-a', data_modified='move-a-mod', injected=false, blocked=false})
    a.equal(emitted[#emitted].name, 'outgoing chunk')
    a.equal(emitted[#emitted].args[1], 0x015,
        'Rahvin main_engine must receive packet id, not the Ashita event table')
    a.equal(emitted[#emitted].args[2], 'move-a')

    target_index = 41
    outgoing({id=0x015, data='move-b'})
    a.equal(emitted[#emitted - 1].name, 'outgoing chunk')
    a.equal(emitted[#emitted].name, 'target change')
    a.deep_equal(emitted[#emitted].args, {41,40})

    service.frame()
    a.equal(emitted[#emitted].name, 'prerender',
        'one Ashita frame must drive Rahvin prerender registrations')

    local ipc = {
        subscribe=function(fn) ipc_listener=fn; return true end,
        unsubscribe=function(fn) a.equal(fn, ipc_listener); ipc_listener=nil; return true end,
    }
    a.equal(service.attach_ipc(ipc), true)
    a.equal(type(ipc_listener), 'function')
    ipc_listener({kind='SPELL'})
    a.equal(emitted[#emitted].name, 'ipc message')
    a.equal(emitted[#emitted].args[1], 'converted:SPELL')
    a.equal(service.detach_ipc(), true)
    a.equal(ipc_listener, nil)

    service.logout()
    a.equal(emitted[#emitted].name, 'logout',
        'Ashita logout must reach Rahvin display_logout registration before teardown')

    a.equal(service.unload(), true)
    a.equal(cleared, 1,
        'profile unload must clear Windower-shaped handlers from the completed generation')
end
