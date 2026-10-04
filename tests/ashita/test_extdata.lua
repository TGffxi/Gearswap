local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.extdata'] = nil
    local extdata = require('ashita.extdata')
    a.equal(type(extdata.new), 'function', 'ashita extdata must expose new(deps)')
    a.equal(type(extdata.production), 'function', 'ashita extdata must expose production(deps)')

    local raw = {Id=27596, Status=5, Extra='packed'}
    local timer_seen, augment_seen

    local service = extdata.new({
        clock=function() return 200000 end,
        timer=function(item, equipped)
            timer_seen = {item=item, equipped=equipped}
            return {recast=120, activation=4, usable=false}
        end,
        augment=function(item)
            augment_seen = item
            return {
                Type='Oseem',
                Augs={
                    one={String='Cap. Point+50%'},
                    two={String='DEX+10'},
                },
            }
        end,
    })

    local decoded = service.decode(raw)
    a.equal(timer_seen.item, raw)
    a.equal(timer_seen.equipped, true,
        'Status 5 must tell the timer decoder that the physical instance is equipped')
    a.equal(augment_seen, raw)
    a.equal(decoded.usable, false)
    a.equal(decoded.next_use_time, 182120,
        'Windower next_use_time must use Rahvin/Windower epoch plus remaining recast')
    a.equal(decoded.activation_time, 182004,
        'Windower activation_time must use Rahvin/Windower epoch plus remaining equip delay')
    a.equal(type(decoded.augments), 'table')
    local seen = {}
    for _, value in ipairs(decoded.augments) do seen[value] = true end
    a.equal(seen['Cap. Point+50%'], true)
    a.equal(seen['DEX+10'], true)

    local clean = extdata.new({
        clock=function() return 200000 end,
        timer=function() return {recast=0, activation=0, usable=true} end,
        augment=function() return {Type='Unaugmented'} end,
    }).decode({Id=1,Status=0})
    a.equal(clean.usable, true)
    a.equal(clean.next_use_time, 182000)
    a.equal(clean.activation_time, 182000)
    a.equal(type(clean.augments), 'table')
    a.equal(#clean.augments, 0)

    -- Production must combine Ashita's timer parser with LAC's own augment parser. This
    -- keeps item-instance bytes authoritative while avoiding a second augment implementation.
    local previous_core = rawget(_G, 'AshitaCore')
    local previous_gdata = rawget(_G, 'gData')
    local previous_itemdata_loaded = package.loaded['ffxi.itemdata']
    local previous_itemdata_preload = package.preload['ffxi.itemdata']
    local previous_time_loaded = package.loaded['ffxi.time']
    local previous_time_preload = package.preload['ffxi.time']

    local resource = {Id=27596, Type=5, CastDelay=8, RecastDelay=7200, MaxCharges=1}
    local manager = {GetItemById=function(_, id)
        if id == 27596 then return resource end
    end}
    rawset(_G, 'AshitaCore', {GetResourceManager=function() return manager end})

    local gData = {
        GetAugment=function(item)
            a.equal(item, raw)
            return {
                Type='Oseem',
                Augs={a={String='Cap. Point+50%'},b={String='DEX+10'}},
            }
        end,
    }
    rawset(_G, 'gData', gData)

    package.loaded['ffxi.itemdata'] = nil
    package.preload['ffxi.itemdata'] = function()
        return {
            parse_timer_info=function(item, ritem, equipped)
                a.equal(item, raw)
                a.equal(ritem, resource)
                a.equal(equipped, true)
                return {
                    remaining_charges=1,
                    max_charges=1,
                    cast_delay=8,
                    raw={time_value1=111,time_value2=222},
                }
            end,
        }
    end
    package.loaded['ffxi.time'] = nil
    package.preload['ffxi.time'] = function()
        return {
            game_time_diff=function(value)
                if value == 111 then return 90 end
                if value == 222 then return 3 end
                error('unexpected timer value')
            end,
        }
    end

    local production = extdata.production({
        clock=function() return 300000 end,
    })
    local live = production.decode(raw)
    a.equal(live.usable, false,
        'positive recast/equip timer means the item is not immediately usable')
    a.equal(live.next_use_time, 282090)
    a.equal(live.activation_time, 282003)
    local live_seen = {}
    for _, value in ipairs(live.augments) do live_seen[value] = true end
    a.equal(live_seen['Cap. Point+50%'], true)
    a.equal(live_seen['DEX+10'], true)

    rawset(_G, 'AshitaCore', previous_core)
    rawset(_G, 'gData', previous_gdata)
    package.loaded['ffxi.itemdata'] = previous_itemdata_loaded
    package.preload['ffxi.itemdata'] = previous_itemdata_preload
    package.loaded['ffxi.time'] = previous_time_loaded
    package.preload['ffxi.time'] = previous_time_preload
end
