local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.ipc'] = nil
    local loaded, ipc = pcall(require, 'ashita.ipc')
    a.equal(loaded, true, 'SpellReceived parity requires the IPC bridge')

    local harness = require('tests.lib.rahvin_harness')
    local h = harness.new({settings={delay=-1}})
    local env = h.env
    local sr_ipc_message = h:event('ipc message')
    local sr_prerender = h:event('prerender', 2)

    a.equal(type(sr_ipc_message), 'function', 'unchanged Rahvin SpellReceived listener must be registered')
    a.equal(type(sr_prerender), 'function', 'unchanged Rahvin SpellReceived failsafe must be registered')
    env.state.SpellReceived:set('ON')
    env.sets.Cure_Received = { head='Received Helm', body='Received Mail' }

    local function msg(sender, kind, phase, action, target, timestamp)
        return ipc.to_rahvin({
            v=1, sender=sender, kind=kind, phase=phase, action=action or '',
            target=target or '', timestamp=timestamp,
        })
    end

    local before = #h.equipped
    sr_ipc_message(msg('CasterA','SPELL','START','1','Other',1000))
    a.equal(#h.equipped, before, 'message for another target must not equip received gear')

    sr_ipc_message(msg('CasterA','SPELL','START','1','Tester',1001))
    a.equal(#h.equipped, before + 1, 'first incoming caster equips Rahvin received set')
    local first = h.equipped[#h.equipped]
    a.equal(first.Head, 'Received Helm')
    a.equal(first.Body, 'Received Mail')
    a.equal(env.active_external_locks.head, true, 'received head slot is borrowed')
    a.equal(env.active_external_locks.body, true, 'received body slot is borrowed')

    -- A second caster joins the same receive window without re-equipping; the hold remains
    -- until both completions arrive.
    sr_ipc_message(msg('CasterB','SPELL','START','1','Tester',1002))
    a.equal(#h.equipped, before + 1, 'second caster joins existing hold without duplicate equip')

    sr_ipc_message(msg('CasterA','CAST','COMPLETE','','',1003))
    a.equal(env.active_external_locks.head, true, 'one remaining caster keeps received gear held')
    sr_ipc_message(msg('CasterB','CAST','COMPLETE','','',1004))
    a.equal(next(env.active_external_locks), nil, 'last completion releases all received slots')

    -- Missing completion must still release through Rahvin's own registered prerender
    -- failsafe. The harness loads the normal engine with only delay overridden to -1.
    sr_ipc_message(msg('CasterC','SPELL','START','1','Tester',1005))
    a.equal(env.active_external_locks.head, true)
    sr_prerender()
    a.equal(next(env.active_external_locks), nil, 'Rahvin failsafe releases stale borrowed gear')
end
