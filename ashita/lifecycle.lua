local M = {}

local STARTUP = {
    {'discover_buff_children', 1.9},
    {'roll_query', 1.9},
    {'display_box_update', 2.0},
    {'dual_wield_check', 2.1},
    {'two_hand_check', 2.2},
    {'bridge_weapon_lock', 2.2},
    {'resolve_weapon_lock', 2.2},
    {'unlock', 2.3},
    {'main_engine', 2.4},
    {'migration_notice', 2.5},
    {'settings_reset_announce', 2.6},
}

local function require_method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:lifecycle.' .. (label or name), 3)
    end
    return fn
end

function M.new(deps)
    if type(deps) ~= 'table' then
        error('RahvinCompatError:lifecycle.deps', 2)
    end

    local events = deps.events
    local scheduler = deps.scheduler
    local display = deps.display
    local keybinds = deps.keybinds
    local commands = deps.commands
    local action_runtime = deps.action_runtime
    local startup = deps.startup or {}

    local event_register = require_method(events, 'register', 'events.register')
    local event_unregister_all = require_method(events, 'unregister_all', 'events.unregister_all')
    local schedule = require_method(scheduler, 'schedule', 'scheduler.schedule')
    local scheduler_tick = require_method(scheduler, 'tick', 'scheduler.tick')
    local scheduler_clear = require_method(scheduler, 'clear', 'scheduler.clear')
    local display_hide = require_method(display, 'hide', 'display.hide')
    local display_destroy = require_method(display, 'destroy', 'display.destroy')
    local keybind_apply = require_method(keybinds, 'apply', 'keybinds.apply')
    local keybind_clear = require_method(keybinds, 'clear', 'keybinds.clear')
    local commands_register = require_method(commands, 'register', 'commands.register')
    local commands_unregister = require_method(commands, 'unregister', 'commands.unregister')
    local action_reset = require_method(action_runtime, 'reset', 'action_runtime.reset')

    if type(deps.ipc_factory) ~= 'function' then
        error('RahvinCompatError:lifecycle.ipc_factory', 2)
    end
    if type(deps.release_slots) ~= 'function' then
        error('RahvinCompatError:lifecycle.release_slots', 2)
    end
    if type(deps.reset_special) ~= 'function' then
        error('RahvinCompatError:lifecycle.reset_special', 2)
    end

    for _, step in ipairs(STARTUP) do
        if type(startup[step[1]]) ~= 'function' then
            error('RahvinCompatError:lifecycle.startup.' .. step[1], 2)
        end
    end

    local running = false
    local destroyed = false
    local ipc
    local service = {}

    local function frame_tick()
        if not running then return false end
        scheduler_tick()
        if ipc and type(ipc.poll) == 'function' then ipc.poll() end
        return true
    end

    local function stop(reason)
        if not running then return true end

        -- Stop every producer before releasing input, visuals and held equipment.
        scheduler_clear()
        action_reset()
        deps.reset_special(reason)
        keybind_clear()
        display_hide()
        if ipc and type(ipc.close) == 'function' then ipc.close() end
        ipc = nil
        commands_unregister()
        event_unregister_all()
        deps.release_slots(reason)
        running = false
        return true
    end

    function service.load(settings)
        if destroyed then return false, 'destroyed' end
        if running then return true end

        deps.release_slots('load')
        ipc = deps.ipc_factory()
        if type(ipc) ~= 'table' or type(ipc.poll) ~= 'function' or type(ipc.close) ~= 'function' then
            ipc = nil
            error('RahvinCompatError:lifecycle.ipc_service', 2)
        end

        commands_register()
        keybind_apply(settings)
        event_register('d3d_present', 'rahvings_runtime_tick', frame_tick)
        event_register('logout', 'rahvings_runtime_logout', function()
            return service.logout()
        end)

        for _, step in ipairs(STARTUP) do
            schedule(startup[step[1]], step[2])
        end

        running = true
        return true
    end

    function service.logout()
        if destroyed or not running then return true end
        return stop('logout')
    end

    function service.unload()
        if destroyed then return true end
        if running then stop('unload') end
        display_destroy()
        destroyed = true
        return true
    end

    function service.is_running()
        return running
    end

    function service.is_destroyed()
        return destroyed
    end

    return service
end

local default_service

function M.configure(deps)
    if default_service and not default_service.is_destroyed() then
        default_service.unload()
    end
    default_service = M.new(deps)
    return default_service
end

local function configured()
    if not default_service then
        error('RahvinCompatError:lifecycle.unconfigured', 3)
    end
    return default_service
end

function M.load(settings)
    return configured().load(settings)
end

function M.logout()
    if not default_service then return true end
    return default_service.logout()
end

function M.unload()
    if not default_service then return true end
    return default_service.unload()
end

return M
