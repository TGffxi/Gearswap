local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.lifecycle'] = nil
    local loaded, lifecycle = pcall(require, 'ashita.lifecycle')
    a.equal(loaded, true, 'Phase 4 Task 5 requires ashita.lifecycle')
    a.equal(type(lifecycle.new), 'function', 'lifecycle.new must expose an injectable lifecycle service')
    a.equal(type(lifecycle.load), 'function', 'lifecycle.load production interface must exist')
    a.equal(type(lifecycle.logout), 'function', 'lifecycle.logout production interface must exist')
    a.equal(type(lifecycle.unload), 'function', 'lifecycle.unload production interface must exist')

    local calls = {}
    local function log(name, ...)
        calls[#calls + 1] = {name=name, args={...}}
        return true
    end

    local registered = {}
    local events = {
        register=function(event, alias, fn)
            registered[event .. ':' .. alias] = fn
            return log('event.register', event, alias)
        end,
        unregister_all=function()
            registered = {}
            log('event.unregister_all')
            return true
        end,
    }

    local scheduled = {}
    local scheduler = {
        schedule=function(fn, delay)
            scheduled[#scheduled + 1] = {fn=fn, delay=delay}
            return scheduled[#scheduled]
        end,
        tick=function() return log('scheduler.tick') end,
        clear=function()
            scheduled = {}
            return log('scheduler.clear')
        end,
    }

    local ipc_generation = 0
    local ipc_instances = {}
    local function ipc_factory()
        ipc_generation = ipc_generation + 1
        local generation = ipc_generation
        local service = {
            poll=function() return log('ipc.poll', generation) end,
            close=function() return log('ipc.close', generation) end,
        }
        ipc_instances[#ipc_instances + 1] = service
        log('ipc.open', generation)
        return service
    end

    local display = {
        hide=function() return log('display.hide') end,
        destroy=function() return log('display.destroy') end,
    }
    local keybinds = {
        apply=function(settings) return log('keybinds.apply', settings) end,
        clear=function() return log('keybinds.clear') end,
    }
    local commands = {
        register=function() return log('commands.register') end,
        unregister=function() return log('commands.unregister') end,
    }
    local action = {reset=function() return log('action.reset') end}

    local startup = {}
    local startup_names = {
        'discover_buff_children', 'roll_query', 'display_box_update', 'dual_wield_check',
        'two_hand_check', 'bridge_weapon_lock', 'resolve_weapon_lock', 'unlock',
        'main_engine', 'migration_notice', 'settings_reset_announce',
    }
    for _, name in ipairs(startup_names) do
        startup[name] = function() return log('startup.' .. name) end
    end

    local settings = {Keybinds={offensemode='f12'}}
    local service = lifecycle.new({
        events=events,
        scheduler=scheduler,
        ipc_factory=ipc_factory,
        display=display,
        keybinds=keybinds,
        commands=commands,
        action_runtime=action,
        release_slots=function(reason) return log('release_slots', reason) end,
        reset_special=function(reason) return log('reset_special', reason) end,
        startup=startup,
    })

    -- Load begins from a clean slot state, creates a fresh transport, installs the command
    -- and key surfaces and registers one frame driver for scheduler + IPC polling.
    a.equal(service.load(settings), true)
    a.equal(calls[1].name, 'release_slots')
    a.equal(calls[1].args[1], 'load')
    a.equal(calls[2].name, 'ipc.open')
    a.equal(calls[3].name, 'commands.register')
    a.equal(calls[4].name, 'keybinds.apply')
    a.equal(calls[5].name, 'event.register')
    a.deep_equal(calls[5].args, {'d3d_present', 'rahvings_runtime_tick'})

    local expected_delays = {1.9, 1.9, 2.0, 2.1, 2.2, 2.2, 2.2, 2.3, 2.4, 2.5, 2.6}
    a.equal(#scheduled, #startup_names, 'Rahvin startup must retain every deferred step')
    for i, name in ipairs(startup_names) do
        a.equal(scheduled[i].fn, startup[name], 'startup callback order differs at ' .. name)
        a.equal(scheduled[i].delay, expected_delays[i], 'startup delay differs at ' .. name)
    end

    -- Repeated load during one profile generation is idempotent.
    local calls_after_load = #calls
    local scheduled_after_load = #scheduled
    a.equal(service.load(settings), true)
    a.equal(#calls, calls_after_load)
    a.equal(#scheduled, scheduled_after_load)

    -- One Ashita frame drives both deferred work and the active same-machine IPC transport.
    local frame = registered['d3d_present:rahvings_runtime_tick']
    a.equal(type(frame), 'function', 'runtime frame handler must be registered')
    frame()
    a.equal(calls[#calls - 1].name, 'scheduler.tick')
    a.equal(calls[#calls].name, 'ipc.poll')
    a.equal(calls[#calls].args[1], 1)

    -- Logout is a complete reversible runtime stop: no queued callback, packet/event hook,
    -- transport, held slot, keybind, visible overlay or in-flight action may survive it.
    local before_logout = #calls
    a.equal(service.logout(), true)
    local logout_names = {}
    for i = before_logout + 1, #calls do logout_names[#logout_names + 1] = calls[i].name end
    a.deep_equal(logout_names, {
        'scheduler.clear', 'action.reset', 'reset_special', 'keybinds.clear', 'display.hide',
        'ipc.close', 'commands.unregister', 'event.unregister_all', 'release_slots',
    }, 'logout teardown order must stop producers before releasing visible/input state')
    a.equal(calls[before_logout + 3].args[1], 'logout')
    a.equal(calls[#calls].args[1], 'logout')
    a.equal(#scheduled, 0, 'logout must clear deferred startup/subjob work')

    local after_logout = #calls
    a.equal(service.logout(), true)
    a.equal(#calls, after_logout, 'repeated logout must be idempotent')

    -- Login/profile re-entry after logout is supported without a process restart. It creates
    -- a new IPC service rather than trying to reuse the irreversibly closed transport.
    a.equal(service.load(settings), true)
    a.equal(ipc_generation, 2, 'load after logout must create a fresh IPC transport')
    local frame2 = registered['d3d_present:rahvings_runtime_tick']
    a.equal(type(frame2), 'function')
    frame2()
    a.equal(calls[#calls].name, 'ipc.poll')
    a.equal(calls[#calls].args[1], 2)

    -- Unload performs the same stop plus permanent renderer destruction. It is final and
    -- idempotent; a destroyed lifecycle cannot silently resurrect backend objects.
    local before_unload = #calls
    a.equal(service.unload(), true)
    a.equal(calls[#calls].name, 'display.destroy')
    local after_unload = #calls
    a.equal(service.unload(), true)
    a.equal(#calls, after_unload, 'repeated unload must be idempotent')
    local dead_load, dead_reason = service.load(settings)
    a.equal(dead_load, false)
    a.equal(dead_reason, 'destroyed')
    a.equal(#calls, after_unload, 'load after permanent unload must not recreate runtime state')
end
