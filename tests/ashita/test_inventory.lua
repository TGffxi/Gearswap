local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.inventory'] = nil
    package.loaded['ashita.recasts'] = nil
    local inv_loaded, inventory = pcall(require, 'ashita.inventory')
    local rec_loaded, recasts = pcall(require, 'ashita.recasts')
    if not inv_loaded or not rec_loaded then
        error(('Phase 3 Task 4 services must exist (inventory=%s recasts=%s)')
            :format(tostring(inv_loaded), tostring(rec_loaded)), 2)
    end

    a.deep_equal(inventory.EQUIPPABLE_BAGS, {0,8,10,11,12,13,14,15,16},
        'equippable bag set must match Rahvin ENCH_BAGS')
    a.equal(type(inventory.new), 'function')
    a.equal(type(recasts.new), 'function')

    local raw = {
        [0] = {
            [1] = {Id=0, Count=0, Status=0},
            [2] = {Id=100, Count=1, Status=0, Extra='A', Name='Augmented Sword', Path='A'},
            [3] = {Id=100, Count=1, Status=5, Extra='B', Name='Augmented Sword', Path='A'},
            [4] = {Id=200, Count=2, Status=0, Extra='C', Name='Other Item'},
        },
        [8] = {
            [1] = {Id=100, Count=1, Status=0, Extra='D', Name='Augmented Sword', Path='B'},
        },
    }

    local compared = 0
    local source = {
        container_max=function(bag)
            if bag == 0 then return 4 end
            if bag == 8 then return 1 end
            return 0
        end,
        container_item=function(bag, index)
            local bag_data = raw[bag]
            return bag_data and bag_data[index] or nil
        end,
        compare_item=function(descriptor, item, bag)
            compared = compared + 1
            if descriptor.Name and descriptor.Name ~= item.Name then return false end
            if descriptor.AugPath and descriptor.AugPath ~= item.Path then return false end
            return true
        end,
    }

    local service = inventory.new(source)
    local bag0 = service.iter_bag(0)
    a.equal(#bag0, 3, 'empty item slots must be skipped without collapsing real instances')
    a.deep_equal({bag=bag0[1].bag,index=bag0[1].index,id=bag0[1].id,count=bag0[1].count,status=bag0[1].status,extra=bag0[1].extra},
        {bag=0,index=2,id=100,count=1,status=0,extra='A'})
    a.equal(bag0[1].raw, raw[0][2], 'normalized entry must retain exact Ashita item instance')
    a.equal(bag0[2].raw, raw[0][3], 'same-id second instance must remain distinct')

    local all_swords = service.find_all({Name='Augmented Sword'})
    a.equal(#all_swords, 3, 'same-name items across bags must never be aggregated')
    a.deep_equal({all_swords[1].bag, all_swords[1].index, all_swords[2].bag, all_swords[2].index, all_swords[3].bag, all_swords[3].index},
        {0,2,0,3,8,1})

    local path_a = service.find_all({Name='Augmented Sword', AugPath='A'})
    a.equal(#path_a, 2, 'LAC-compatible matcher must preserve augment/path identity')
    a.equal(path_a[1].status, 0)
    a.equal(path_a[2].status, 5, 'worn duplicate must be independently observable')
    a.equal(compared > 0, true, 'inventory matching must delegate to the injected LAC matcher')

    -- Ashita IRecast timers are 1/60-second ticks. The adapter exposes the Windower-shaped
    -- seconds tables that unchanged Rahvin code consumes.
    local recast_service = recasts.new({
        ability_entries=function()
            return {
                {timer_id=2, ticks=900},
                {timer_id=3, ticks=0},
            }
        end,
        spell_entries=function()
            return {
                {id=1, ticks=120},
                {id=2, ticks=0},
            }
        end,
    })
    local abilities = recast_service.abilities()
    a.equal(abilities[2], 15, 'ability ticks must normalize to seconds')
    a.equal(abilities[3], 0, 'ready ability must remain present at zero seconds')
    local spells = recast_service.spells()
    a.equal(spells[1], 2, 'spell ticks must normalize to seconds')
    a.equal(spells[2], 0)

    local unavailable = recasts.new({})
    a.equal(unavailable.abilities(), nil, 'unavailable ability recast source must stay distinguishable from ready')
    a.equal(unavailable.spells(), nil, 'unavailable spell recast source must stay distinguishable from ready')

    -- compat.extdata must hand the original Ashita item instance to the decoder while
    -- keeping Windower-compatible enchant timing fields and augment identity untouched.
    local extdata = require('compat.extdata')
    local decoded_raw
    local decoder = extdata.new({
        decode_item=function(_, item)
            decoded_raw = item
            return {
                usable=true,
                next_use_time=12345,
                activation_time=12300,
                Type='Delve', Path='A', Rank=15,
                Trial=777, TrialComplete=true,
                Augs={Attack={String='Attack+20'}},
            }
        end,
    })
    local ext = decoder.decode(bag0[1])
    a.equal(decoded_raw, raw[0][2], 'extdata decoder must unwrap normalized inventory entries')
    a.equal(ext.usable, true)
    a.equal(ext.next_use_time, 12345)
    a.equal(ext.activation_time, 12300)
    a.equal(ext.Path, 'A')
    a.equal(ext.Rank, 15)
    a.equal(ext.Trial, 777)
    a.equal(ext.TrialComplete, true)
    a.equal(ext.Augs.Attack.String, 'Attack+20')
end
