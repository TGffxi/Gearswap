local a = require('tests.lib.assertions')

local function memory_transport()
    local listeners = {}
    local transport = {}
    function transport.send(raw)
        for fn in pairs(listeners) do fn(raw) end
        return true
    end
    function transport.subscribe(fn)
        listeners[fn] = true
        return true
    end
    function transport.unsubscribe(fn)
        listeners[fn] = nil
        return true
    end
    function transport.emit(raw)
        for fn in pairs(listeners) do fn(raw) end
    end
    return transport
end

return function()
    package.loaded['ashita.ipc'] = nil
    local loaded, ipc = pcall(require, 'ashita.ipc')
    a.equal(loaded, true, 'ashita.ipc service must exist before Phase 3 Task 3 can pass')
    a.equal(ipc.VERSION, 1, 'wire payload version')
    a.equal(type(ipc.new), 'function')
    a.equal(type(ipc.encode), 'function')
    a.equal(type(ipc.decode), 'function')
    a.equal(type(ipc.from_rahvin), 'function')
    a.equal(type(ipc.to_rahvin), 'function')

    local payload = {
        v=1, sender='Caster', kind='SPELL', phase='START', action='1',
        target='Tester,Friend', timestamp=10000,
    }
    local wire = ipc.encode(payload)
    local decoded = ipc.decode(wire)
    a.deep_equal(decoded, payload, 'versioned payload round-trip preserves sender/action/target identity')
    a.equal(ipc.decode('not-an-ipc-payload'), nil, 'malformed payload rejected')

    local wrong_version = wire:gsub('^RGSIPC|1|', 'RGSIPC|2|')
    a.equal(ipc.decode(wrong_version), nil, 'unknown payload version rejected')

    local now = 10000
    local transport = memory_transport()
    local service = ipc.new(transport, {
        clock=function() return now end,
        max_age=5000,
        sender='Caster',
    })

    local first, second = {}, {}
    local function on_first(message) first[#first+1] = message end
    local function on_second(message) second[#second+1] = message end
    service.subscribe(on_first)
    service.subscribe(on_second)

    a.equal(service.send(payload), true)
    a.equal(#first, 1); a.equal(#second, 1)
    a.deep_equal(first[1], payload)

    -- Exact retransmission is transport duplication, not a second cast.
    transport.emit(wire)
    a.equal(#first, 1, 'duplicate message is idempotent')
    a.equal(#second, 1)

    transport.emit(ipc.encode({
        v=1, sender='OldCaster', kind='SPELL', phase='START', action='2',
        target='Tester', timestamp=4000,
    }))
    a.equal(#first, 1, 'stale payload rejected before subscribers can lock gear')

    service.unsubscribe(on_second)
    now = 10001
    local fresh = {
        v=1, sender='Caster2', kind='ABILITY', phase='START', action='20',
        target='Tester', timestamp=10001,
    }
    transport.emit(ipc.encode(fresh))
    a.equal(#first, 2)
    a.equal(#second, 1, 'unsubscribe stops delivery')
    a.deep_equal(first[2], fresh)

    local legacy_spell = 'RAHVIN|SPELL|Caster|Tester,Friend|1|10000'
    local normalized = ipc.from_rahvin(legacy_spell, 'Caster', 10000)
    a.deep_equal(normalized, payload, 'Rahvin spell announce normalizes into versioned payload')
    a.equal(ipc.to_rahvin(normalized), legacy_spell, 'Rahvin spell announce round-trips losslessly')

    local legacy_complete = 'RAHVIN|COMPLETE|Caster|10002'
    local complete = ipc.from_rahvin(legacy_complete, 'Caster', 10002)
    a.equal(complete.sender, 'Caster')
    a.equal(complete.kind, 'CAST')
    a.equal(complete.phase, 'COMPLETE')
    a.equal(ipc.to_rahvin(complete), legacy_complete)

    local rollq = ipc.from_rahvin('RAHVIN|ROLLQ|Tester', 'Caster', 10003)
    a.equal(rollq.sender, 'Caster'); a.equal(rollq.target, 'Tester'); a.equal(rollq.kind, 'ROLLQ')
    a.equal(ipc.to_rahvin(rollq), 'RAHVIN|ROLLQ|Tester')

    local roll = ipc.from_rahvin('RAHVIN|ROLL|Tester|310|11', 'Caster', 10004)
    a.equal(roll.kind, 'ROLL'); a.equal(roll.target, 'Tester'); a.equal(roll.action, '310,11')
    a.equal(ipc.to_rahvin(roll), 'RAHVIN|ROLL|Tester|310|11')

    a.equal(ipc.from_rahvin('OTHER|MESSAGE', 'Caster', 10000), nil, 'non-Rahvin legacy message rejected')
end
