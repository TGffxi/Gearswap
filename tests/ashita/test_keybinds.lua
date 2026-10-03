local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.keybinds'] = nil
    local loaded, keybinds = pcall(require, 'ashita.keybinds')
    a.equal(loaded, true, 'Phase 4 Task 3 requires ashita.keybinds')
    a.equal(type(keybinds.new), 'function', 'keybinds.new must expose an injectable adapter')
    a.equal(type(keybinds.apply), 'function', 'keybinds.apply production interface must exist')
    a.equal(type(keybinds.clear), 'function', 'keybinds.clear production interface must exist')
    a.equal(type(keybinds.rebind), 'function', 'keybinds.rebind production interface must exist')

    local executed = {}
    local service = keybinds.new(function(command)
        executed[#executed + 1] = command
        return true
    end)

    local settings = {
        Keybinds = {
            offensemode='f12', treasurehunter='f11', weaponlock='f10', weaponmode='f9',
            jobmode='^f12', jobmode2='^f11', hoxne='!f10', spellreceived='~f9',
        },
    }

    -- Rahvin persists Windower key spelling. Ashita accepts the same Alt/Ctrl markers,
    -- but Shift is '+' rather than '~'. Bound commands enter the same LAC HandleCommand
    -- bridge as typed `/lac fwd ...` commands.
    a.equal(service.apply(settings), true)
    a.deep_equal(executed, {
        '/bind F12 /lac fwd OffenseMode',
        '/bind F9 /lac fwd WeaponMode',
        '/bind F10 /lac fwd WeaponLock',
        '/bind F11 /lac fwd TreasureHunter',
        '/bind ^F12 /lac fwd JobMode',
        '/bind ^F11 /lac fwd JobMode2',
        '/bind !F10 /lac fwd Hoxne',
        '/bind +F9 /lac fwd SpellReceived',
    }, 'all eight Rahvin mode keys must map to Ashita binds in Rahvin key-list order')

    local first_apply_count = #executed
    a.equal(service.apply(settings), true)
    a.equal(#executed, first_apply_count, 'reapplying identical settings must not duplicate binds')

    -- Rebind releases the held key before taking the new one, updates the same settings
    -- table for the caller's normal settings-save path, and returns the persisted Rahvin
    -- spelling rather than Ashita's translated spelling.
    local ok, persisted = service.rebind('offensemode', '~f8')
    a.equal(ok, true)
    a.equal(persisted, '~f8')
    a.equal(settings.Keybinds.offensemode, '~f8')
    a.equal(executed[#executed - 1], '/unbind F12')
    a.equal(executed[#executed], '/bind +F8 /lac fwd OffenseMode')

    -- A key already held by another Rahvin action is refused without changing either bind
    -- or the persistence table. The adapter never steals another action's key silently.
    local before_collision = #executed
    local old_weapon = settings.Keybinds.weaponmode
    local collision_ok, collision_reason = service.rebind('weaponmode', '~f8')
    a.equal(collision_ok, false)
    a.equal(collision_reason, 'collision')
    a.equal(#executed, before_collision)
    a.equal(settings.Keybinds.weaponmode, old_weapon)

    -- Empty persisted keys mean no bind. A later apply is the persistence handoff after a
    -- character settings reload: it changes only what differs and never accumulates stale
    -- bindings from the previous settings snapshot.
    local second = {Keybinds={}}
    for key, value in pairs(settings.Keybinds) do second.Keybinds[key] = value end
    second.Keybinds.jobmode2 = ''
    second.Keybinds.weaponlock = '^f6'
    local before_second = #executed
    a.equal(service.apply(second), true)
    a.equal(#executed, before_second + 3,
        'one removed bind plus one changed bind must produce exactly three operations')
    a.equal(executed[before_second + 1], '/unbind F10')
    a.equal(executed[before_second + 2], '/unbind ^F11')
    a.equal(executed[before_second + 3], '/bind ^F6 /lac fwd WeaponLock')

    -- Collision handling on bulk apply matches Rahvin's ordered ownership rule: the first
    -- row keeps the key and the later row is left unbound for this session.
    local collision_settings = {Keybinds={}}
    for key, value in pairs(second.Keybinds) do collision_settings.Keybinds[key] = value end
    collision_settings.Keybinds.weaponmode = collision_settings.Keybinds.offensemode
    local before_bulk_collision = #executed
    a.equal(service.apply(collision_settings), true)
    a.equal(#executed, before_bulk_collision + 1,
        'bulk collision should only release the later action old key')
    a.equal(executed[#executed], '/unbind F9')

    -- clear() releases only binds owned by this adapter; never `/unbind all`, which would
    -- destroy unrelated user binds. It is safe to call repeatedly during reload/unload.
    local before_clear = #executed
    a.equal(service.clear(), true)
    local cleared = {}
    for i = before_clear + 1, #executed do
        cleared[#cleared + 1] = executed[i]
        a.equal(executed[i] ~= '/unbind all', true, 'cleanup must preserve unrelated user binds')
    end
    a.equal(#cleared > 0, true, 'clear must release the adapter-owned binds')
    local after_clear = #executed
    a.equal(service.clear(), true)
    a.equal(#executed, after_clear, 'repeated clear must be idempotent')

    -- Unsupported action names and malformed keys fail closed without issuing commands.
    local before_bad = #executed
    local bad_action_ok = service.rebind('not-a-rahvin-action', 'f1')
    a.equal(bad_action_ok, false)
    local bad_key_ok = service.rebind('offensemode', 'ctrl+f5')
    a.equal(bad_key_ok, false, 'Rahvin parser owns human spelling normalization before this adapter')
    a.equal(#executed, before_bad)
end
