local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.platform'] = nil
    local platform = require('ashita.platform')

    local errors = {}
    local p = platform.new({
        inventory={iter_bag=function() return {} end},
        recasts={abilities=function() return {} end, spells=function() return {} end},
        ipc_to_rahvin=function() return nil end,
        on_event_error=function(name, err)
            errors[#errors + 1] = {name=name, err=tostring(err)}
        end,
    })

    local second = 0
    p:register_event('prerender', function() error('first prerender failed') end)
    p:register_event('prerender', function() second = second + 1 end)

    local ok, count = pcall(function() return p:emit('prerender') end)
    a.equal(ok, true,
        'one Rahvin event handler failure must not abort the Windower-shaped event dispatch')
    a.equal(count, 2)
    a.equal(second, 1,
        'later handlers on the same event must still run after an earlier handler fails')
    a.equal(#errors, 1, 'event failure must be reported exactly once')
    a.equal(errors[1].name, 'prerender')
end
