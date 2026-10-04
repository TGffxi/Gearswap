local a = require('tests.lib.assertions')

local function set_contains(set, value)
    return type(set) == 'table' and type(set.contains) == 'function' and set:contains(value)
end

return function()
    package.loaded['ashita.resources'] = nil
    local resources = require('ashita.resources')
    a.equal(type(resources.new), 'function', 'ashita resources must expose new(source, limits)')
    a.equal(type(resources.production), 'function', 'ashita resources must expose production(core)')

    local strings = {
        ['buffs.names'] = {
            [308] = "Fighter's Roll",
            [2] = 'Sleep',
        },
        ['zones.names'] = {
            [55] = 'Dynamis - Jeuno [D]',
        },
        ['jobs.names'] = {
            [1] = 'Warrior',
            [17] = 'Corsair',
        },
        ['jobs.names_abbr'] = {
            [1] = 'WAR',
            [17] = 'COR',
        },
    }

    local raw = {
        items = {
            [15435] = {
                Id=15435, Name={'Karin Obi'}, LogNameSingular={'Karin Obi'},
                Level=71, Jobs=bit.lshift(1, 16), Races=bit.lshift(1, 0),
                Slots=bit.lshift(1, 10), Targets=0x01, Skill=0,
                CastTime=0, CastDelay=0, RecastDelay=0,
            },
            [27593] = {
                Id=27593, Name={'Jubilee Ring'}, LogNameSingular={'Jubilee Ring'},
                Level=99, Jobs=bit.lshift(1, 0) + bit.lshift(1, 16),
                Races=0xFF, Slots=bit.lshift(1, 13) + bit.lshift(1, 14),
                Targets=0x01, Skill=0, CastTime=1, CastDelay=8, RecastDelay=7200,
            },
            [999] = {
                Id=999, Name={'Great Test Sword'}, LogNameSingular={'Great Test Sword'},
                Level=1, Jobs=0xFFFFFF, Races=0xFF, Slots=1, Targets=0,
                Skill=4, CastTime=0, CastDelay=0, RecastDelay=0,
            },
        },
        abilities = {
            [100] = {
                Id=100, Name={"Fighter's Roll"}, RecastTimerId=193,
                Type=8, TPCost=0,
            },
            [200] = {
                Id=200, Name={'Test Waltz'}, RecastTimerId=7,
                Type=12, TPCost=350,
            },
        },
        spells = {
            [10] = {
                Index=10, Id=10, Name={'Test Nuke'}, Element=0,
                CastTime=12, RecastDelay=20, Skill=36, Type=2,
            },
        },
        buffs = {
            [2] = {Id=2},
            [308] = {Id=308},
        },
    }

    local source = {
        item=function(id) return raw.items[id] end,
        ability=function(id) return raw.abilities[id] end,
        spell=function(id) return raw.spells[id] end,
        buff=function(id) return raw.buffs[id] end,
        string=function(tbl, id) return strings[tbl] and strings[tbl][id] or nil end,
        decode=function(value) return value end,
    }

    local res = resources.new(source, {
        item_ids={999,15435,27593},
        ability_ids={100,200},
        spell_ids={10},
        buff_ids={2,308},
        zone_ids={55},
        job_ids={1,17},
    })

    for _, name in ipairs({
        'items','buffs','job_abilities','weapon_skills','spells',
        'elements','zones','jobs','bags',
    }) do
        a.equal(type(res[name]), 'table', 'resource collection missing: ' .. name)
    end

    local ring = res.items[27593]
    a.equal(ring.id, 27593)
    a.equal(ring.en, 'Jubilee Ring')
    a.equal(ring.english, 'Jubilee Ring')
    a.equal(ring.enl, 'Jubilee Ring')
    a.equal(ring.level, 99)
    a.equal(ring.skill, 0)
    a.equal(ring.cast_time, 1)
    a.equal(ring.cast_delay, 8)
    a.equal(ring.recast_delay, 7200)
    a.equal(set_contains(ring.targets, 'Self'), true,
        'item target mask must expose Windower Self membership')
    a.equal(set_contains(ring.slots, 13), true)
    a.equal(set_contains(ring.slots, 14), true)
    a.equal(ring.jobs[1], true)
    a.equal(ring.jobs[17], true)
    a.equal(ring.races[1], true)

    a.equal(res.items[999].skill, 4,
        'weapon skill id must remain compatible with Rahvin two-handed checks')

    local roll = res.job_abilities[100]
    a.equal(roll.id, 100)
    a.equal(roll.en, "Fighter's Roll")
    a.equal(roll.type, 'CorsairRoll')
    a.equal(roll.status, 308,
        'Corsair Roll must map to the same-named buff id for eleven tracking')
    a.equal(roll.recast_id, 193)

    local waltz = res.job_abilities[200]
    a.equal(waltz.tp_cost, 350)
    a.equal(waltz.recast_id, 7)

    local spell = res.spells[10]
    a.equal(spell.id, 10)
    a.equal(spell.en, 'Test Nuke')
    a.equal(spell.element, 0)
    a.equal(spell.cast_time, 3,
        'Ashita spell CastTime quarter-seconds must normalize to Windower seconds')

    a.equal(res.buffs[2].en, 'Sleep')
    a.equal(res.buffs[2].english, 'Sleep')
    a.equal(res.zones[55].en, 'Dynamis - Jeuno [D]')
    a.equal(res.jobs[17].en, 'COR')
    a.equal(res.jobs[17].english, 'Corsair')

    a.equal(res.elements[0].en, 'Fire')
    a.equal(res.elements[6].en, 'Light')
    a.equal(res.elements[15].en, 'None')
    a.equal(type(res.elements[0].japanese), 'string')

    a.equal(res.bags[0].en, 'Inventory')
    a.equal(res.bags[8].en, 'Wardrobe')
    a.equal(res.bags[16].en, 'Wardrobe 8')

    -- The production path must use the active Ashita resource manager and preserve the
    -- exact same normalization contract.
    local manager = {
        GetItemById=function(_, id) return raw.items[id] end,
        GetAbilityById=function(_, id) return raw.abilities[id] end,
        GetSpellById=function(_, id) return raw.spells[id] end,
        GetStatusIconById=function(_, id) return raw.buffs[id] end,
        GetString=function(_, tbl, id) return strings[tbl] and strings[tbl][id] or nil end,
    }
    local core = {GetResourceManager=function() return manager end}
    local production = resources.production(core, {
        item_ids={27593}, ability_ids={100}, spell_ids={10},
        buff_ids={308}, zone_ids={55}, job_ids={17},
        decode=function(value) return value end,
    })
    a.equal(production.items[27593].en, 'Jubilee Ring')
    a.equal(production.job_abilities[100].status, 308)
    a.equal(production.spells[10].cast_time, 3)
end
