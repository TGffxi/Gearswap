local a = require('tests.lib.assertions')

return function()
    local old_preload = package.preload['socket']
    local old_loaded = package.loaded['socket']
    local old_clock = os.clock

    local function restore()
        package.preload['socket'] = old_preload
        package.loaded['socket'] = old_loaded
        os.clock = old_clock
        package.loaded['ashita.ipc'] = nil
    end

    local ok, err = pcall(function()
        package.loaded['socket'] = nil
        package.preload['socket'] = function()
            return {
                gettime=function() return 1700000000.125 end,
            }
        end
        os.clock = function() return 12.5 end
        package.loaded['ashita.ipc'] = nil

        local ipc = require('ashita.ipc')
        local wire
        local transport = {
            subscribe=function() return true end,
            send=function(raw) wire = raw; return true end,
        }
        local service = ipc.new(transport, {sender='Alice'})
        a.equal(service.send({kind='SPELL', phase='START', action='20', target='Bob'}), true)
        local decoded = ipc.decode(wire)
        a.equal(type(decoded), 'table', 'default-clock message must decode')
        a.equal(decoded.timestamp, 1700000000125,
            'production IPC clock must use wall time in Unix-epoch milliseconds, not process os.clock')
        service.close()
    end)

    restore()
    if not ok then error(err, 0) end
end
