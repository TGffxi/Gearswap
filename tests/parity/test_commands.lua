local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.commands'] = nil
    local loaded, commands = pcall(require, 'ashita.commands')
    a.equal(loaded, true, 'Phase 4 Task 2 requires ashita.commands')
    a.equal(type(commands.new), 'function', 'commands.new must expose an injectable command bridge')
    a.equal(type(commands.forward), 'function', 'commands.forward production interface must exist')
    a.equal(type(commands.register), 'function', 'commands.register production interface must exist')
    a.equal(type(commands.unregister), 'function', 'commands.unregister production interface must exist')

    local harness = require('tests.lib.rahvin_harness')
    local h = harness.new()
    local env = h.env

    -- The bridge never owns Rahvin command semantics. It joins LAC's argument table and
    -- forwards the resulting line to the unchanged Rahvin self_command parser.
    local dispatched = {}
    local custom = {}
    env.self_command_custom = function(command)
        custom[#custom + 1] = command
    end

    local registrations, unregistrations = {}, {}
    local event_api = {
        register=function(event, alias, fn)
            registrations[#registrations + 1] = {event=event, alias=alias, fn=fn}
            return true
        end,
        unregister=function(event, alias)
            unregistrations[#unregistrations + 1] = {event=event, alias=alias}
            return true
        end,
    }

    local bridge = commands.new(function(command)
        dispatched[#dispatched + 1] = command
        return env.self_command(command)
    end, event_api)
    a.equal(type(bridge.forward), 'function')
    a.equal(type(bridge.register), 'function')
    a.equal(type(bridge.unregister), 'function')

    -- Read-only utility commands must pass through the exact Rahvin dispatcher without an
    -- Ashita-side duplicate parser.
    bridge.forward({'help'})
    bridge.forward({'version'})
    a.equal(dispatched[1], 'help')
    a.equal(dispatched[2], 'version')

    -- Preserve the original argument case while joining LAC args. Rahvin's profile command
    -- deliberately reads the original command string rather than its lowercase dispatch key.
    local sent = {}
    h.platform.send_command = function(_, command)
        sent[#sent + 1] = command
        return true
    end
    bridge.forward({'profile', 'My', 'Profile'})
    a.equal(dispatched[#dispatched], 'profile My Profile')
    a.equal(sent[#sent]:find('exec My_Profile/', 1, true) ~= nil, true,
        'free-text/case-sensitive Rahvin arguments must survive LAC forwarding')

    -- A valid mode argument changes the real Rahvin mode. A rejected value is claimed by
    -- Rahvin and must not leak into the job file custom-command hook.
    h:set_offense({'Normal', 'DT'}, 'Normal')
    bridge.forward({'OffenseMode', 'DT'})
    a.equal(env.state.OffenseMode.value, 'DT')
    local custom_before_invalid = #custom
    bridge.forward({'OffenseMode', 'Bogus'})
    a.equal(env.state.OffenseMode.value, 'DT', 'invalid mode must not alter the Rahvin state')
    a.equal(#custom, custom_before_invalid,
        'a Rahvin-rejected mode argument must not fall through to self_command_custom')

    -- Unknown commands still belong to the job file, exactly as they do under GearSwap.
    bridge.forward({'CustomThing', 'MixedCase'})
    a.equal(custom[#custom], 'customthing mixedcase')

    -- Save-as-you-change remains Rahvin behavior. The bridge only forwards; these values are
    -- observed at the existing config.save boundary after the unchanged handlers run.
    local saved = {}
    h.platform.save_config = function(_, value)
        saved[#saved + 1] = value
        return true
    end
    local function last_save()
        a.equal(#saved > 0, true, 'command was expected to save settings')
        return saved[#saved]
    end

    bridge.forward({'display', 'off'})
    a.equal(last_save().visible, false)
    bridge.forward({'displaymode', 'on'})
    a.equal(last_save().oneline, true)
    bridge.forward({'debug', 'on'})
    a.equal(last_save().debug, true)
    bridge.forward({'warn', 'off'})
    a.equal(last_save().warn, false)
    bridge.forward({'info', 'off'})
    a.equal(last_save().info, false)
    bridge.forward({'gearreporting', 'on'})
    a.equal(last_save().gear_reporting, true)
    bridge.forward({'displaycells', '9'})
    a.equal(last_save().Display_MinValueCells, 9)

    local save_count = #saved
    bridge.forward({'displaystyle'}) -- bare form cycles through Rahvin's own renderer list
    a.equal(#saved, save_count + 1, 'displaystyle cycle must use Rahvin save behavior')
    a.equal(type(last_save().Display_Style), 'string')

    bridge.forward({'displaypos', 'status', '123', '456'})
    a.equal(#saved > save_count + 1, true, 'display position change must save through Rahvin')

    bridge.forward({'keybind', 'offensemode', 'f8'})
    a.equal(last_save().Keybinds.offensemode, 'f8', 'keybind changes must remain Rahvin-owned')
    local saves_before_bad_key = #saved
    local custom_before_bad_key = #custom
    bridge.forward({'keybind', 'offensemode', 'not-a-key'})
    a.equal(#saved, saves_before_bad_key, 'invalid keybind must not save')
    a.equal(#custom, custom_before_bad_key, 'invalid keybind is claimed by Rahvin')

    local custom_before_bad_display = #custom
    bridge.forward({'displaymode', 'sideways'})
    a.equal(#custom, custom_before_bad_display,
        'invalid display argument must be rejected by Rahvin without job-hook fallthrough')

    -- Optional /rahvings is only a thin Ashita command-event alias. Registration and teardown
    -- are idempotent so a reload cannot accumulate duplicate handlers.
    a.equal(bridge.register(), true)
    a.equal(bridge.register(), true)
    a.equal(#registrations, 1, 'command alias registration must be idempotent')
    a.equal(registrations[1].event, 'command')
    a.equal(type(registrations[1].alias), 'string')
    a.equal(registrations[1].alias ~= '', true)

    local alias_event = {command='/rahvings OffenseMode Normal', blocked=false}
    registrations[1].fn(alias_event)
    a.equal(alias_event.blocked, true, '/rahvings command must be consumed')
    a.equal(env.state.OffenseMode.value, 'Normal', '/rahvings must reach the same Rahvin parser')
    a.equal(dispatched[#dispatched], 'OffenseMode Normal')

    local unrelated = {command='/echo untouched', blocked=false}
    registrations[1].fn(unrelated)
    a.equal(unrelated.blocked, false, 'unrelated Ashita commands must be ignored')

    a.equal(bridge.unregister(), true)
    a.equal(bridge.unregister(), true)
    a.equal(#unregistrations, 1, 'command alias teardown must be idempotent')
    a.deep_equal(unregistrations[1], {
        event=registrations[1].event,
        alias=registrations[1].alias,
    })
end
