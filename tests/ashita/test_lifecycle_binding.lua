local a = require('tests.lib.assertions')
local lifecycle = require('ashita.lifecycle')

return function()
    local registered = {}
    local events = {
        register=function(event, alias, fn)
            registered[event .. ':' .. alias] = fn
            return true
        end,
        unregister_all=function()
            registered = {}
            return true
        end,
    }

    local scheduler = {
        schedule=function() return true end,
        tick=function() return true end,
        clear=function() return true end,
    }

    local closed = 0
    local service = lifecycle.new({
        events=events,
        scheduler=scheduler,
        ipc_factory=function()
            return {
                poll=function() return true end,
                close=function() closed = closed + 1; return true end,
            }
        end,
        display={hide=function() return true end, destroy=function() return true end},
        keybinds={apply=function() return true end, clear=function() return true end},
        commands={register=function() return true end, unregister=function() return true end},
        action_runtime={reset=function() return true end},
        release_slots=function() return true end,
        reset_special=function() return true end,
        startup={
            discover_buff_children=function() end,
            roll_query=function() end,
            display_box_update=function() end,
            dual_wield_check=function() end,
            two_hand_check=function() end,
            bridge_weapon_lock=function() end,
            resolve_weapon_lock=function() end,
            unlock=function() end,
            main_engine=function() end,
            migration_notice=function() end,
            settings_reset_announce=function() end,
        },
    })

    a.equal(service.load({Keybinds={}}), true)
    a.equal(type(registered['d3d_present:rahvings_runtime_tick']), 'function',
        'runtime frame event must be bound')
    local logout = registered['logout:rahvings_runtime_logout']
    a.equal(type(logout), 'function', 'Ashita logout event must call lifecycle.logout')

    logout()
    a.equal(service.is_running(), false, 'logout event must stop the runtime')
    a.equal(closed, 1, 'logout event must close the active IPC transport')
end
