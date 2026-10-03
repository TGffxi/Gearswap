local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.ipc'] = nil
    local loaded, ipc = pcall(require, 'ashita.ipc')
    a.equal(loaded, true, 'SpellReceived parity requires the IPC bridge')

    local harness = require('tests.lib.rahvin_harness')
    local h = harness.new()
    local env = h.env

    a.equal(type(env.sr_ipc_message), 'function', 'unchanged Rahvin SpellReceived listener must be loaded')
    a.equal(type(env.sr_prerender), 'function', 'unchanged Rahvin failsafe driver must be loaded')
    env.state.SpellReceived:set('ON')
    env.sets.Cure_Received = { head='Received Helm', body='Received Mail' }

    local function msg(sender, kind, phase, action, target, timestamp)
        return ipc.to_rahvin({
            v=1, sender=sender, kind=kind, phase=phase, action=action or '',
            target=target or '', timestamp=timestamp,
        })
    end

    local before = #h.equipped
    env.sr_ipc_message(msg('CasterA','SPELL','START','1','Other',1000))
    a.equal(#h.equipped, before, 'message for another target must not equip received gear')

    env.sr_ipc_message(msg('CasterA','SPELL','START','1','Tester',1001))
    a.equal(#h.equipped, before + 1, 'first incoming caster equips Rahvin received set')
    local first = h.equipped[#h.equipped]
    a.equal(first.Head, 'Received Helm')
    a.equal(first.Body, 'Received Mail')
    a.equal(env.active_external_locks.head, true, 'received head slot is borrowed')
    a.equal(env.active_external_locks.body, true, 'received body slot is borrowed')
    a.equal(env.sr_failsafe_active(), true, 'incoming cast arms Rahvin failsafe')

    -- A second caster joins the same receive window without re-equipping; the hold remains
    -- until both completions arrive.
    env.sr_ipc_message(msg('CasterB','SPELL','START','1','Tester',1002))
    a.equal(#h.equipped, before + 1, 'second caster joins existing hold without duplicate equip')

    env.sr_ipc_message(msg('CasterA','CAST','COMPLETE','','',1003))
    a.equal(env.active_external_locks.head, true, 'one remaining caster keeps received gear held')
    env.sr_ipc_message(msg('CasterB','CAST','COMPLETE','','',1004))
    a.equal(next(env.active_external_locks), nil, 'last completion releases all received slots')
    a.equal(env.sr_failsafe_active(), false, 'normal completion disarms failsafe')

    -- Missing completion must still release through Rahvin's own prerender failsafe.
    env.settings.delay = -1
    env.sr_ipc_message(msg('CasterC','SPELL','START','1','Tester',1005))
    a.equal(env.active_external_locks.head, true)
    a.equal(env.sr_failsafe_active(), true)
    env.sr_prerender()
    a.equal(next(env.active_external_locks), nil, 'Rahvin failsafe releases stale borrowed gear')
    a.equal(env.sr_failsafe_active(), false)
end
