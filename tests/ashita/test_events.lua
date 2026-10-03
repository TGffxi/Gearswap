local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.events'] = nil
    local loaded, events = pcall(require, 'ashita.events')
    a.equal(loaded, true, 'ashita.events service must exist before Phase 3 Task 1 can pass')
    a.equal(type(events.new), 'function', 'events.new dependency-injection factory')

    local registered, unregistered, errors = {}, {}, {}
    local api = {
        register=function(event, alias, fn)
            registered[#registered+1] = {event=event, alias=alias, fn=fn}
            return true
        end,
        unregister=function(event, alias)
            unregistered[#unregistered+1] = {event=event, alias=alias}
            return true
        end,
    }
    local service = events.new(api, function(err) errors[#errors+1]=tostring(err) end)
    a.equal(type(service.register), 'function')
    a.equal(type(service.unregister_all), 'function')

    local calls = {}
    service.register('packet_in', 'phase3_packet', function(value) calls[#calls+1]=value end)
    service.register('packet_out', 'phase3_packet', function(value) calls[#calls+1]=value*10 end)
    a.equal(#registered, 2, 'same alias is allowed on different Ashita events')

    a.raises(function()
        service.register('packet_in', 'phase3_packet', function() end)
    end, 'RahvinCompatError:event_alias_duplicate', 'duplicate alias on one event must be rejected')

    registered[1].fn(2)
    registered[2].fn(3)
    a.deep_equal(calls, {2,30})

    service.register('d3d_present', 'phase3_broken', function() error('boom') end)
    local ok = pcall(registered[3].fn)
    a.equal(ok, true, 'registered callbacks must isolate callback errors')
    a.equal(#errors, 1, 'callback failure must be reported exactly once')

    service.unregister_all()
    a.equal(#unregistered, 3, 'bulk cleanup unregisters every installed handler')
    a.deep_equal(unregistered[1], {event='packet_in', alias='phase3_packet'})
    a.deep_equal(unregistered[2], {event='packet_out', alias='phase3_packet'})
    a.deep_equal(unregistered[3], {event='d3d_present', alias='phase3_broken'})

    service.unregister_all()
    a.equal(#unregistered, 3, 'bulk cleanup is idempotent')
end
