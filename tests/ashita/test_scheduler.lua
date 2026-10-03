local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.scheduler'] = nil
    local loaded, scheduler = pcall(require, 'ashita.scheduler')
    a.equal(loaded, true, 'ashita.scheduler service must exist before Phase 3 Task 1 can pass')
    a.equal(type(scheduler.new), 'function', 'scheduler.new dependency-injection factory')

    local now, errors = 100, {}
    local service = scheduler.new(function() return now end, function(err) errors[#errors+1]=tostring(err) end)
    a.equal(type(service.schedule), 'function')
    a.equal(type(service.tick), 'function')
    a.equal(type(service.clear), 'function')

    local calls = {}
    service.schedule(function() calls[#calls+1]='late' end, 3)
    service.schedule(function() calls[#calls+1]='same-a' end, 1)
    service.schedule(function() calls[#calls+1]='same-b' end, 1)
    service.schedule(function() error('scheduled boom') end, 2)
    service.schedule(function() calls[#calls+1]='after-error' end, 2)

    a.equal(service.tick(100.5), 0, 'nothing fires before due time')
    a.equal(service.tick(101), 2, 'same-time callbacks both fire')
    a.deep_equal(calls, {'same-a','same-b'}, 'same-time callbacks retain insertion order')

    a.equal(service.tick(102), 2, 'error callback and following callback are both consumed')
    a.deep_equal(calls, {'same-a','same-b','after-error'}, 'callback error does not stop later due work')
    a.equal(#errors, 1, 'scheduled callback failure is reported once')

    a.equal(service.tick(103), 1)
    a.deep_equal(calls, {'same-a','same-b','after-error','late'})
    a.equal(service.tick(200), 0, 'completed callbacks never repeat')

    service.schedule(function() calls[#calls+1]='must-not-run' end, 1)
    service.clear()
    a.equal(service.tick(500), 0, 'clear cancels pending work for unload')
    a.deep_equal(calls, {'same-a','same-b','after-error','late'})
end
