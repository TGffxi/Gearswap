local a = require('tests.lib.assertions')
return function()
    local sets = require('compat.sets')
    local item = {name='Nyame Helm', augment={'Path: B', 'Rank: 30'}}
    local base = {head=item, body='Nyame Mail', nested={keep=true}}
    local overlay = {body='Sakpata Breastplate', hands={Name='Nyame Gauntlets', AugPath='B'}}
    local result = sets.combine(base, nil, overlay, {feet='Nyame Sollerets'})
    a.deep_equal(result, {head=item, body='Sakpata Breastplate', hands={Name='Nyame Gauntlets', AugPath='B'}, feet='Nyame Sollerets', nested={keep=true}})
    a.deep_equal(base, {head=item, body='Nyame Mail', nested={keep=true}})
    a.equal(result.head == item, false, 'item descriptors must be copied')
    result.head.augment[1] = 'changed'
    a.equal(item.augment[1], 'Path: B')
    local copy = sets.copy(base)
    copy.nested.keep = false
    a.equal(base.nested.keep, true)
    a.raises(function() sets.combine(base, 'bad') end, 'RahvinCompatError:set_combine_argument')
end
