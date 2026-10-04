local a = require('tests.lib.assertions')

return function()
    local module_names = {
        'ashita.profile','ashita.composition','ashita.scheduler','ashita.events',
        'ashita.inventory','ashita.recasts','ashita.resources','ashita.snapshot',
        'ashita.native','ashita.ipc','ashita.commands','ashita.keybinds',
        'ashita.packet_decoder',
    }
    local saved = {}
    for _, name in ipairs(module_names) do saved[name] = package.loaded[name] end

    local old_core = rawget(_G, 'AshitaCore')
    local old_gdata = rawget(_G, 'gData')
    local old_gfunc = rawget(_G, 'gFunc')
    local old_ashita = rawget(_G, 'ashita')

    local function restore()
        for _, name in ipairs(module_names) do package.loaded[name] = saved[name] end
        rawset(_G, 'AshitaCore', old_core)
        rawset(_G, 'gData', old_gdata)
        rawset(_G, 'gFunc', old_gfunc)
        rawset(_G, 'ashita', old_ashita)
    end

    local ok, err = pcall(function()
        local core = {}
        local gData = {
            GetPlayer=function() return {Name='Tester'} end,
        }
        local enabled = {}
        local gFunc = {
            Enable=function(slot) enabled[#enabled + 1] = slot; return true end,
        }
        local raw_events = {
            register=function() return true end,
            unregister=function() return true end,
        }
        rawset(_G, 'AshitaCore', core)
        rawset(_G, 'gData', gData)
        rawset(_G, 'gFunc', gFunc)
        rawset(_G, 'ashita', {events=raw_events})

        local scheduler = {
            schedule=function() end,
            tick=function() end,
            clear=function() end,
        }
        local events = {
            register=function() end,
            unregister_all=function() end,
        }
        local inventory = {iter_bag=function() return {} end}
        local recasts = {abilities=function() return {} end, spells=function() return {} end}
        local resources = {items={},buffs={},job_abilities={},weapon_skills={},spells={},elements={},zones={},jobs={},bags={}}
        local snapshot_fn = function() return {player={},world={},buffactive={},pet={},equipment={},inventory={}} end
        local native = {resources=resources}

        local resources_calls = {}
        package.loaded['ashita.resources'] = {
            production=function(value)
                resources_calls[#resources_calls + 1] = value
                return resources
            end,
        }

        local snapshot_calls = {}
        package.loaded['ashita.snapshot'] = {
            production=function(deps)
                snapshot_calls[#snapshot_calls + 1] = deps
                return snapshot_fn
            end,
        }

        local native_calls = {}
        package.loaded['ashita.native'] = {
            production=function(deps)
                native_calls[#native_calls + 1] = deps
                return native
            end,
        }

        package.loaded['ashita.scheduler'] = scheduler
        package.loaded['ashita.events'] = events
        package.loaded['ashita.inventory'] = inventory
        package.loaded['ashita.recasts'] = recasts

        local decoder = {}
        local decoder_calls = 0
        package.loaded['ashita.packet_decoder'] = {
            new=function()
                decoder_calls = decoder_calls + 1
                return decoder
            end,
        }

        local transports, ipc_services, ipc_options = {}, {}, {}
        package.loaded['ashita.ipc'] = {
            to_rahvin=function(payload) return payload and payload.message end,
            localhost_transport=function()
                local transport = {generation=#transports + 1}
                transports[#transports + 1] = transport
                return transport
            end,
            new=function(transport, options)
                ipc_options[#ipc_options + 1] = options
                local service = {
                    transport=transport,
                    poll=function() return 0 end,
                    close=function() return true end,
                    subscribe=function() return true end,
                    unsubscribe=function() return true end,
                    send_rahvin=function() return true end,
                }
                ipc_services[#ipc_services + 1] = service
                return service
            end,
        }

        local command_dispatch
        local command_event_api
        local command_service = {
            register=function() return true end,
            unregister=function() return true end,
        }
        package.loaded['ashita.commands'] = {
            new=function(dispatch, event_api)
                command_dispatch = dispatch
                command_event_api = event_api
                return command_service
            end,
        }

        local clear_bridged_calls = 0
        package.loaded['ashita.keybinds'] = {
            clear_bridged=function()
                clear_bridged_calls = clear_bridged_calls + 1
                return true
            end,
        }

        local captured
        local engine_commands = {}
        local fake_profile = {
            Sets={sentinel=true},
            OnLoad=function() end,
            OnUnload=function() end,
            HandleCommand=function() end,
            HandleDefault=function() end,
            HandleAbility=function() end,
            HandleItem=function() end,
            HandlePrecast=function() end,
            HandleMidcast=function() end,
            HandlePreshot=function() end,
            HandleMidshot=function() end,
            HandleWeaponskill=function() end,
        }
        local graph = {
            profile=fake_profile,
            engine={
                command=function(value)
                    engine_commands[#engine_commands + 1] = value
                    return true
                end,
            },
            env={},
        }
        package.loaded['ashita.composition'] = {
            new=function(deps)
                captured = deps
                return graph
            end,
        }

        package.loaded['ashita.profile'] = nil
        local profile = require('ashita.profile')
        a.equal(type(profile.production), 'function',
            'profile.production(job_path) must build the installable LuAshitacast profile')

        local installed = profile.production('jobs/Test.lua')
        a.equal(type(installed), 'table')
        for _, name in ipairs({
            'OnLoad','OnUnload','HandleCommand','HandleDefault','HandleAbility','HandleItem',
            'HandlePrecast','HandleMidcast','HandlePreshot','HandleMidshot','HandleWeaponskill',
        }) do
            a.equal(type(installed[name]), 'function', 'production profile missing LAC callback: ' .. name)
        end
        a.equal(installed.Sets, fake_profile.Sets,
            'production root must expose the exact composition Sets table')

        a.equal(captured.job_path, 'jobs/Test.lua')
        a.equal(captured.scheduler, scheduler, 'production root must use one shared scheduler singleton')
        a.equal(captured.events, events, 'production root must use one shared event registry singleton')
        a.equal(captured.inventory, inventory)
        a.equal(captured.recasts, recasts)
        a.equal(captured.gData, gData)
        a.equal(captured.gFunc, gFunc)
        a.equal(captured.native, native)
        a.equal(captured.snapshot, snapshot_fn)
        a.equal(captured.decoder, decoder)
        a.equal(captured.commands, command_service)
        a.equal(type(captured.ipc_factory), 'function')
        a.equal(type(captured.ipc_to_rahvin), 'function')
        a.equal(type(captured.release_slots), 'function')
        a.equal(type(captured.reset_special), 'function')
        a.equal(type(captured.display), 'table')
        a.equal(type(captured.display.hide), 'function')
        a.equal(type(captured.display.destroy), 'function')
        a.equal(type(captured.keybinds), 'table')
        a.equal(type(captured.keybinds.apply), 'function')
        a.equal(type(captured.keybinds.clear), 'function')

        a.deep_equal(resources_calls, {core},
            'production resources must be constructed exactly once from the active AshitaCore')
        a.equal(#snapshot_calls, 1)
        a.equal(snapshot_calls[1].core, core)
        a.equal(snapshot_calls[1].gData, gData)
        a.equal(snapshot_calls[1].inventory, inventory)
        a.equal(snapshot_calls[1].resources, resources,
            'snapshot and native/platform must share the exact same resource identity')
        a.equal(#native_calls, 1)
        a.equal(native_calls[1].scheduler, scheduler)
        a.equal(native_calls[1].gData, gData)
        a.equal(native_calls[1].resources, resources)
        a.equal(decoder_calls, 1)

        a.equal(command_event_api, raw_events,
            'optional /rahvings alias must register on the active Ashita command event API')
        command_dispatch('WeaponMode')
        a.deep_equal(engine_commands, {'WeaponMode'},
            'command alias must dispatch into the same composition engine, not _G.self_command')

        -- Rahvin binds its own keys during the unchanged job include. Lifecycle apply must
        -- therefore be deliberately passive, while lifecycle clear owns logout cleanup of
        -- the translated bridge registry.
        a.equal(captured.keybinds.apply({Keybinds={}}), true)
        a.equal(clear_bridged_calls, 0,
            'lifecycle load must not create a second keybind owner')
        a.equal(captured.keybinds.clear(), true)
        a.equal(clear_bridged_calls, 1)

        local first_ipc = captured.ipc_factory()
        local second_ipc = captured.ipc_factory()
        a.equal(first_ipc ~= second_ipc, true,
            'every lifecycle login generation must get a fresh IPC service')
        a.equal(#transports, 2)
        a.equal(transports[1] ~= transports[2], true)
        a.equal(ipc_options[1].sender, 'Tester')
        a.equal(ipc_options[2].sender, 'Tester')

        captured.release_slots('logout')
        local slots = {}
        for _, value in ipairs(enabled) do slots[value] = true end
        for _, slot in ipairs({
            'Main','Sub','Range','Ammo','Head','Body','Hands','Legs','Feet',
            'Neck','Waist','Back','Ear1','Ear2','Ring1','Ring2',
        }) do
            a.equal(slots[slot], true, 'logout cleanup must release LAC slot: ' .. slot)
        end

        local bad = pcall(function() profile.production('') end)
        a.equal(bad, false, 'production profile must reject an empty job path')
    end)

    restore()
    if not ok then error(err, 0) end
end
