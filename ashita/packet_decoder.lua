local M = {}

local function byte_at(data, index)
    if type(data) ~= 'string' then
        error('RahvinCompatError:packet_decoder.data', 4)
    end
    local value = data:byte(index)
    if value == nil then
        error('RahvinCompatError:packet_decoder.truncated', 4)
    end
    return value
end

local function reader(data, zero_based_byte)
    local bit_offset = (zero_based_byte or 0) * 8
    return function(bits)
        local value = 0
        for out_bit = 0, bits - 1 do
            local absolute = bit_offset + out_bit
            local byte_index = math.floor(absolute / 8) + 1
            local bit_index = absolute % 8
            local byte = byte_at(data, byte_index)
            local one = math.floor(byte / (2 ^ bit_index)) % 2
            if one ~= 0 then value = value + (2 ^ out_bit) end
        end
        bit_offset = bit_offset + bits
        return value
    end
end

local function u16le(data, zero_based_offset)
    local lo = byte_at(data, zero_based_offset + 1)
    local hi = byte_at(data, zero_based_offset + 2)
    return lo + hi * 256
end

local function production_zone_id()
    local core = rawget(_G, 'AshitaCore')
    if not core or type(core.GetMemoryManager) ~= 'function' then
        error('RahvinCompatError:packet_decoder.ashita_unavailable', 3)
    end
    local memory = core:GetMemoryManager()
    local party = memory and memory:GetParty()
    if not party or type(party.GetMemberZone) ~= 'function' then
        error('RahvinCompatError:packet_decoder.zone_unavailable', 3)
    end
    return tonumber(party:GetMemberZone(0))
end

local function production_target_index()
    local core = rawget(_G, 'AshitaCore')
    if not core or type(core.GetMemoryManager) ~= 'function' then
        error('RahvinCompatError:packet_decoder.ashita_unavailable', 3)
    end
    local memory = core:GetMemoryManager()
    local target = memory and memory:GetTarget()
    if not target or type(target.GetTargetIndex) ~= 'function' then
        error('RahvinCompatError:packet_decoder.target_unavailable', 3)
    end
    return tonumber(target:GetTargetIndex(0))
end

function M.new(source)
    source = source or {}
    local zone_id = source.zone_id or production_zone_id
    local target_index = source.target_index or production_target_index
    if type(zone_id) ~= 'function' or type(target_index) ~= 'function' then
        error('RahvinCompatError:packet_decoder.source', 2)
    end

    local last_zone = nil
    local service = {}

    function service.action(e)
        if type(e) ~= 'table' then return nil end
        local data = e.data or e.data_modified
        if type(data) ~= 'string' then return nil end

        -- Pinned Ashita v4 actionparse/parser.lua begins the bit-packed 0x028 body at
        -- zero-based byte position 5.  Values are read least-significant bit first.
        local read = reader(data, 5)
        local action = {
            actor_id = read(32),
            target_count = read(6),
        }
        action.reserved = read(4)
        action.category = read(4)
        action.param = read(32)
        action.recast = read(32)
        action.targets = {}

        for target_number = 1, action.target_count do
            local target = {
                id = read(32),
                action_count = read(4),
                actions = {},
            }
            for action_number = 1, target.action_count do
                local result = {
                    reaction = read(3),
                    animation = read(2),
                    effect = read(12),
                    stagger = read(5),
                    knockback = read(5),
                    param = read(17),
                    message = read(10),
                    unknown = read(31),
                }

                result.has_add_effect = read(1) ~= 0
                if result.has_add_effect then
                    result.add_effect_animation = read(6)
                    result.add_effect_effect = read(4)
                    result.add_effect_param = read(17)
                    result.add_effect_message = read(10)
                else
                    result.add_effect_animation = 0
                    result.add_effect_effect = 0
                    result.add_effect_param = 0
                    result.add_effect_message = 0
                end

                result.has_spike_effect = read(1) ~= 0
                if result.has_spike_effect then
                    result.spike_effect_animation = read(6)
                    result.spike_effect_effect = read(4)
                    result.spike_effect_param = read(14)
                    result.spike_effect_message = read(10)
                else
                    result.spike_effect_animation = 0
                    result.spike_effect_effect = 0
                    result.spike_effect_param = 0
                    result.spike_effect_message = 0
                end

                target.actions[action_number] = result
            end
            action.targets[target_number] = target
        end

        return action
    end

    function service.zone(e)
        if type(e) ~= 'table' then return nil, nil end
        local data = e.data_modified or e.data
        if type(data) ~= 'string' then return nil, nil end
        local new_zone = u16le(data, 0x30)
        local old_zone = last_zone
        if old_zone == nil then old_zone = zone_id() end
        last_zone = new_zone
        return new_zone, old_zone
    end

    function service.logout(e)
        if type(e) ~= 'table' then return false end
        local data = e.data or e.data_modified
        if type(data) ~= 'string' then return false end
        -- Pinned Ashita v4 settings.lua logout detector:
        -- incoming 0x00B is a real logout only when byte +0x04 equals 1.
        return byte_at(data, 0x04 + 1) == 1
    end

    function service.target_index(_)
        return target_index()
    end

    function service.reset_zone()
        last_zone = nil
    end

    return service
end

return M
