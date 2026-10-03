local lac_data = require('ashita.lac_data')
local action_runtime = require('ashita.action_runtime')
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
    local state = deps.state_runtime
    local lifecycle = deps.lifecycle
    local settings = deps.settings or {}
    local profile = {Sets=deps.sets or {}}
    local function flush() return backend:flush() end
    local function begin() runtime:begin(lac_data.action(gData)); flush() end
    local function middle() runtime:midcast(lac_data.action(gData)); flush() end

    profile.OnLoad=function()
        invoke(engine, 'load')
        flush()
        invoke_optional(lifecycle, 'load', settings)
    end
    profile.OnUnload=function()
        runtime:reset()
        invoke(engine, 'unload')
        flush()
        invoke_optional(lifecycle, 'unload')
    end
    profile.HandleCommand=function(args) invoke(engine, 'command', args); flush() end
    profile.HandleDefault=function()
        runtime:tick(lac_data.action(gData))
        if state then
            if type(deps.snapshot) ~= 'function' then error('RahvinCompatError:bootstrap.snapshot', 2) end
            state:update(deps.snapshot(gData))
        end
        if not runtime:is_active() then invoke(engine, 'default') end
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
    profile._backend=backend
    return profile
end

return M
