local a = require('tests.lib.assertions')
return function()
    local snapshot = require('ashita.snapshot')
    local generations = 0
    local provider = {}
    function provider:begin_snapshot() generations=generations+1; return generations end
    local function check(g) a.equal(g, generations, 'mixed provider generation') end
    function provider:player(g) check(g); return {name='Test', status_id=1, status='Engaged'} end
    function provider:world(g) check(g); return {day='Firesday', weather='Hot Spells', weather_id=5} end
    function provider:buffs(g) check(g); return {{id=33,name='Haste'}, {id=33,name='Haste'}, {id=40,name='Protect'}} end
    function provider:pet(g) check(g); return {name='Luopan'} end
    function provider:equipment(g) check(g); return {head='Nyame Helm'} end
    function provider:inventory(g) check(g); return {{id=1,name='Ring',slot=1},{id=1,name='Ring',slot=2}} end
    local service = snapshot.new(provider)
    local result = service:capture()
    a.equal(result.generation, 1); a.equal(result.player.status, 'Engaged')
    a.equal(result.world.day, 'Firesday'); a.equal(result.world.weather_id, 5)
    a.equal(result.buffactive.Haste, 2); a.equal(result.buffactive[33], 2); a.equal(result.buffactive.Protect, 1)
    a.equal(#result.inventory, 2); a.equal(result.inventory[1].slot, 1); a.equal(result.inventory[2].slot, 2)
    provider.player = function() error('provider changed after capture') end
    a.equal(result.player.name, 'Test')
    a.raises(function() snapshot.new({}):capture() end, 'RahvinCompatError:snapshot_provider:begin_snapshot')
end
