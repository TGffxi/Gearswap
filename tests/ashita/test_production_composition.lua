local a = require('tests.lib.assertions')

return function()
    local previous_native_module = package.loaded['ashita.native']
    local resolved_native
    local native_production_calls = {}
    package.loaded['ashita.native'] = {
        production=function(deps)
            native_production_calls[#native_production_calls + 1] = deps
            return resolved_native
        end,
    }
    package.loaded['ashita.composition'] = nil
    local composition = require('ashita.composition')
    a.equal(type(composition.new), 'function', 'production composition must expose new(deps)')

    local native_calls = {}
    local function mark(name, value)
        return function(...)
            native_calls[#native_calls + 1] = {name=name, args={...}}
            return value
        end
    end

    local resources = {
        items={{id=1}}, buffs={}, job_abilities={}, weapon_skills={}, spells={},
        elements={}, zones={}, jobs={}, bags={},
    }
    local native = {
        resources=resources,
        chat=mark('chat', true),
        send_command=mark('send_command', true),
        input=mark('input', true),
        window_settings=mark('window_settings', {ui_x_res=1920, ui_y_res=1080}),
        wc_match=mark('wc_match', true),
        get_info=mark('get_info', {language='english', logged_in=true}),
        get_abilities=mark('get_abilities', {job_traits={}}),
        get_party=mark('get_party', {p0={name='Tester'}}),
        get_mob_by_id=mark('get_mob_by_id', nil),
        get_mob_by_index=mark('get_mob_by_index', nil),
        get_player=mark('get_player', {id=111,index=22,name='Tester'}),
        inject_outgoing=mark('inject_outgoing', true),
        gettime=mark('gettime', 123.5),
        load_config=function(path, defaults)
            native_calls[#native_calls + 1] = {name='load_config', args={path, defaults}}
            return defaults
        end,
        save_config=mark('save_config', true),
        decode_item=mark('decode_item', {status=5}),
        new_file=function(path)
            native_calls[#native_calls + 1] = {name='new_file', args={path}}
            return {path=path, exists=function() return false end, read=function() return nil end}
        end,
        prim={},
    }
    for _, op in ipairs({'create','delete','set_position','set_size','set_color','set_visibility'}) do
        native.prim[op] = mark('prim_' .. op, true)
    end
    -- schedule is intentionally absent. Composition must bind platform scheduling to the
    -- exact scheduler instance lifecycle ticks instead of accepting a second native queue.
    resolved_native = native

    local inventory = {iter_bag=function() return {} end}
    local recasts = {abilities=function() return {} end, spells=function() return {} end}

    local native_handlers = {}
    local unregisters = 0
    local events = {
        register=function(event, alias, fn)
            native_handlers[event .. ':' .. alias] = fn
            return true
        end,
        unregister_all=function()
            unregisters = unregisters + 1
            for key in pairs(native_handlers) do native_handlers[key] = nil end
            return true
        end,
    }

    local scheduled = {}
    local scheduler_ticks, scheduler_clears = 0, 0
    local scheduler = {
        schedule=function(fn, delay)
            scheduled[#scheduled + 1] = {fn=fn, delay=delay}
            return scheduled[#scheduled]
        end,
        tick=function()
            scheduler_ticks = scheduler_ticks + 1
            return 0
        end,
        clear=function()
            scheduler_clears = scheduler_clears + 1
            local count = #scheduled
            scheduled = {}
            return count
        end,
    }

    local ipc_listener
    local ipc_polls, ipc_closes, ipc_unsubscribes = 0, 0, 0
    local ipc = {
        subscribe=function(fn) ipc_listener = fn; return true end,
        unsubscribe=function(fn)
            a.equal(fn, ipc_listener, 'composition must detach the exact IPC listener it attached')
            ipc_listener = nil
            ipc_unsubscribes = ipc_unsubscribes + 1
            return true
        end,
        send_rahvin=function() return true end,
        poll=function() ipc_polls = ipc_polls + 1; return true end,
        close=function() ipc_closes = ipc_closes + 1; return true end,
    }

    local gfunc_calls = {}
    local gFunc = {
        EquipSet=function(set) gfunc_calls[#gfunc_calls + 1] = {'EquipSet', set}; return true end,
        Enable=function(slot) gfunc_calls[#gfunc_calls + 1] = {'Enable', slot}; return true end,
        Disable=function(slot) gfunc_calls[#gfunc_calls + 1] = {'Disable', slot}; return true end,
        CancelAction=function() gfunc_calls[#gfunc_calls + 1] = {'CancelAction'}; return true end,
    }
    local current_action
    local gData = {
        GetAction=function() return current_action end,
        GetActionTarget=function() return nil end,
        GetPlayer=function() return {Name='Tester'} end,
    }

    local snapshot_calls = 0
    local function snapshot()
        snapshot_calls = snapshot_calls + 1
        return {
            player={name='Tester', main_job='WAR', sub_job='SAM', id=111, index=22,
                status='Idle', tp=0, equipment={}, inventory={}},
            world={day='Firesday', weather='Clear', area='Test'},
            buffactive={}, buffs={}, pet={isvalid=false}, equipment={}, inventory={},
        }
    end

    local created_fonts = {}
    local fonts = {
        new=function(settings)
            local font = {
                visible=settings.visible,
                locked=settings.locked,
                can_focus=settings.can_focus,
                font_family=settings.font_family,
                font_height=settings.font_height,
                bold=settings.bold,
                italic=settings.italic,
                right_justified=settings.right_justified,
                color=settings.color,
                color_outline=settings.color_outline,
                padding=settings.padding,
                position_x=settings.position_x,
                position_y=settings.position_y,
                text=settings.text,
                background={
                    visible=settings.background and settings.background.visible or false,
                    color=settings.background and settings.background.color or 0,
                    locked=settings.background and settings.background.locked or false,
                    can_focus=settings.background and settings.background.can_focus or false,
                },
            }
            function font:get_text_size() return 100, 20 end
            function font:register() return true end
            function font:unregister() return true end
            function font:destroy() return true end
            created_fonts[#created_fonts + 1] = font
            return font
        end,
    }

    local previous_fonts_preload = package.preload['fonts']
    local previous_fonts_loaded = package.loaded['fonts']
    package.loaded['fonts'] = nil
    package.preload['fonts'] = function() return fonts end

    local display_hides, display_destroys = 0, 0
    local display = {
        hide=function() display_hides = display_hides + 1; return true end,
        destroy=function() display_destroys = display_destroys + 1; return true end,
    }
    local keybind_applies, keybind_clears = 0, 0
    local keybinds = {
        apply=function() keybind_applies = keybind_applies + 1; return true end,
        clear=function() keybind_clears = keybind_clears + 1; return true end,
    }
    local command_registers, command_unregisters = 0, 0
    local commands = {
        register=function() command_registers = command_registers + 1; return true end,
        unregister=function() command_unregisters = command_unregisters + 1; return true end,
    }
    local slot_releases, special_resets = 0, 0

    local settings = {Keybinds={}}
    local graph = composition.new({
        inventory=inventory,
        recasts=recasts,
        events=events,
        scheduler=scheduler,
        ipc_factory=function() return ipc end,
        ipc_to_rahvin=function(payload) return payload and payload.message or nil end,
        gData=gData,
        gFunc=gFunc,
        snapshot=snapshot,
        job_path='tests/fixtures/production_job',
        settings=settings,
        display=display,
        keybinds=keybinds,
        commands=commands,
        release_slots=function() slot_releases = slot_releases + 1; return true end,
        reset_special=function() special_resets = special_resets + 1; return true end,
    })

    a.equal(#native_production_calls, 1,
        'composition must build the production native adapter when deps.native is absent')
    a.equal(native_production_calls[1].scheduler, scheduler,
        'production native adapter must share lifecycle scheduler')
    a.equal(native_production_calls[1].gData, gData,
        'production native adapter must share LuAshitacast gData')

    a.equal(type(graph), 'table')
    a.equal(type(graph.profile), 'table', 'composition must return the installable LAC profile')
    a.equal(type(graph.platform), 'table', 'composition must expose its shared platform for diagnostics')
    a.equal(type(graph.env), 'table', 'composition must expose the Rahvin execution environment')
    a.equal(type(graph.env.texts), 'table', 'composition must install Ashita-backed texts compatibility')
    a.equal(type(graph.env.texts.new), 'function', 'production texts compatibility must expose new')
    a.equal(#created_fonts >= 2, true, 'unchanged Rahvin core must create status/debug Ashita font objects')
    a.equal(type(graph.engine), 'table', 'composition must bind Rahvin globals as one engine adapter')
    a.equal(type(graph.lifecycle), 'table', 'composition must build lifecycle around the same graph')
    a.equal(type(graph.runtime_events), 'table', 'composition must build runtime events around the same platform')
    a.equal(type(graph.action_runtime), 'table')
    a.equal(type(graph.state_runtime), 'table')
    a.equal(type(graph.backend), 'table')

    a.equal(graph.platform.resources, resources, 'composition must retain one production resource identity')
    a.equal(graph.env.require('resources').items, resources.items,
        'compat resources must resolve through the same platform resource collections')
    a.equal(graph.profile.Sets, graph.env.sets, 'LAC profile and Rahvin environment must share the same sets table')
    a.equal(graph.profile._backend, graph.backend, 'GearSwap and bootstrap must share one LAC equip backend')
    a.equal(graph.profile._runtime, graph.action_runtime, 'bootstrap must use the graph action runtime')
    a.equal(graph.action_runtime.engine, graph.engine, 'action runtime must invoke the same Rahvin engine adapter')
    a.equal(graph.state_runtime.engine, graph.engine, 'state runtime must invoke the same Rahvin engine adapter')

    a.equal(graph.env.Rahvin_GS, '2.1', 'unchanged Rahvin engine must load inside the production environment')
    for _, name in ipairs({'pretarget','precast','midcast','aftercast','status_change','buff_change','pet_change'}) do
        a.equal(type(graph.env[name]), 'function', 'Rahvin engine global missing after production load: ' .. name)
    end
    for _, name in ipairs({'load','unload','command','default','pretarget','precast','midcast','preshot','midshot',
        'aftercast','status_change','buff_change','pet_change','is_busy'}) do
        a.equal(type(graph.engine[name]), 'function', 'production engine adapter missing method: ' .. name)
    end

    -- Rahvin's root schedules eleven delayed startup functions while it loads. Production
    -- composition must capture those registrations and hand them to lifecycle, not enqueue
    -- them early and then enqueue an identical second set during lifecycle.load().
    a.equal(#scheduled, 0, 'Rahvin startup work must not enter the live scheduler before LAC OnLoad')

    local direct_scheduled = false
    graph.env.coroutine.schedule(function() direct_scheduled = true end, 9)
    a.equal(#scheduled, 1, 'runtime coroutine.schedule must use the lifecycle scheduler instance')
    a.equal(scheduled[1].delay, 9)
    a.equal(direct_scheduled, false)

    local prerenders, ipc_messages = 0, {}
    graph.env.windower.register_event('prerender', function() prerenders = prerenders + 1 end)
    graph.env.windower.register_event('ipc message', function(message) ipc_messages[#ipc_messages + 1] = message end)

    graph.profile.OnLoad()
    a.equal(graph.env.production_fixture_loads, 1, 'LAC OnLoad must call the loaded Rahvin job get_sets exactly once')
    a.equal(#scheduled, 12,
        'lifecycle must add exactly the eleven captured Rahvin startup tasks to the same scheduler queue')
    a.equal(keybind_applies, 1)
    a.equal(command_registers, 1)
    a.equal(slot_releases, 1)
    a.equal(type(ipc_listener), 'function', 'lifecycle IPC generation must attach to the shared platform')

    -- GearSwap cancellation is action-scoped state, not only a low-level LAC primitive.
    -- cancel_spell() must expose the flag to Rahvin in the same pretarget/precast scope, and
    -- a later action must begin with a fresh false flag rather than inheriting stale cancel.
    graph.env._global.cancel_spell = false
    graph.env.cancel_spell()
    a.equal(graph.env._global.cancel_spell, true,
        'cancel_spell must set GearSwap _global.cancel_spell for Rahvin to observe')
    a.equal(gfunc_calls[#gfunc_calls][1], 'CancelAction',
        'cancel_spell must still invoke the LuAshitacast cancel primitive')

    graph.env._global.cancel_spell = true
    local cancel_seen_at_pretarget
    graph.env.pretarget_custom = function()
        cancel_seen_at_pretarget = graph.env._global.cancel_spell
    end
    -- Exercise only the Wave-2 ownership boundary here. Running a complete HandleItem would
    -- deliberately enter later pet/build logic whose pet_midaction compatibility belongs to
    -- Wave 5 and must not become an accidental prerequisite for this gate.
    graph.engine.pretarget({
        action_type='Item', type='Item', name='Echo Drops', english='Echo Drops',
        id=100, target={name='Tester', type='SELF'},
    })
    a.equal(cancel_seen_at_pretarget, false,
        'a new player action must reset stale GearSwap cancel state before Rahvin pretarget')
    graph.env.pretarget_custom=nil

    -- Wave 3: wrapped Windower events are one GearSwap transaction. Refresh globals once
    -- before all handlers, merge every equip request, then commit exactly one EquipSet.
    local function equipset_count()
        local count = 0
        for _, call in ipairs(gfunc_calls) do
            if call[1] == 'EquipSet' then count = count + 1 end
        end
        return count
    end

    local wrapped_snapshot_before = snapshot_calls
    local wrapped_equips_before = equipset_count()
    local wrapped_order = {}
    graph.env.windower.register_event('wave3 wrapped', function()
        wrapped_order[#wrapped_order + 1] = 'first'
        a.equal(snapshot_calls, wrapped_snapshot_before + 1,
            'wrapped event must refresh GearSwap globals before its first handler')
        graph.env.equip({head='Wrapped Helm'})
    end)
    graph.env.windower.register_event('wave3 wrapped', function()
        wrapped_order[#wrapped_order + 1] = 'second'
        a.equal(snapshot_calls, wrapped_snapshot_before + 1,
            'wrapped event must refresh only once for all handlers')
        graph.env.equip({body='Wrapped Mail'})
    end)
    a.equal(graph.platform:emit('wave3 wrapped'), 2)
    a.deep_equal(wrapped_order, {'first','second'})
    a.equal(snapshot_calls, wrapped_snapshot_before + 1,
        'wrapped event must own exactly one snapshot refresh')
    a.equal(equipset_count(), wrapped_equips_before + 1,
        'wrapped event must flush all handler gear exactly once')
    local wrapped_set = gfunc_calls[#gfunc_calls][2]
    a.equal(wrapped_set.Head, 'Wrapped Helm')
    a.equal(wrapped_set.Body, 'Wrapped Mail')

    -- Raw handlers deliberately cannot commit gear. Any equip buffered inside the raw scope
    -- must be discarded at that boundary and must never leak into a later wrapped event.
    local raw_snapshot_before = snapshot_calls
    local raw_equips_before = equipset_count()
    graph.env.windower.raw_register_event('wave3 raw', function()
        graph.env.equip({head='Raw Leak Helm'})
    end)
    a.equal(graph.platform:emit('wave3 raw'), 1)
    a.equal(snapshot_calls, raw_snapshot_before,
        'raw event must not run GearSwap wrapped snapshot refresh')
    a.equal(equipset_count(), raw_equips_before,
        'raw event must not commit buffered equipment')

    graph.env.windower.register_event('wave3 after raw', function() end)
    a.equal(graph.platform:emit('wave3 after raw'), 1)
    a.equal(equipset_count(), raw_equips_before,
        'equipment buffered by a raw event must be discarded, not flushed by the next wrapped event')

    -- Actual unchanged Rahvin registrations: target change and IPC are wrapped, while both
    -- prerender drivers are raw. These checks exercise the real root registrations.
    local target_snapshot_before = snapshot_calls
    graph.platform:emit('target change', 41, 40)
    a.equal(snapshot_calls, target_snapshot_before + 1,
        'Rahvin target change must execute with wrapped refresh semantics')

    local frame = native_handlers['d3d_present:rahvings_runtime_tick']
    a.equal(type(frame), 'function', 'composition lifecycle must own one native d3d frame handler')
    local frame_snapshot_before = snapshot_calls
    frame()
    a.equal(scheduler_ticks, 1, 'native frame must tick the shared scheduler')
    a.equal(ipc_polls, 1, 'native frame must poll the same IPC instance lifecycle attached')
    a.equal(prerenders, 1, 'native frame must reach Rahvin logical prerender handlers on the same platform')
    a.equal(snapshot_calls, frame_snapshot_before,
        'Rahvin prerender registrations are raw and must not refresh GearSwap globals')

    local ipc_snapshot_before = snapshot_calls
    ipc_listener({message='RAHVIN|TEST'})
    a.deep_equal(ipc_messages, {'RAHVIN|TEST'}, 'attached IPC must dispatch through the shared Rahvin event surface')
    a.equal(snapshot_calls, ipc_snapshot_before + 1,
        'Rahvin IPC message registration must execute with wrapped refresh semantics')

    local config = graph.env.require('config')
    local loaded = config.load('probe', {x=1})
    a.equal(loaded.x, 1)
    a.equal(native_calls[#native_calls].name, 'load_config', 'config compatibility must resolve through platform')
    local extdata = graph.env.require('extdata')
    extdata.decode({raw={Extra='x'}})
    a.equal(native_calls[#native_calls].name, 'decode_item', 'extdata compatibility must resolve through platform')
    local files = graph.env.require('files')
    local file = files.new('probe.txt')
    a.equal(file.path, 'probe.txt')
    a.equal(native_calls[#native_calls].name, 'new_file', 'files compatibility must resolve through platform')

    package.preload['fonts'] = previous_fonts_preload
    package.loaded['fonts'] = previous_fonts_loaded
    package.loaded['ashita.native'] = previous_native_module

    graph.profile.OnUnload()
    a.equal(graph.env.production_fixture_unloads, 1, 'LAC OnUnload must invoke Rahvin file_unload exactly once')
    a.equal(ipc_unsubscribes, 1, 'unload must detach the shared IPC listener')
    a.equal(ipc_closes, 1, 'unload must close the same IPC generation')
    a.equal(command_unregisters, 1)
    a.equal(keybind_clears, 1)
    a.equal(scheduler_clears, 1)
    a.equal(special_resets, 1)
    a.equal(display_destroys, 1)
    a.equal(unregisters, 1, 'unload must tear down the same native event registry')
end
