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
    for _, name in ipairs({'config', 'resources', 'extdata', 'socket', 'files', 'xml'}) do
        a.equal(type(env.require(name)), 'table', name)
    end
    for _, contract in ipairs({{'config','load'}, {'config','save'}, {'extdata','decode'},
        {'socket','gettime'}, {'files','new'}, {'xml','parse'}}) do
        a.equal(type(env.require(contract[1])[contract[2]]), 'function', table.concat(contract, '.'))
    end
end
