local include = require('compat.include')
local sets_compat = require('compat.sets')
local modes = require('compat.modes')
local M = {}
local function unsupported(name)
    return function() error('RahvinCompatError:' .. name, 2) end
end
function M.new(platform)
    local table_methods = {
        contains=function(self, wanted) for _, item in ipairs(self) do if item == wanted then return true end end return false end,
        insert=function(self, ...) table.insert(self, ...); return self end,
        concat=function(self, ...) return table.concat(self, ...) end,
        clear=function(self) for key in pairs(self) do self[key] = nil end; return self end,
    }
    local function wrapped_table(value)
        return setmetatable(value or {}, {__index=table_methods})
    end
    local function wrapped_set(value)
        value = value or {}
        local membership = {}
        for _, item in ipairs(value) do membership[item] = true end
        return setmetatable(value, {__index=function(_, key)
            local method = table_methods[key]
            if method ~= nil then return method end
            return membership[key]
        end})
    end
    local env = {
        sets={}, set_combine=sets_compat.combine, M=modes.M, S=wrapped_set, T=wrapped_table,
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
function M.install_runtime(env, platform)
    local resources = require('compat.resources').new(platform)
    local modules = {
        config=require('compat.config').new(platform), resources=resources,
        extdata=require('compat.extdata').new(platform),
        socket={gettime=function() return platform.gettime and platform:gettime() or os.time() end},
        files={new=function(path)
            if type(platform.new_file) ~= 'function' then error('RahvinCompatError:files.new', 2) end
            return platform:new_file(path)
        end},
        xml={parse=function() error('RahvinCompatError:xml.parse', 2) end},
    }
    env.require = function(name)
        local value = modules[name]
        if value == nil then error('RahvinCompatError:require:' .. tostring(name), 2) end
        return value
    end
    local table_lib = {}; for key,value in pairs(table) do table_lib[key]=value end
    table_lib.copy = require('compat.sets').copy
    table_lib.contains = function(values, wanted) for _,value in pairs(values) do if value == wanted then return true end end return false end
    env.table = table_lib
    string.contains = string.contains or function(value, needle) return value:find(needle, 1, true) ~= nil end
    string.startswith = string.startswith or function(value, prefix) return value:sub(1, #prefix) == prefix end
    string.endswith = string.endswith or function(value, suffix) return suffix == '' or value:sub(-#suffix) == suffix end
    string.trim = string.trim or function(value)
        return (tostring(value):gsub('^%s*(.-)%s*$', '%1'))
    end
    env.coroutine = {}; for key,value in pairs(coroutine) do env.coroutine[key]=value end
    env.coroutine.schedule = function(fn, delay)
        if type(platform.schedule) ~= 'function' then error('RahvinCompatError:schedule', 2) end
        return platform:schedule(fn, delay)
    end
    return env
end
return M
