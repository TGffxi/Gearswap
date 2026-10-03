local M = {}

local unpack = unpack or table.unpack

local function default_error(err)
    local message = 'RahvinCompatError:event_callback:' .. tostring(err)
    if type(print) == 'function' then print(message) end
end

function M.new(api, on_error)
    if type(api) ~= 'table' or type(api.register) ~= 'function' or type(api.unregister) ~= 'function' then
        error('RahvinCompatError:event_api', 2)
    end
    on_error = on_error or default_error

    local installed = {}
    local aliases = {}
    local service = {}

    local function report(err)
        pcall(on_error, err)
    end

    function service.register(event, alias, fn)
        if type(event) ~= 'string' or event == '' then error('RahvinCompatError:event_name', 2) end
        if type(alias) ~= 'string' or alias == '' then error('RahvinCompatError:event_alias', 2) end
        if type(fn) ~= 'function' then error('RahvinCompatError:event_callback', 2) end

        aliases[event] = aliases[event] or {}
        if aliases[event][alias] then
            error('RahvinCompatError:event_alias_duplicate:' .. event .. ':' .. alias, 2)
        end

        local function wrapped(...)
            local args = {...}
            local ok, err = pcall(function() return fn(unpack(args)) end)
            if not ok then report(err) end
        end

        local ok, result = pcall(api.register, event, alias, wrapped)
        if not ok then error('RahvinCompatError:event_register:' .. tostring(result), 2) end
        if result == false then error('RahvinCompatError:event_register:' .. event .. ':' .. alias, 2) end

        aliases[event][alias] = true
        installed[#installed + 1] = {event=event, alias=alias}
        return true
    end

    function service.unregister_all()
        local current = installed
        installed = {}
        aliases = {}
        for _, entry in ipairs(current) do
            local ok, result = pcall(api.unregister, entry.event, entry.alias)
            if not ok then
                report(result)
            elseif result == false then
                report('RahvinCompatError:event_unregister:' .. entry.event .. ':' .. entry.alias)
            end
        end
        return #current
    end

    return service
end

local default_service
local function production_service()
    if default_service then return default_service end
    local root = rawget(_G, 'ashita')
    local api = root and root.events
    if type(api) ~= 'table' then error('RahvinCompatError:ashita.events_unavailable', 3) end
    default_service = M.new(api, default_error)
    return default_service
end

function M.register(event, alias, fn)
    return production_service().register(event, alias, fn)
end

function M.unregister_all()
    if not default_service then return 0 end
    local count = default_service.unregister_all()
    default_service = nil
    return count
end

return M
