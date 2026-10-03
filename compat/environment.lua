local include = require('compat.include')
local sets_compat = require('compat.sets')
local modes = require('compat.modes')
local M = {}
local function unsupported(name)
    return function() error('RahvinCompatError:' .. name, 2) end
end
function M.new(platform)
    local env = {
        sets={}, set_combine=sets_compat.combine, M=modes.M,
        equip=unsupported('equip'), enable=unsupported('enable'), disable=unsupported('disable'),
        cancel_spell=unsupported('cancel_spell'),
        _platform=platform or {},
    }
    env._G = env
    env.include = function(path) return include.load(path, env) end
    return setmetatable(env, {__index=_G})
end
function M.install_globals(env)
    local previous = {}
    for key, value in pairs(env) do
        if key ~= '_G' then previous[key] = {exists=rawget(_G, key) ~= nil, value=rawget(_G, key)}; rawset(_G, key, value) end
    end
    local handle = {}
    function handle:restore()
        for key, old in pairs(previous) do rawset(_G, key, old.exists and old.value or nil) end
    end
    return handle
end
return M
