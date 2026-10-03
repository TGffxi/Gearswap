local M = {}

-- Packet ids are pinned against Ashita v4 / LuAshitacast sources used by this port.
-- 0x00A: zone/player initialization, 0x028: incoming action packet.
-- Rahvin's Windower TH death-message hook consumes packet 0x029.
M.IDS = {
    ZONE = 0x00A,
    ACTION = 0x028,
    ACTION_MESSAGE = 0x029,
}

local function require_handler(handlers, name)
    local fn = handlers and handlers[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:packets.handler.' .. tostring(name), 3)
    end
    return fn
end

function M.new(handlers, decoder)
    handlers = handlers or {}
    decoder = decoder or {}

    local zone_change = require_handler(handlers, 'zone_change')
    local incoming_chunk = require_handler(handlers, 'incoming_chunk')
    local action_handler = require_handler(handlers, 'action')
    local main_engine = require_handler(handlers, 'main_engine')
    local target_change = require_handler(handlers, 'target_change')

    local previous_target_index = nil
    local service = {}

    function service.on_action(decoded)
        if decoded == nil then return false end
        action_handler(decoded)
        return true
    end

    function service.on_incoming(e)
        if type(e) ~= 'table' then return false end

        if e.id == M.IDS.ACTION_MESSAGE then
            incoming_chunk(e.id, e.data, e.data_modified, e.injected, e.blocked)
            return true
        end

        if e.id == M.IDS.ACTION then
            local decoded = type(decoder.action) == 'function' and decoder.action(e) or e.decoded_action
            return service.on_action(decoded)
        end

        if e.id == M.IDS.ZONE then
            local new_zone, old_zone
            if type(decoder.zone) == 'function' then
                new_zone, old_zone = decoder.zone(e)
            else
                new_zone, old_zone = e.new_zone, e.old_zone
            end
            zone_change(new_zone, old_zone)
            -- Target indices are zone-local. The next outgoing tick establishes a fresh
            -- baseline rather than reporting a synthetic target change across zones.
            previous_target_index = nil
            return true
        end

        return false
    end

    function service.on_outgoing(e)
        -- Rahvin's original main_engine is driven by every outgoing chunk. Preserve that
        -- cadence rather than narrowing it to action packets.
        main_engine(e)

        if type(decoder.target_index) == 'function' then
            local current = decoder.target_index(e)
            if previous_target_index == nil then
                previous_target_index = current
            elseif current ~= previous_target_index then
                local old = previous_target_index
                previous_target_index = current
                target_change(current, old)
            end
        end
        return true
    end

    function service.reset_target()
        previous_target_index = nil
    end

    return service
end

return M
