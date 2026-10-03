local M = {}

local DEFAULT_ALIAS = 'rahvings_command_bridge'

local function join_args(args)
    if type(args) == 'string' then return args end
    if type(args) ~= 'table' then
        error('RahvinCompatError:commands.args', 3)
    end

    local parts = {}
    for i = 1, #args do
        parts[#parts + 1] = tostring(args[i])
    end
    return table.concat(parts, ' ')
end

local function production_event_api()
    local root = rawget(_G, 'ashita')
    local api = root and root.events
    if type(api) ~= 'table'
        or type(api.register) ~= 'function'
        or type(api.unregister) ~= 'function' then
        error('RahvinCompatError:commands.events_unavailable', 3)
    end
    return api
end

local function production_dispatch(command)
    local fn = rawget(_G, 'self_command')
    if type(fn) ~= 'function' then
        error('RahvinCompatError:commands.dispatch_unconfigured', 3)
    end
    return fn(command)
end

function M.new(dispatch, event_api, alias)
    if type(dispatch) ~= 'function' then
        error('RahvinCompatError:commands.dispatch', 2)
    end
    if type(event_api) ~= 'table'
        or type(event_api.register) ~= 'function'
        or type(event_api.unregister) ~= 'function' then
        error('RahvinCompatError:commands.event_api', 2)
    end

    alias = alias or DEFAULT_ALIAS
    if type(alias) ~= 'string' or alias == '' then
        error('RahvinCompatError:commands.alias', 2)
    end

    local registered = false
    local service = {}

    function service.forward(args)
        return dispatch(join_args(args))
    end

    local function command_event(e)
        if type(e) ~= 'table' or type(e.command) ~= 'string' then return false end

        -- Ashita command events carry the original command line. Only consume the exact
        -- /rahvings namespace; everything after it is handed to the same Rahvin dispatcher
        -- used by /lac fwd, preserving the player's original argument case.
        local command = e.command
        local first, rest = command:match('^%s*(%S+)%s*(.-)%s*$')
        if not first or first:lower() ~= '/rahvings' then return false end

        e.blocked = true
        if rest == '' then
            return service.forward({})
        end
        return dispatch(rest)
    end

    function service.register()
        if registered then return true end
        local ok, result = pcall(event_api.register, 'command', alias, command_event)
        if not ok then
            error('RahvinCompatError:commands.register:' .. tostring(result), 2)
        end
        if result == false then
            error('RahvinCompatError:commands.register:' .. alias, 2)
        end
        registered = true
        return true
    end

    function service.unregister()
        if not registered then return true end
        local ok, result = pcall(event_api.unregister, 'command', alias)
        if not ok then
            error('RahvinCompatError:commands.unregister:' .. tostring(result), 2)
        end
        if result == false then
            error('RahvinCompatError:commands.unregister:' .. alias, 2)
        end
        registered = false
        return true
    end

    return service
end

local default_service

function M.configure(dispatch, event_api, alias)
    if default_service then default_service.unregister() end
    default_service = M.new(dispatch, event_api or production_event_api(), alias)
    return default_service
end

local function service()
    if not default_service then
        default_service = M.new(production_dispatch, production_event_api(), DEFAULT_ALIAS)
    end
    return default_service
end

function M.forward(args)
    return service().forward(args)
end

function M.register()
    return service().register()
end

function M.unregister()
    if not default_service then return true end
    return default_service.unregister()
end

return M
