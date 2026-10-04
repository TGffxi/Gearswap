local M = {}

local function require_method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:platform.' .. (label or name), 3)
    end
    return fn
end

local function default_event_error(name, err)
    if type(print) == 'function' then
        print('RahvinCompatError:event_handler:' .. tostring(name) .. ':' .. tostring(err))
    end
end

function M.new(deps)
    deps = deps or {}

    local inventory = deps.inventory or require('ashita.inventory')
    local recasts = deps.recasts or require('ashita.recasts')
    local native = deps.native
    local ipc_to_rahvin = deps.ipc_to_rahvin
    if ipc_to_rahvin == nil then
        ipc_to_rahvin = require('ashita.ipc').to_rahvin
    end
    if type(ipc_to_rahvin) ~= 'function' then
        error('RahvinCompatError:platform.ipc_to_rahvin', 2)
    end

    local on_event_error = deps.on_event_error or default_event_error
    if type(on_event_error) ~= 'function' then
        error('RahvinCompatError:platform.on_event_error', 2)
    end
    local on_event_begin = deps.on_event_begin
    local on_event_end = deps.on_event_end
    if on_event_begin ~= nil and type(on_event_begin) ~= 'function' then
        error('RahvinCompatError:platform.on_event_begin', 2)
    end
    if on_event_end ~= nil and type(on_event_end) ~= 'function' then
        error('RahvinCompatError:platform.on_event_end', 2)
    end

    local iter_bag = require_method(inventory, 'iter_bag', 'inventory.iter_bag')
    local ability_recasts = require_method(recasts, 'abilities', 'recasts.abilities')
    local spell_recasts = require_method(recasts, 'spells', 'recasts.spells')

    local handlers = {}
    local current_ipc
    local current_ipc_listener
    local service = {}

    -- The production composition supplies one native Ashita/LAC facade.  Keep these
    -- methods on the platform even in the pure-Lua harness so compatibility code has one
    -- stable surface; if composition omitted a capability, fail at the call site instead
    -- of silently pretending the Windower operation succeeded.
    local native_methods = {
        'chat', 'send_command', 'input', 'window_settings', 'wc_match', 'get_info',
        'get_abilities', 'get_party', 'get_mob_by_id', 'get_mob_by_index', 'get_player',
        'inject_outgoing', 'schedule', 'gettime', 'load_config', 'save_config',
        'decode_item', 'new_file',
    }
    for _, name in ipairs(native_methods) do
        local method_name = name
        service[method_name] = function(_, ...)
            local fn = require_method(native, method_name, 'native.' .. method_name)
            return fn(...)
        end
    end

    local primitive_methods = {
        create='prim_create',
        delete='prim_delete',
        set_position='prim_set_position',
        set_size='prim_set_size',
        set_color='prim_set_color',
        set_visibility='prim_set_visibility',
    }
    for native_name, platform_name in pairs(primitive_methods) do
        local primitive_name = native_name
        local method_name = platform_name
        service[method_name] = function(_, ...)
            local prim = native and native.prim
            local fn = require_method(prim, primitive_name, 'native.prim.' .. primitive_name)
            return fn(...)
        end
    end

    -- Resource collections are intentionally shared by identity.  compat.resources wraps
    -- the collections but must observe the exact same production snapshot as the rest of
    -- the platform; copying here would let resource state drift between adapters.
    service.resources = native and native.resources or nil

    local function register_event(name, fn, mode)
        if type(name) ~= 'string' or name == '' then
            error('RahvinCompatError:platform.event_name', 3)
        end
        if type(fn) ~= 'function' then
            error('RahvinCompatError:platform.event_handler', 3)
        end
        local list = handlers[name]
        if not list then
            list = {}
            handlers[name] = list
        end
        local entry = {fn=fn, mode=mode}
        list[#list + 1] = entry
        return fn
    end

    function service:register_event(name, fn)
        return register_event(name, fn, 'wrapped')
    end

    function service:raw_register_event(name, fn)
        return register_event(name, fn, 'raw')
    end

    local function begin_event(mode, name)
        if on_event_begin then
            local ok, err = pcall(on_event_begin, mode, name)
            if not ok then
                pcall(on_event_error, name, err)
                return false
            end
        end
        return true
    end

    local function end_event(mode, name)
        if on_event_end then
            local ok, err = pcall(on_event_end, mode, name)
            if not ok then pcall(on_event_error, name, err) end
        end
    end

    function service:emit(name, ...)
        local list = handlers[name]
        if not list then return 0 end
        local snapshot = {}
        for i = 1, #list do
            snapshot[i] = {fn=list[i].fn, mode=list[i].mode}
        end
        local args = {...}
        local unpack_args = unpack or table.unpack
        local index = 1
        while index <= #snapshot do
            local mode = snapshot[index].mode
            local last = index
            while last + 1 <= #snapshot and snapshot[last + 1].mode == mode do
                last = last + 1
            end

            local active = begin_event(mode, name)
            if active then
                for i = index, last do
                    local ok, err = pcall(snapshot[i].fn, unpack_args(args))
                    if not ok then
                        pcall(on_event_error, name, err)
                    end
                end
                end_event(mode, name)
            end
            index = last + 1
        end
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
