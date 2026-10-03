local M = {}

local function require_method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:platform.' .. (label or name), 3)
    end
    return fn
end

function M.new(deps)
    deps = deps or {}

    local inventory = deps.inventory or require('ashita.inventory')
    local recasts = deps.recasts or require('ashita.recasts')
    local ipc_to_rahvin = deps.ipc_to_rahvin
    if ipc_to_rahvin == nil then
        ipc_to_rahvin = require('ashita.ipc').to_rahvin
    end
    if type(ipc_to_rahvin) ~= 'function' then
        error('RahvinCompatError:platform.ipc_to_rahvin', 2)
    end

    local iter_bag = require_method(inventory, 'iter_bag', 'inventory.iter_bag')
    local ability_recasts = require_method(recasts, 'abilities', 'recasts.abilities')
    local spell_recasts = require_method(recasts, 'spells', 'recasts.spells')

    local handlers = {}
    local current_ipc
    local current_ipc_listener
    local service = {}

    function service:register_event(name, fn)
        if type(name) ~= 'string' or name == '' then
            error('RahvinCompatError:platform.event_name', 2)
        end
        if type(fn) ~= 'function' then
            error('RahvinCompatError:platform.event_handler', 2)
        end
        local list = handlers[name]
        if not list then
            list = {}
            handlers[name] = list
        end
        list[#list + 1] = fn
        return fn
    end

    function service:emit(name, ...)
        local list = handlers[name]
        if not list then return 0 end
        local snapshot = {}
        for i = 1, #list do snapshot[i] = list[i] end
        for i = 1, #snapshot do snapshot[i](...) end
        return #snapshot
    end

    function service:clear_events()
        local count = 0
        for _, list in pairs(handlers) do count = count + #list end
        handlers = {}
        return count
    end

    function service:detach_ipc()
        if current_ipc and current_ipc_listener then
            local unsubscribe = require_method(current_ipc, 'unsubscribe', 'ipc.unsubscribe')
            unsubscribe(current_ipc_listener)
        end
        current_ipc = nil
        current_ipc_listener = nil
        return true
    end

    function service:attach_ipc(ipc)
        if type(ipc) ~= 'table' then
            error('RahvinCompatError:platform.ipc', 2)
        end
        local subscribe = require_method(ipc, 'subscribe', 'ipc.subscribe')
        require_method(ipc, 'unsubscribe', 'ipc.unsubscribe')
        require_method(ipc, 'send_rahvin', 'ipc.send_rahvin')

        service:detach_ipc()
        local listener = function(payload)
            local message = ipc_to_rahvin(payload)
            if message ~= nil then service:emit('ipc message', message) end
        end
        current_ipc = ipc
        current_ipc_listener = listener
        subscribe(listener)
        return true
    end

    function service:send_ipc(message, sender, timestamp)
        if not current_ipc then return false, 'ipc_unavailable' end
        return current_ipc.send_rahvin(message, sender, timestamp)
    end

    function service:get_items(bag)
        return iter_bag(bag)
    end

    function service:get_ability_recasts()
        return ability_recasts()
    end

    function service:get_spell_recasts()
        return spell_recasts()
    end

    return service
end

return M
