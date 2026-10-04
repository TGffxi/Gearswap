local a = require('tests.lib.assertions')
local environment = require('compat.environment')

local function patch(data, offset, bytes)
    return data:sub(1, offset) .. bytes .. data:sub(offset + #bytes + 1)
end

local function le_u16(data, pos)
    local b1, b2 = data:byte(pos, pos + 1)
    return b1 + b2 * 0x100
end

local function le_u32(data, pos)
    local b1, b2, b3, b4 = data:byte(pos, pos + 3)
    return b1 + b2 * 0x100 + b3 * 0x10000 + b4 * 0x1000000
end

return function()
    local previous_struct = rawget(_G, 'struct')
    local previous_unpack = string.unpack

    local ok, err = pcall(function()
        local ffi = require('ffi')

        -- Pinned Ashita struct.unpack is 1-based for its byte position.  Windower's
        -- string:unpack callers use packet offsets directly (0x09, 0x19, 5), so the
        -- compatibility method must translate offset -> offset + 1 exactly once.
        _G.struct = {
            unpack=function(fmt, data, pos)
                if fmt == 'I' then return le_u32(data, pos) end
                if fmt == 'H' then return le_u16(data, pos) end
                if fmt == 'fff' then
                    local values = ffi.new('float[3]')
                    ffi.copy(values, data:sub(pos, pos + 11), 12)
                    return tonumber(values[0]), tonumber(values[1]), tonumber(values[2])
                end
                error('unexpected format: ' .. tostring(fmt))
            end,
        }
        string.unpack = nil

        local env = environment.new({resources={}})
        environment.install_runtime(env, {resources={}})
        a.equal(type(string.unpack), 'function',
            'Windower-compatible method-style string:unpack must be installed')

        -- Real Rahvin 0x029 offsets: target id at 0x09 and message id halfword at 0x19.
        local action_message = string.rep('\0', 0x20)
        action_message = patch(action_message, 0x09, string.char(0x78, 0x56, 0x34, 0x12))
        action_message = patch(action_message, 0x19, string.char(0x23, 0x81))
        a.equal(action_message:unpack('I', 0x09), 0x12345678,
            '0x029 target id must preserve Windower zero-based packet offset semantics')
        a.equal(action_message:unpack('H', 0x19), 0x8123,
            '0x029 message id must preserve Windower zero-based packet offset semantics')

        -- Real Rahvin 0x015 movement call uses data:unpack('fff', 5).
        local floats = ffi.new('float[3]')
        floats[0], floats[1], floats[2] = 1.25, -2.5, 3.75
        local movement = string.rep('\0', 5) .. ffi.string(floats, 12)
        local x, z, y = movement:unpack('fff', 5)
        a.equal(x, 1.25); a.equal(z, -2.5); a.equal(y, 3.75)
    end)

    string.unpack = previous_unpack
    rawset(_G, 'struct', previous_struct)
    if not ok then error(err, 0) end
end
