local a = require('tests.lib.assertions')
local backend = require('ashita.equip_backend')

return function()
    local calls = {sets={}, enabled={}, disabled={}, cancelled=0}
    local gFunc = {
        EquipSet=function(set) calls.sets[#calls.sets+1]=set end,
        Enable=function(slot) calls.enabled[#calls.enabled+1]=slot end,
        Disable=function(slot) calls.disabled[#calls.disabled+1]=slot end,
        CancelAction=function() calls.cancelled=calls.cancelled+1 end,
    }
    local b = backend.new(gFunc)
    local first = {Name='Chirich Ring +1', Augment={'A','B'}, AugPath='A', AugRank=15,
        AugTrial=123, Bag='Wardrobe 2', Quantity=1}
    local second = {Name='Chirich Ring +1', Augment={'C'}, Bag='Wardrobe 3', Quantity=1}
    local rahvin = {
        name="Rosmerta's Cape",
        priority=80,
        augments={'HP+60', '"Fast Cast"+10'},
        bag='wardrobe2',
        AugPath='A',
        AugRank=15,
        AugTrial=123,
    }
    b:equip({back=rahvin})
    b:flush()
    local rahvin_set = calls.sets[#calls.sets]
    a.equal(rahvin_set.Back.Name, rahvin.name,
        'GearSwap lowercase name must normalize to LAC Name')
    a.equal(rahvin_set.Back.Priority, rahvin.priority,
        'GearSwap lowercase priority must normalize to LAC Priority')
    a.deep_equal(rahvin_set.Back.Augment, rahvin.augments,
        'GearSwap augments must normalize to LAC Augment')
    a.equal(rahvin_set.Back.Bag, rahvin.bag,
        'GearSwap lowercase bag must normalize to LAC Bag')
    a.equal(rahvin_set.Back.AugPath, 'A')
    a.equal(rahvin_set.Back.AugRank, 15)
    a.equal(rahvin_set.Back.AugTrial, 123)
    a.equal(rahvin_set.Back.name, nil,
        'normalized LAC item must not depend on GearSwap lowercase name')
    a.equal(rahvin_set.Back.priority, nil)
    a.equal(rahvin_set.Back.augments, nil)
    a.equal(rahvin_set.Back.bag, nil)

    calls.sets = {}
    b = backend.new(gFunc)

    b:equip({main='Naegling', left_ring=first, right_ring=second, head='Old'})
    b:equip({head='New', body={Name='Nyame Mail'}})
    a.equal(#calls.sets, 0)
    b:flush()
    a.equal(#calls.sets, 1); local set = calls.sets[1]
    a.equal(set.Main, 'Naegling'); a.equal(set.Head, 'New'); a.equal(set.Ring1.Name, first.Name)
    a.deep_equal(set.Ring1, first); a.deep_equal(set.Ring2, second)
    a.equal(set.Ring1 == first, false); a.equal(set.Ring1 == set.Ring2, false)
    b:flush(); a.equal(#calls.sets, 1)
    b:disable('left_ear'); b:enable('right_ring'); b:cancel_action()
    a.equal(calls.disabled[1], 'Ear1'); a.equal(calls.enabled[1], 'Ring2'); a.equal(calls.cancelled, 1)
    a.raises(function() local missing=backend.new({}); missing:equip({head='X'}); missing:flush() end,
        'RahvinCompatError:gFunc.EquipSet')
end
