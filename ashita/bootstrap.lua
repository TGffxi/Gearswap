local lac_data = require('ashita.lac_data')
local action_runtime = require('ashita.action_runtime')
local pet_runtime_module = require('ashita.pet_runtime')
local equip_backend = require('ashita.equip_backend')
local M = {}

local function invoke(engine, name, ...)
    local fn = engine[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:engine.' .. name, 3) end
    return fn(...)
end

local function invoke_optional(owner, name, ...)
    if owner == nil then return nil end
    local fn = owner[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:bootstrap.lifecycle.' .. name, 3) end
    return fn(...)
end

function M.create(deps)
    deps = deps or {}
    local gData = deps.gData or error('RahvinCompatError:bootstrap.gData', 2)
    local backend = deps.backend or equip_backend.new(deps.gFunc)
    local engine = deps.engine or {}
    local runtime = deps.action_runtime or action_runtime.new(engine, deps.clock)
    local pet_runtime = deps.pet_runtime or pet_runtime_module.new(engine)
    local state = deps.state_runtime
    local lifecycle = deps.lifecycle
    local settings = deps.settings or {}
    local profile = {Sets=deps.sets or {}}
    local function flush() return backend:flush() end
    local function refresh_action_snapshot()
        if type(deps.snapshot) ~= 'function' then
            error('RahvinCompatError:bootstrap.snapshot', 2)
        end
        return deps.snapshot(gData)
    end
    local function begin()
        refresh_action_snapshot()
        runtime:begin(lac_data.action(gData))
        flush()
    end
    local function middle()
        refresh_action_snapshot()
        runtime:midcast(lac_data.action(gData))
        flush()
    end

    profile.OnLoad=function()
        invoke(engine, 'load')
        flush()
        invoke_optional(lifecycle, 'load', settings)
    end
    profile.OnUnload=function()
        runtime:reset()
        pet_runtime:clear()
        invoke(engine, 'unload')
        flush()
        invoke_optional(lifecycle, 'unload')
    end
    profile.HandleCommand=function(args) invoke(engine, 'command', args); flush() end
    profile.HandleDefault=function()
        -- LuAshitacast exposes pet work only through GetPetAction while HandleDefault is
        -- running. Refresh the GearSwap-facing snapshot first, then advance the independent
        -- pet and player generations. Pet is observed before player aftercast so an already
        -- active LAC PetAction is visible to Rahvin's pet_midaction() during player cleanup.
        local snapshot
        if type(deps.snapshot) == 'function' then
            snapshot = deps.snapshot(gData)
        elseif state then
            error('RahvinCompatError:bootstrap.snapshot', 2)
        end

        local pet_changed = pet_runtime:update(lac_data.pet_action(gData))
        runtime:tick(lac_data.action(gData))

        if state then state:update(snapshot) end

        -- Pet midcast and pet aftercast each own their complete default tick. Repeated
        -- PetAction snapshots do not retrigger hooks, and ordinary idle/engaged gear resumes
        -- only on the next quiet tick after pet completion.
        if not runtime:is_active() and not pet_runtime:is_active() and not pet_changed then
            invoke(engine, 'default')
        end
        flush()
    end
    profile.HandleAbility=begin
    profile.HandleItem=begin
    profile.HandlePrecast=begin
    profile.HandleMidcast=middle
    profile.HandlePreshot=begin
    profile.HandleMidshot=middle
    profile.HandleWeaponskill=begin
    profile._runtime=runtime
    profile._pet_runtime=pet_runtime
    profile._backend=backend
    return profile
end

return M
