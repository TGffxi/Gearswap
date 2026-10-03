local a = require('tests.lib.assertions')
return function()
    local slots = require('compat.slots')
    local expected = {main='Main', sub='Sub', range='Range', ammo='Ammo', head='Head', body='Body', hands='Hands', legs='Legs', feet='Feet', neck='Neck', waist='Waist', lear='Ear1', rear='Ear2', lring='Ring1', rring='Ring2', back='Back'}
    for gs, lac in pairs(expected) do
        a.equal(slots.to_lac(gs), lac)
        a.equal(slots.to_lac(gs:upper()), lac)
        a.equal(slots.to_gearswap(lac), gs)
    end
    a.raises(function() slots.to_lac('cape') end, 'RahvinCompatError:unknown_slot:cape')
end
