local slots = require('compat.slots')
local sets = require('compat.sets')
local items = require('compat.item_normalizer')
local M = {}
local function need(backend, method)
    if type(backend[method]) ~= 'function' then error('RahvinCompatError:backend.' .. method, 3) end
    return backend[method]
end
local function translate(set)
    local result = {}
    for slot, item in pairs(set or {}) do result[slots.to_lac(slot)] = items.normalize(item) end
    return result
end
function M.install(env, backend)
    backend = backend or {}
    env.sets, env.set_combine = env.sets or {}, sets.combine
    env._global = env._global or {}
    if env._global.cancel_spell == nil then env._global.cancel_spell = false end
    env.empty = items.empty
    env.equip = function(set) return need(backend, 'equip')(backend, translate(set)) end
    env.enable = function(...) for i=1,select('#',...) do need(backend, 'enable')(backend, slots.to_lac(select(i,...))) end end
    env.disable = function(...) for i=1,select('#',...) do need(backend, 'disable')(backend, slots.to_lac(select(i,...))) end end
    env.cancel_spell = function(value)
        if value == nil then value = true end
        if type(value) ~= 'boolean' then error('RahvinCompatError:cancel_spell_argument', 2) end
        env._global.cancel_spell = value
        if value then return need(backend, 'cancel_action')(backend) end
        return false
    end
    return env
end
return M
