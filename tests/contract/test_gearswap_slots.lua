local a = require('tests.lib.assertions')
local environment = require('compat.environment')
local gearswap = require('compat.gearswap')

return function()
    local equipped
    local env = gearswap.install(environment.new(), {equip=function(_, set) equipped = set end})
    env.equip({main='Naegling', left_ear='Moonshade Earring', right_ear='Telos Earring',
        left_ring='Defending Ring', right_ring='Moonlight Ring'})
    a.equal(equipped.Main, 'Naegling')
    a.equal(equipped.Ear1, 'Moonshade Earring')
    a.equal(equipped.Ear2, 'Telos Earring')
    a.equal(equipped.Ring1, 'Defending Ring')
    a.equal(equipped.Ring2, 'Moonlight Ring')
end
