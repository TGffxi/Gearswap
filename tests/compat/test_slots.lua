local a = require('tests.lib.assertions')
return function()
    local slots = require('compat.slots')
    local accepted = {
        main='Main', sub='Sub', range='Range', ranged='Range', ammo='Ammo',
        head='Head', body='Body', hands='Hands', legs='Legs', feet='Feet',
        neck='Neck', waist='Waist', back='Back',
        ear1='Ear1', lear='Ear1', learring='Ear1', left_ear='Ear1',
        ear2='Ear2', rear='Ear2', rearring='Ear2', right_ear='Ear2',
        ring1='Ring1', lring='Ring1', left_ring='Ring1',
        ring2='Ring2', rring='Ring2', right_ring='Ring2',
    }
    for spelling, lac in pairs(accepted) do
        a.equal(slots.to_lac(spelling), lac, spelling)
        a.equal(slots.to_lac(spelling:upper()), lac, spelling:upper())
    end
    local canonical = {
        Main='main', Sub='sub', Range='range', Ammo='ammo', Head='head', Body='body',
        Hands='hands', Legs='legs', Feet='feet', Neck='neck', Waist='waist', Back='back',
        Ear1='left_ear', Ear2='right_ear', Ring1='left_ring', Ring2='right_ring',
    }
    for lac, spelling in pairs(canonical) do a.equal(slots.to_gearswap(lac), spelling, lac) end
    for spelling, lac in pairs(accepted) do
        a.equal(slots.to_gearswap(spelling), canonical[lac], 'reverse ' .. spelling)
    end
    a.raises(function() slots.to_lac('cape') end, 'RahvinCompatError:unknown_slot:cape')
end
