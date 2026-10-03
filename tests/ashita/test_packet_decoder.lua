local a = require('tests.lib.assertions')
local bit = require('bit')
local unpack = unpack or table.unpack

local function action_packet()
    -- Ashita v4 pinned source: addons/actionparse/parser.lua starts the packed
    -- 0x028 action body at byte position 5 and reads fields LSB-first.
    local bytes = {}
    for i = 1, 96 do bytes[i] = 0 end
    local pos, bitpos = 5, 0 -- zero-based byte position, matching bitreader:set_pos(5)

    local function write(value, bits)
        for x = 0, bits - 1 do
            local one = bit.band(bit.rshift(value, x), 1)
            if one ~= 0 then
                local index = pos + 1
                bytes[index] = bit.bor(bytes[index], bit.lshift(1, bitpos))
            end
            bitpos = bitpos + 1
            if bitpos == 8 then
                bitpos = 0
                pos = pos + 1
            end
        end
    end

    write(123456, 32) -- actor server id
    write(1, 6)       -- target count
    write(0, 4)       -- reserved/result summary
    write(6, 4)       -- category / cmd_no: job ability finish
    write(77, 32)     -- param / cmd_arg
    write(99, 32)     -- info

    write(654321, 32) -- target server id
    write(1, 4)       -- action/result count

    write(0, 3)       -- miss
    write(1, 2)       -- kind
    write(22, 12)     -- sub kind
    write(3, 5)       -- info
    write(4, 5)       -- scale
    write(777, 17)    -- action param/value
    write(123, 10)    -- message
    write(0, 31)      -- bit field

    write(1, 1)       -- has proc / add effect
    write(5, 6)       -- proc kind
    write(6, 4)       -- proc info
    write(888, 17)    -- proc value
    write(290, 10)    -- proc message (skillchain range)

    write(1, 1)       -- has react / spike effect
    write(2, 6)       -- react kind
    write(3, 4)       -- react info
    write(99, 14)     -- react value
    write(456, 10)    -- react message

    local used = pos + (bitpos > 0 and 1 or 0)
    local out = {}
    for i = 1, used do out[i] = bytes[i] end
    return string.char(unpack(out))
end

local function zone_packet(zone)
    -- Ashita v4 pinned source documents 0x00A zone id as uint16 LE at +0x30.
    local bytes = {}
    for i = 1, 0x32 do bytes[i] = 0 end
    bytes[0x30 + 1] = zone % 256
    bytes[0x31 + 1] = math.floor(zone / 256) % 256
    return string.char(unpack(bytes))
end

return function()
    local old_core = rawget(_G, 'AshitaCore')
    local ok, err = pcall(function()
        package.loaded['ashita.packet_decoder'] = nil
        local loaded, decoder_mod = pcall(require, 'ashita.packet_decoder')
        a.equal(loaded, true, 'production packet path requires ashita.packet_decoder')
        a.equal(type(decoder_mod.new), 'function', 'packet_decoder.new must expose dependency injection')

        local current_zone = 100
        local current_target = 777
        local decoder = decoder_mod.new({
            zone_id=function() return current_zone end,
            target_index=function() return current_target end,
        })

        local decoded = decoder.action({id=0x028, data=action_packet()})
        a.equal(decoded.actor_id, 123456)
        a.equal(decoded.category, 6)
        a.equal(decoded.param, 77)
        a.equal(decoded.targets[1].id, 654321)
        local act = decoded.targets[1].actions[1]
        a.equal(act.param, 777)
        a.equal(act.message, 123)
        a.equal(act.has_add_effect, true)
        a.equal(act.add_effect_animation, 5)
        a.equal(act.add_effect_effect, 6)
        a.equal(act.add_effect_param, 888)
        a.equal(act.add_effect_message, 290)
        a.equal(act.has_spike_effect, true)
        a.equal(act.spike_effect_animation, 2)
        a.equal(act.spike_effect_effect, 3)
        a.equal(act.spike_effect_param, 99)
        a.equal(act.spike_effect_message, 456)

        local new_zone, old_zone = decoder.zone({id=0x00A, data_modified=zone_packet(291)})
        a.equal(new_zone, 291)
        a.equal(old_zone, 100, 'first raw zone event must retain the zone being left')
        current_zone = 291
        local newer_zone, previous_zone = decoder.zone({id=0x00A, data_modified=zone_packet(292)})
        a.equal(newer_zone, 292)
        a.equal(previous_zone, 291, 'subsequent raw zone event must use decoder zone history')
        a.equal(decoder.target_index({id=0x015}), 777)

        -- Production packets.new without an injected decoder must use Ashita memory for
        -- old-zone and target state, and the raw decoder for 0x028.
        _G.AshitaCore = {
            GetMemoryManager=function()
                return {
                    GetParty=function()
                        return {GetMemberZone=function(_, index) a.equal(index, 0); return 100 end}
                    end,
                    GetTarget=function()
                        return {GetTargetIndex=function(_, index) a.equal(index, 0); return 888 end}
                    end,
                }
            end,
        }
        package.loaded['ashita.packet_decoder'] = nil
        package.loaded['ashita.packets'] = nil
        local packets = require('ashita.packets')
        local seen = {}
        local service = packets.new({
            zone_change=function(new, old) seen.zone={new,old} end,
            incoming_chunk=function() end,
            action=function(value) seen.action=value end,
            main_engine=function() end,
            target_change=function(new, old) seen.target={new,old} end,
        })
        a.equal(service.on_incoming({id=0x028, data=action_packet()}), true)
        a.equal(seen.action.actor_id, 123456,
            'packets default path must decode raw Ashita action packets')
        a.equal(service.on_incoming({id=0x00A, data_modified=zone_packet(291)}), true)
        a.deep_equal(seen.zone, {291,100}, 'packets default path must decode raw zone packet')
        service.on_outgoing({id=0x015, data=''})
        service.on_outgoing({id=0x015, data=''})
        a.equal(seen.target, nil, 'unchanged production target index must not synthesize a change')
    end)

    _G.AshitaCore = old_core
    package.loaded['ashita.packet_decoder'] = nil
    package.loaded['ashita.packets'] = nil
    if not ok then error(err, 0) end
end
