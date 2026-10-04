local a = require('tests.lib.assertions')
local command_runtime = require('ashita.command_runtime')
local harness = require('tests.lib.rahvin_harness')

local function runtime_fixture()
    local calls = {}
    local scheduled = {}
    local function record(name, value)
        calls[#calls + 1] = {name, value}
        return true
    end
    local runtime = command_runtime.new({
        schedule=function(fn, delay)
            scheduled[#scheduled + 1] = {fn=fn, delay=delay}
            return scheduled[#scheduled]
        end,
        input=function(command) return record('input', command) end,
        raw_command=function(command) return record('raw', command) end,
        cancel_buff=function(id) return record('cancel', id) end,
        execute_script=function(path) return record('script', path) end,
        self_command=function(command) return record('self', command) end,
        validate=function() return record('validate', true) end,
    })
    return runtime, calls, scheduled
end

local function calls_of(calls, name)
    local out = {}
    for _, call in ipairs(calls) do
        if call[1] == name then out[#out + 1] = call[2] end
    end
    return out
end

return function()
    local runtime, calls, scheduled = runtime_fixture()

    -- Internal GearSwap self commands are adapter-owned and must never be handed to Ashita
    -- as unknown 'gs' commands.
    runtime:send('gs c update auto')
    a.deep_equal(calls_of(calls, 'self'), {'update auto'})
    a.equal(#calls_of(calls, 'raw'), 0)

    -- GearSwap validation is not LuAshitacast Packer validation. Consume it through the
    -- compatibility validator and never silently map it to /lac validate.
    runtime:send('gs validate')
    a.equal(#calls_of(calls, 'validate'), 1)
    a.equal(#calls_of(calls, 'raw'), 0)

    runtime:send('cancel 71')
    a.deep_equal(calls_of(calls, 'cancel'), {71})

    runtime:send('exec My_Profile/WAR_SAM_Tester')
    a.deep_equal(calls_of(calls, 'script'), {'My_Profile/WAR_SAM_Tester'})

    -- Commands for external Ashita addons can be passed through the Ashita parser. Windower
    -- console syntax (//foo) is normalized to Ashita's /foo form.
    runtime:send('aset set tanking')
    runtime:send('input //aset spellset magic')
    a.deep_equal(calls_of(calls, 'raw'), {
        '/aset set tanking',
        '/aset spellset magic',
    })

    -- Normal input commands execute as game/typed commands rather than being queued as
    -- literal Windower command-language text.
    runtime:send('input /p Rampart [OFF]')
    a.deep_equal(calls_of(calls, 'input'), {'/p Rampart [OFF]'})

    -- Windower wait splits one chain into scheduled continuations. Every continuation uses
    -- the existing shared scheduler and preserves command order.
    local chain_runtime, chain_calls, chain_scheduled = runtime_fixture()
    chain_runtime:send('wait 1;input /macro book 4;wait .1;input /macro set 2;gs c update auto')
    a.equal(#chain_calls, 0, 'leading wait must defer the first executable command')
    a.equal(#chain_scheduled, 1)
    a.equal(chain_scheduled[1].delay, 1)

    chain_scheduled[1].fn()
    a.deep_equal(calls_of(chain_calls, 'input'), {'/macro book 4'})
    a.equal(#chain_scheduled, 2)
    a.equal(chain_scheduled[2].delay, 0.1)

    chain_scheduled[2].fn()
    a.deep_equal(calls_of(chain_calls, 'input'), {'/macro book 4','/macro set 2'})
    a.deep_equal(calls_of(chain_calls, 'self'), {'update auto'})
    a.equal(#chain_scheduled, 2)

    -- No exact pinned Ashita command was proven equivalent to Windower terminate, and the
    -- Windower Lua addon manager syntax is not an Ashita addon-manager command. These must
    -- fail explicitly rather than be passed through while pretending parity.
    a.raises(function() runtime:send('terminate') end,
        'RahvinCompatError:command_unsupported:terminate')
    a.raises(function() runtime:send('lua u autocor') end,
        'RahvinCompatError:command_unsupported:lua u autocor')
    a.raises(function() runtime:send('send @all gs c update auto') end,
        'RahvinCompatError:command_unsupported:send @all')

    -- Exercise the actual unchanged Rahvin jobsetup chain. All 22 sample files call this at
    -- file scope; it must parse without modifying Rahvin or the samples.
    local h = harness.new()
    local job_runtime, job_calls, job_scheduled = runtime_fixture()
    h.platform.send_command = function(_, command)
        return job_runtime:send(command)
    end
    h.env.jobsetup('8', '4', '1')

    a.equal(#job_scheduled, 1)
    a.equal(job_scheduled[1].delay, 1)
    job_scheduled[1].fn()
    a.deep_equal(calls_of(job_calls, 'input'), {'/macro book 4'})
    a.equal(#job_scheduled, 2)
    a.equal(job_scheduled[2].delay, 1)

    job_scheduled[2].fn()
    a.deep_equal(calls_of(job_calls, 'input'), {'/macro book 4','/macro set 1'})
    a.equal(#calls_of(job_calls, 'validate'), 1,
        'unchanged jobsetup must consume GearSwap validate through compatibility')
    a.equal(#job_scheduled, 3)
    a.equal(job_scheduled[3].delay, 3)

    job_scheduled[3].fn()
    a.deep_equal(calls_of(job_calls, 'input'), {
        '/macro book 4','/macro set 1','/lockstyleset 8','/echo Change Complete',
    })
    a.deep_equal(calls_of(job_calls, 'self'), {'update auto'},
        'unchanged jobsetup must finish through the Rahvin self-command dispatcher')
end
