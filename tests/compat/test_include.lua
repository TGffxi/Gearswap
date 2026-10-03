local a = require('tests.lib.assertions')
return function()
    local include = require('compat.include')
    local environment = require('compat.environment')
    local env = environment.new({})
    a.equal(include.load('tests/fixtures/include/counter', env), 1)
    a.equal(include.load('tests/fixtures/include/counter.lua', env), 2)
    a.equal(env.counter, 2)
    local modes = include.load('Modes', env)
    a.equal(type(modes), 'table')
    a.raises(function() include.load('does/not/exist', env) end, 'RahvinCompatError:include_not_found:does/not/exist')
    local old = package.path
    package.path = '/tmp/host-shadow/?.lua;' .. old
    local ok, err = pcall(include.load, 'does/not/exist', env)
    package.path = old
    a.equal(ok, false); a.equal(tostring(err):match('include_not_found') ~= nil, true)
    local installed = environment.install_globals(env)
    a.equal(_G.set_combine, env.set_combine)
    installed:restore()
end
