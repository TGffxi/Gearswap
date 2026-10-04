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

    -- Rahvin's real GearSwap gear library uses lowercase item metadata.  LuAshitacast's
    -- MakeItemTable is case-sensitive and consumes Name/Priority/Augment/Bag, so the
    -- compatibility boundary must translate the item shape without requiring Rahvin or
    -- shipped job files to change.
    local rahvin_item = {
        name='Chirich Ring +1',
        priority=17,
        augments={'Accuracy+10', 'Attack+10'},
        bag='Wardrobe 2',
    }
    env.equip({
        head={name='Nyame Helm', augment='Path: B'},
        left_ring=rahvin_item,
        right_ring={Name='Moonlight Ring', Priority=4, AugPath='A', AugRank=15, AugTrial=123},
        sub=env.empty,
    })

    a.equal(equipped.Head.Name, 'Nyame Helm')
    a.equal(equipped.Head.Augment, 'Path: B')
    a.equal(equipped.Ring1.Name, 'Chirich Ring +1')
    a.equal(equipped.Ring1.Priority, 17)
    a.deep_equal(equipped.Ring1.Augment, {'Accuracy+10', 'Attack+10'})
    a.equal(equipped.Ring1.Bag, 'Wardrobe 2')
    a.equal(equipped.Ring2.Name, 'Moonlight Ring',
        'already-LAC-shaped item metadata must remain accepted')
    a.equal(equipped.Ring2.Priority, 4)
    a.equal(equipped.Ring2.AugPath, 'A')
    a.equal(equipped.Ring2.AugRank, 15)
    a.equal(equipped.Ring2.AugTrial, 123)
    a.equal(equipped.Sub, 'remove',
        'GearSwap empty sentinel must become LuAshitacast explicit unequip semantics')
    a.equal(rahvin_item.Name, nil, 'translation must not mutate Rahvin set tables')
    a.equal(type(env.empty), 'table', 'GearSwap-compatible empty sentinel must exist by identity')
end
