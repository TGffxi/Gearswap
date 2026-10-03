local a = require('tests.lib.assertions')

local function contains(values)
    local t = {}
    for _, value in ipairs(values) do t[value] = true end
    function t:contains(value) return self[value] == true end
    return t
end

return function()
    package.loaded['ashita.inventory'] = nil
    package.loaded['ashita.recasts'] = nil
    local inv_loaded = pcall(require, 'ashita.inventory')
    local rec_loaded = pcall(require, 'ashita.recasts')
    if not inv_loaded or not rec_loaded then
        error(('Enchant/Hoxne parity requires Task 4 data services (inventory=%s recasts=%s)')
            :format(tostring(inv_loaded), tostring(rec_loaded)), 2)
    end

    local harness = require('tests.lib.rahvin_harness')
    local h = harness.new()
    local env = h.env

    -- These are Rahvin's unchanged critical-window decisions. The adapter may supply data,
    -- but must not reimplement or reinterpret which actions can borrow Hoxne's slots.
    a.equal(type(env.critical_action_for), 'function', 'unchanged Rahvin Hoxne classifier must be loaded')
    local song = env.critical_action_for({type='BardSong', id=999})
    a.equal(song.slot, 'range')
    a.equal(song.resume, 'delay')
    a.equal(song.delay, 5)
    local geo = env.critical_action_for({type='Geomancy', id=999})
    a.equal(geo.slot, 'range')
    local tomahawk = env.critical_action_for({type='JobAbility', id=150})
    a.equal(tomahawk.slot, 'ammo')
    a.equal(tomahawk.force, 'Thr. Tomahawk')
    a.equal(tomahawk.resume, 'aftercast')
    a.equal(env.critical_action_for({type='JobAbility', id=1}), nil,
        'ordinary job ability must not open a Hoxne critical window')

    -- Exercise the unchanged Rahvin enchanted-item entry path using the same normalized
    -- Windower-shaped item that the Ashita inventory adapter will expose. The raw Ashita
    -- instance remains attached so compat.extdata can decode its timers and augment bytes.
    local raw_item = {Id=900, Count=1, Status=0, Extra='raw-extdata'}
    h.platform.resources.items[900] = {
        id=900,
        en='Test Charm',
        enl='Test Charm',
        cast_delay=0,
        cast_time=1,
        targets=contains({'Self'}),
        slots=contains({4}), -- head
    }
    h.platform.get_items = function(_, bag)
        if bag == 0 then
            return {{id=900,count=1,status=0,extra='raw-extdata',raw=raw_item}}
        end
        return {}
    end
    local decoded_seen
    h.platform.decode_item = function(_, item)
        decoded_seen = item
        return {usable=true}
    end

    a.equal(type(env.use_enchantment), 'function', 'unchanged Rahvin enchanted-item command must be loaded')
    local before = #h.equipped
    env.use_enchantment('Test Charm')
    a.equal(#h.equipped, before + 1, 'ready carried enchanted item must enter Rahvin equip/use state machine')
    a.equal(h.equipped[#h.equipped].Head, 'Test Charm')
    a.equal(decoded_seen, raw_item, 'Rahvin extdata path must receive the exact Ashita inventory instance')

    -- A second physical instance with the same item id is data, not quantity aggregation.
    -- Task 4 inventory matching owns that identity; Rahvin may then inspect status per copy.
    local inventory = require('ashita.inventory').new({
        container_max=function(bag) return bag == 0 and 2 or 0 end,
        container_item=function(bag, index)
            if bag ~= 0 then return nil end
            if index == 1 then return {Id=900,Count=1,Status=0,Extra='one'} end
            if index == 2 then return {Id=900,Count=1,Status=5,Extra='two'} end
        end,
        compare_item=function(descriptor, item) return descriptor.id == item.Id end,
    })
    local copies = inventory.find_all({id=900})
    a.equal(#copies, 2)
    a.equal(copies[1].status, 0)
    a.equal(copies[2].status, 5, 'worn duplicate remains separately addressable for Hoxne/enchant checks')
end
