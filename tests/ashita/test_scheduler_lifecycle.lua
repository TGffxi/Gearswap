local a = require('tests.lib.assertions')

return function()
    local old_ashita = rawget(_G, 'ashita')
    local old_events = package.loaded['ashita.events']
    local old_scheduler = package.loaded['ashita.scheduler']
    local old_lifecycle = package.loaded['ashita.lifecycle']

    local active = {}
    local function key(event, alias) return event .. ':' .. alias end

    local function restore()
        rawset(_G, 'ashita', old_ashita)
        package.loaded['ashita.events'] = old_events
        package.loaded['ashita.scheduler'] = old_scheduler
        package.loaded['ashita.lifecycle'] = old_lifecycle
    end

    local ok, err = pcall(function()
        rawset(_G, 'ashita', {
            events={
                register=function(event, alias, fn)
                    active[key(event, alias)] = fn
                    return true
                end,
                unregister=function(event, alias)
                    active[key(event, alias)] = nil
                    return true
                end,
            },
        })
        package.loaded['ashita.events'] = nil
        package.loaded['ashita.scheduler'] = nil
        package.loaded['ashita.lifecycle'] = nil

        local events = require('ashita.events')
        local scheduler = require('ashita.scheduler')
        local lifecycle = require('ashita.lifecycle')

        local startup = {
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
        }

        local service = lifecycle.new({
            events=events,
            scheduler=scheduler,
            ipc_factory=function()
                return {poll=function() return 0 end, close=function() return true end}
            end,
            display={hide=function() return true end, destroy=function() return true end},
            keybinds={apply=function() return true end, clear=function() return true end},
            commands={register=function() return true end, unregister=function() return true end},
            action_runtime={reset=function() return true end},
            release_slots=function() return true end,
            reset_special=function() return true end,
            startup=startup,
        })

        a.equal(service.load({Keybinds={}}), true)
        local count = 0
        for name in pairs(active) do
            if name:match('^d3d_present:') then count = count + 1 end
        end
        a.equal(count, 1,
            'lifecycle must be the single d3d_present owner; scheduler must not bind a second hidden frame handler')
        a.equal(type(active['d3d_present:rahvings_runtime_tick']), 'function')

        a.equal(service.logout(), true)
        count = 0
        for name in pairs(active) do
            if name:match('^d3d_present:') then count = count + 1 end
        end
        a.equal(count, 0, 'logout must remove every runtime frame handler')

        a.equal(service.load({Keybinds={}}), true)
        count = 0
        for name in pairs(active) do
            if name:match('^d3d_present:') then count = count + 1 end
        end
        a.equal(count, 1, 'login/reload must restore exactly one runtime frame handler')
        a.equal(type(active['d3d_present:rahvings_runtime_tick']), 'function')
        service.unload()
    end)

    restore()
    if not ok then error(err, 0) end
end
