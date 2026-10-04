local platform_module = require('ashita.platform')
local runtime_events_module = require('ashita.runtime_events')
local lifecycle_module = require('ashita.lifecycle')
local action_runtime_module = require('ashita.action_runtime')
local pet_runtime_module = require('ashita.pet_runtime')
local command_runtime_module = require('ashita.command_runtime')
local validate_module = require('ashita.validate')
local state_runtime_module = require('ashita.state_runtime')
local equip_backend_module = require('ashita.equip_backend')
local bootstrap = require('ashita.bootstrap')
local environment = require('compat.environment')
local gearswap = require('compat.gearswap')
local windower = require('compat.windower')
local texts_compat = require('compat.texts')

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

local unpack_values = unpack or table.unpack

local function need(value, label)
    if value == nil then error('RahvinCompatError:composition.' .. label, 3) end
    return value
end

local function need_method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:composition.' .. (label or name), 3)
    end
    return fn
end

local function normalize_path(path)
    return tostring(path or ''):gsub('\\', '/'):gsub('%.lua$', '')
end

local function invoke_env(env, name, ...)
    local fn = env[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:engine.' .. name, 3)
    end
    return fn(...)
end

local function seed_environment(env, snapshot)
    if type(snapshot) ~= 'table' then return end
    if snapshot.player ~= nil then env.player = snapshot.player end
    if snapshot.world ~= nil then env.world = snapshot.world end
    if snapshot.buffactive ~= nil then env.buffactive = snapshot.buffactive end
    if snapshot.pet ~= nil then env.pet = snapshot.pet end

    if type(env.player) == 'table' then
        if snapshot.equipment ~= nil and env.player.equipment == nil then
            env.player.equipment = snapshot.equipment
        end
        if snapshot.inventory ~= nil and env.player.inventory == nil then
            env.player.inventory = snapshot.inventory
        end
    end
end

function M.new(deps)
    deps = deps or {}

    local scheduler = need(deps.scheduler, 'scheduler')
    need_method(scheduler, 'schedule', 'scheduler.schedule')
    need_method(scheduler, 'tick', 'scheduler.tick')
    need_method(scheduler, 'clear', 'scheduler.clear')

    local events = need(deps.events, 'events')
    local gData = need(deps.gData, 'gData')
    local gFunc = need(deps.gFunc, 'gFunc')

    local native = deps.native
    if native == nil then
        local native_module = require('ashita.native')
        local production = need_method(native_module, 'production', 'native.production')
        native = production({
            scheduler=scheduler,
            gData=gData,
        })
    end
    local snapshot_source = need(deps.snapshot, 'snapshot')
    if type(snapshot_source) ~= 'function' then
        error('RahvinCompatError:composition.snapshot', 2)
    end

    local startup_capture = {}
    local capturing_startup = false

    -- Never give Windower coroutine.schedule an independent queue.  During the unchanged
    -- Rahvin engine root load, capture only its eleven deferred startup registrations.
    -- As soon as that include returns, all subsequent scheduling goes to the exact scheduler
    -- instance lifecycle ticks.
    local native_facade = setmetatable({
        schedule=function(fn, delay)
            if type(fn) ~= 'function' then
                error('RahvinCompatError:composition.schedule_callback', 2)
            end
            if capturing_startup then
                local entry = {fn=fn, delay=delay}
                startup_capture[#startup_capture + 1] = entry
                return entry
            end
            return scheduler.schedule(fn, delay)
        end,
    }, {__index=native})

    local backend = equip_backend_module.new(gFunc)
    local capture_snapshot

    local platform = platform_module.new({
        native=native_facade,
        inventory=deps.inventory,
        recasts=deps.recasts,
        ipc_to_rahvin=deps.ipc_to_rahvin,
        on_event_error=deps.on_event_error,
        on_event_begin=function(mode)
            -- No GearSwap equip buffer may cross a logical event boundary. Wrapped events
            -- additionally refresh the user-facing globals once before their handlers.
            backend:discard()
            if mode == 'wrapped' then
                if type(capture_snapshot) ~= 'function' then
                    error('RahvinCompatError:composition.event_snapshot', 2)
                end
                capture_snapshot(gData)
            elseif mode ~= 'raw' then
                error('RahvinCompatError:composition.event_mode:' .. tostring(mode), 2)
            end
        end,
        on_event_end=function(mode)
            if mode == 'wrapped' then
                backend:flush()
            else
                backend:discard()
            end
        end,
    })

    local env = environment.new(platform)

    -- Install Windower command-language compatibility before the job file is included.
    -- Every shipped sample calls jobsetup() at file scope, so its wait/input/validate/self
    -- chain must already be routable while env.include(job_path) is still executing.
    local command_runtime = command_runtime_module.new({
        schedule=function(fn, delay) return scheduler.schedule(fn, delay) end,
        input=function(command)
            local fn = native_facade.input
            if type(fn) ~= 'function' then error('RahvinCompatError:native.input', 2) end
            return fn(command)
        end,
        raw_command=function(command)
            local fn = native_facade.send_command
            if type(fn) ~= 'function' then error('RahvinCompatError:native.send_command', 2) end
            return fn(command)
        end,
        cancel_buff=function(id)
            local fn = native_facade.cancel_buff
            if type(fn) ~= 'function' then error('RahvinCompatError:native.cancel_buff', 2) end
            return fn(id)
        end,
        execute_script=function(path)
            local fn = native_facade.execute_script
            if type(fn) ~= 'function' then error('RahvinCompatError:native.execute_script', 2) end
            return fn(path)
        end,
        self_command=function(command)
            return invoke_env(env, 'self_command', command)
        end,
        validate=function(args)
            return validate_module.validate(env, platform, args)
        end,
    })

    platform.send_command = function(_, command)
        return command_runtime:send(command)
    end

    environment.install_runtime(env, platform)
    gearswap.install(env, backend)
    env.windower = windower.new(platform)
    local fonts = deps.fonts
    if fonts == nil then
        local ok, loaded = pcall(require, 'fonts')
        if not ok then error('RahvinCompatError:composition.fonts:' .. tostring(loaded), 2) end
        fonts = loaded
    end
    env.texts = deps.texts or texts_compat.new(fonts)
    env._global = env._global or {}

    -- GearSwap exposes pet_midaction to user code from the moment the job environment is
    -- created. The concrete runtime is attached after Rahvin's globals have loaded; until
    -- then the query is safely false. Passing false reproduces GearSwap's explicit clear.
    local pet_runtime
    env.pet_midaction = function(value)
        if value == false then
            if pet_runtime then pet_runtime:clear() end
            return false
        end
        if value ~= nil and type(value) ~= 'boolean' then
            error('RahvinCompatError:pet_midaction_argument', 2)
        end
        if not pet_runtime or not pet_runtime:is_active() then return false end
        return true, pet_runtime:current()
    end

    capture_snapshot = function(data)
        local value = snapshot_source(data)
        seed_environment(env, value)
        return value
    end

    seed_environment(env, capture_snapshot(gData))

    -- Capture only the unchanged Rahvin root's startup schedules, not arbitrary job-file
    -- schedules.  Nested component includes inherit the capture flag until the root returns.
    local base_include = env.include
    env.include = function(path)
        if normalize_path(path) ~= 'RahvinGS/Rahvin-Engine' then
            return base_include(path)
        end

        local previous = capturing_startup
        capturing_startup = true
        local results = {pcall(base_include, path)}
        capturing_startup = previous
        if not results[1] then error(results[2], 2) end
        table.remove(results, 1)
        return unpack_values(results)
    end

    local job_path = need(deps.job_path, 'job_path')
    env.include(job_path)

    if #startup_capture ~= #STARTUP then
        error(('RahvinCompatError:composition.startup_count:%d'):format(#startup_capture), 2)
    end

    local startup = {}
    for index, spec in ipairs(STARTUP) do
        local captured = startup_capture[index]
        if captured.delay ~= spec[2] then
            error(('RahvinCompatError:composition.startup_delay:%s:%s')
                :format(spec[1], tostring(captured.delay)), 2)
        end
        startup[spec[1]] = captured.fn
    end

    -- The adapter deliberately resolves Rahvin globals at call time.  Job files may replace
    -- custom hooks after the engine root has loaded, so copying function values here would
    -- freeze stale references.
    local engine = {}

    engine.load = function()
        return invoke_env(env, 'get_sets')
    end

    engine.unload = function()
        return invoke_env(env, 'file_unload')
    end

    engine.command = function(args)
        if type(args) == 'table' then args = table.concat(args, ' ') end
        return invoke_env(env, 'self_command', args)
    end

    engine.default = function()
        local status = env.player and env.player.status or nil
        return invoke_env(env, 'status_change', status, status)
    end

    engine.pretarget = function(action)
        env._global.cancel_spell = false
        return invoke_env(env, 'pretarget', action)
    end
    engine.precast = function(action) return invoke_env(env, 'precast', action) end
    engine.midcast = function(action) return invoke_env(env, 'midcast', action) end
    engine.preshot = function(action) return invoke_env(env, 'precast', action) end
    engine.midshot = function(action) return invoke_env(env, 'midcast', action) end
    engine.aftercast = function(action) return invoke_env(env, 'aftercast', action) end
    engine.status_change = function(...) return invoke_env(env, 'status_change', ...) end
    engine.buff_change = function(...) return invoke_env(env, 'buff_change', ...) end
    engine.pet_change = function(...) return invoke_env(env, 'pet_change', ...) end
    engine.pet_midcast = function(...) return invoke_env(env, 'pet_midcast', ...) end
    engine.pet_aftercast = function(...) return invoke_env(env, 'pet_aftercast', ...) end
    engine.sub_job_change = function(...) return invoke_env(env, 'sub_job_change', ...) end
    engine.is_busy = function() return env.is_Busy == true end

    local action_runtime = action_runtime_module.new(engine, deps.clock)
    pet_runtime = pet_runtime_module.new(engine)
    local state_runtime = state_runtime_module.new(engine, platform)

    local lifecycle
    local runtime_events = runtime_events_module.new({
        events=events,
        platform=platform,
        decoder=deps.decoder,
        on_logout=function()
            if lifecycle == nil then
                error('RahvinCompatError:composition.logout_before_lifecycle', 2)
            end
            return lifecycle.logout()
        end,
    })

    lifecycle = lifecycle_module.new({
        events=events,
        scheduler=scheduler,
        ipc_factory=need(deps.ipc_factory, 'ipc_factory'),
        display=need(deps.display, 'display'),
        keybinds=need(deps.keybinds, 'keybinds'),
        commands=need(deps.commands, 'commands'),
        action_runtime=action_runtime,
        runtime_events=runtime_events,
        release_slots=need(deps.release_slots, 'release_slots'),
        reset_special=need(deps.reset_special, 'reset_special'),
        startup=startup,
    })

    local profile = bootstrap.create({
        gData=gData,
        gFunc=gFunc,
        backend=backend,
        engine=engine,
        action_runtime=action_runtime,
        pet_runtime=pet_runtime,
        command_runtime=command_runtime,
        state_runtime=state_runtime,
        lifecycle=lifecycle,
        settings=deps.settings or {},
        sets=env.sets,
        snapshot=capture_snapshot,
    })

    return {
        profile=profile,
        platform=platform,
        env=env,
        engine=engine,
        lifecycle=lifecycle,
        runtime_events=runtime_events,
        action_runtime=action_runtime,
        pet_runtime=pet_runtime,
        state_runtime=state_runtime,
        backend=backend,
    }
end

return M
