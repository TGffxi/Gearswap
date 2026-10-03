local packets = require('ashita.packets')

local M = {}

local function require_method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:runtime_events.' .. (label or name), 3)
    end
    return fn
end

function M.new(deps)
    deps = deps or {}

    local events = deps.events or require('ashita.events')
    local platform = deps.platform
    if type(platform) ~= 'table' then
        error('RahvinCompatError:runtime_events.platform', 2)
    end

    local event_register = require_method(events, 'register', 'events.register')
    require_method(platform, 'emit', 'platform.emit')
    require_method(platform, 'attach_ipc', 'platform.attach_ipc')
    require_method(platform, 'detach_ipc', 'platform.detach_ipc')
    require_method(platform, 'clear_events', 'platform.clear_events')

    local bridge = packets.new({
        zone_change=function(new_zone, old_zone)
            platform:emit('zone change', new_zone, old_zone)
        end,
        incoming_chunk=function(id, data, modified, injected, blocked)
            platform:emit('incoming chunk', id, data, modified, injected, blocked)
        end,
        action=function(value)
            platform:emit('action', value)
        end,
        main_engine=function(e)
            platform:emit('outgoing chunk', e.id, e.data, e.data_modified, e.injected, e.blocked)
        end,
        target_change=function(new_index, old_index)
            platform:emit('target change', new_index, old_index)
        end,
    }, deps.decoder)

    local registered = false
    local ipc_attached = false
    local service = {}

    local function packet_in(e)
        return bridge.on_incoming(e)
    end

    local function packet_out(e)
        return bridge.on_outgoing(e)
    end

    function service.register()
        if registered then return true end
        event_register('packet_in', 'rahvings_packet_in', packet_in)
        event_register('packet_out', 'rahvings_packet_out', packet_out)
        registered = true
        return true
    end

    function service.frame()
        return platform:emit('prerender')
    end

    function service.logout()
        return platform:emit('logout')
    end

    function service.attach_ipc(ipc)
        platform:attach_ipc(ipc)
        ipc_attached = true
        return true
    end

    function service.detach_ipc()
        if not ipc_attached then return true end
        platform:detach_ipc()
        ipc_attached = false
        return true
    end

    function service.unload()
        service.detach_ipc()
        platform:clear_events()
        bridge.reset_target()
        return true
    end

    return service
end

return M
