local a = require('tests.lib.assertions')
local environment = require('compat.environment')

return function()
    local sent = {}
    local platform = {
        send_command=function(_, command)
            sent[#sent + 1] = command
            return true
        end,
    }
    local env = environment.install_runtime(environment.new(), platform)
    local list = env.T{'one'}
    list:insert('two')
    a.equal(list:concat('|'), 'one|two')
    list:clear()
    a.equal(#list, 0)
    local set = env.S{'one', 'two'}
    a.equal(set:contains('one'), true)
    a.equal(set.two, true)

    -- Windower extends Lua's string library. Unchanged Rahvin code relies on trim() in the
    -- enchanted-item lookup path and lpad() in the debug display.
    a.equal(type(string.trim), 'function', 'Windower-compatible string.trim must exist')
    a.equal(('  Test Charm\t\r\n'):trim(), 'Test Charm', 'string.trim removes leading/trailing whitespace')
    a.equal(type(string.lpad), 'function', 'Windower-compatible string.lpad must exist')
    a.equal(('[true]'):lpad(' ', 12), '      [true]', 'string.lpad left-pads to the requested total width')
    a.equal(('longer'):lpad('0', 3), 'longer', 'string.lpad never truncates a value already wider than the target')

    -- GearSwap exposes send_command as a user-file global in addition to windower.send_command.
    -- Rahvin's keybind and shutdown handlers use that global directly.
    a.equal(type(env.send_command), 'function', 'GearSwap-compatible global send_command must exist')
    a.equal(env.send_command('bind f8 gs c OffenseMode'), true)
    a.equal(sent[1], 'bind f8 gs c OffenseMode', 'global send_command delegates to the platform command backend')

    for _, name in ipairs({'config', 'resources', 'extdata', 'socket', 'files', 'xml'}) do
        a.equal(type(env.require(name)), 'table', name)
    end
    for _, contract in ipairs({{'config','load'}, {'config','save'}, {'extdata','decode'},
        {'socket','gettime'}, {'files','new'}, {'xml','parse'}}) do
        a.equal(type(env.require(contract[1])[contract[2]]), 'function', table.concat(contract, '.'))
    end
    a.raises(function() env.require('files').new('data/settings.xml') end, 'RahvinCompatError:files.new')
end
