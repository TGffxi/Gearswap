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
