local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.lifecycle'] = nil
    local lifecycle = require('ashita.lifecycle')

    local calls = {}
    local function log(name, ...)
        calls[#calls + 1] = {name=name, args={...}}
        return true
    end

    local registered = {}
    local events = {
        register=function(event, alias, fn)
            registered[event .. ':' .. alias] = fn
            return log('events.register', event, alias)
        end,
        unregister_all=function()
            registered = {}
            return log('events.unregister_all')
        end,
    }

    local scheduler = {
        schedule=function(fn, delay) return {fn=fn, delay=delay} end,
        tick=function() return log('scheduler.tick') end,
        clear=function() return log('scheduler.clear') end,
    }

    local generation = 0
    local ipc_instances = {}
    local function ipc_factory()
        generation = generation + 1
        local id = generation
        local ipc = {
            poll=function() return log('ipc.poll', id) end,
            close=function() return log('ipc.close', id) end,
        }
        ipc_instances[id] = ipc
        log('ipc.open', id)
        return ipc
    end

    local runtime_events = {
        register=function() return log('runtime.register') end,
        attach_ipc=function(ipc) return log('runtime.attach_ipc', ipc) end,
        detach_ipc=function() return log('runtime.detach_ipc') end,
        frame=function() return log('runtime.frame') end,
        logout=function() return log('runtime.logout') end,
        unload=function() return log('runtime.unload') end,
    }

    local startup = {}
    for _, name in ipairs({
        'discover_buff_children', 'roll_query', 'display_box_update', 'dual_wield_check',
        'two_hand_check', 'bridge_weapon_lock', 'resolve_weapon_lock', 'unlock',
        'main_engine', 'migration_notice', 'settings_reset_announce',
    }) do startup[name] = function() end end

    local service = lifecycle.new({
        events=events,
        scheduler=scheduler,
        ipc_factory=ipc_factory,
        runtime_events=runtime_events,
        display={hide=function() return log('display.hide') end, destroy=function() return log('display.destroy') end},
        keybinds={apply=function() return log('keybinds.apply') end, clear=function() return log('keybinds.clear') end},
        commands={register=function() return log('commands.register') end, unregister=function() return log('commands.unregister') end},
        action_runtime={reset=function() return log('action.reset') end},
        release_slots=function(reason) return log('release_slots', reason) end,
        reset_special=function(reason) return log('reset_special', reason) end,
        startup=startup,
    })

    a.equal(service.load({Keybinds={}}), true)
    local saw_register, saw_attach = false, false
    for _, call in ipairs(calls) do
        if call.name == 'runtime.register' then saw_register = true end
        if call.name == 'runtime.attach_ipc' then
            saw_attach = true
            a.equal(call.args[1], ipc_instances[1], 'runtime bridge must attach the same fresh IPC instance lifecycle polls')
        end
    end
    a.equal(saw_register, true, 'load must register packet_in/packet_out runtime bridge')
    a.equal(saw_attach, true, 'load must attach Rahvin IPC dispatch to current transport')

    local frame = registered['d3d_present:rahvings_runtime_tick']
    a.equal(type(frame), 'function')
    a.equal(registered['logout:rahvings_runtime_logout'], nil,
        'Ashita v4 has no native logout event; logout ownership must come from packet_in 0x00B')
    local before_frame = #calls
    frame()
    local frame_names = {}
    for i = before_frame + 1, #calls do frame_names[#frame_names + 1] = calls[i].name end
    a.deep_equal(frame_names, {'scheduler.tick', 'ipc.poll', 'runtime.frame'},
        'one Ashita frame must drive scheduler, IPC transport and Rahvin prerender bridge exactly once')

    local before_logout = #calls
    a.equal(service.logout(), true)
    local logout_names = {}
    for i = before_logout + 1, #calls do logout_names[#logout_names + 1] = calls[i].name end
    a.equal(logout_names[1], 'runtime.logout',
        'Rahvin logout handlers must run before runtime teardown removes their event surface')
    local detach_index, close_index
    for i, name in ipairs(logout_names) do
        if name == 'runtime.detach_ipc' then detach_index = i end
        if name == 'ipc.close' then close_index = i end
    end
    a.equal(type(detach_index), 'number', 'logout must detach platform IPC listener')
    a.equal(type(close_index), 'number', 'logout must close transport')
    a.equal(detach_index < close_index, true, 'IPC listener must detach before transport closes')

    a.equal(service.load({Keybinds={}}), true)
    a.equal(generation, 2)
    local register_count, attach2 = 0, false
    for _, call in ipairs(calls) do
        if call.name == 'runtime.register' then register_count = register_count + 1 end
        if call.name == 'runtime.attach_ipc' and call.args[1] == ipc_instances[2] then attach2 = true end
    end
    a.equal(register_count, 2,
        'load after logout must re-register packet hooks removed by events.unregister_all')
    a.equal(attach2, true, 'load after logout must attach the new IPC generation')

    local before_unload = #calls
    a.equal(service.unload(), true)
    local unload_names = {}
    for i = before_unload + 1, #calls do unload_names[#unload_names + 1] = calls[i].name end
    local saw_runtime_unload = false
    for _, name in ipairs(unload_names) do if name == 'runtime.unload' then saw_runtime_unload = true end end
    a.equal(saw_runtime_unload, true,
        'profile unload must clear the completed Rahvin Windower-shaped handler generation')
end
