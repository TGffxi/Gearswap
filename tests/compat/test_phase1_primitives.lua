local a = require('tests.lib.assertions')
local environment = require('compat.environment')

return function()
    local env = environment.install_runtime(environment.new(), {})
    local list = env.T{'one'}
    list:insert('two')
    a.equal(list:concat('|'), 'one|two')
    list:clear()
    a.equal(#list, 0)
    local set = env.S{'one', 'two'}
    a.equal(set:contains('one'), true)
    a.equal(set.two, true)

    -- Windower extends Lua's string library; unchanged Rahvin code relies on trim() in the
    -- enchanted-item lookup path. Keep that compatibility surface explicit and regression-tested.
    a.equal(type(string.trim), 'function', 'Windower-compatible string.trim must exist')
    a.equal(('  Test Charm\t\r\n'):trim(), 'Test Charm', 'string.trim removes leading/trailing whitespace')

    for _, name in ipairs({'config', 'resources', 'extdata', 'socket', 'files', 'xml'}) do
        a.equal(type(env.require(name)), 'table', name)
    end
    for _, contract in ipairs({{'config','load'}, {'config','save'}, {'extdata','decode'},
        {'socket','gettime'}, {'files','new'}, {'xml','parse'}}) do
        a.equal(type(env.require(contract[1])[contract[2]]), 'function', table.concat(contract, '.'))
    end
    a.raises(function() env.require('files').new('data/settings.xml') end, 'RahvinCompatError:files.new')
end
