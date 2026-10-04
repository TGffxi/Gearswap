local a = require('tests.lib.assertions')
local state_runtime = require('ashita.state_runtime')

local function snapshot(status, buffs, pet, sub_job)
    return {player={status=status, sub_job=sub_job or 'SAM'}, buffs=buffs or {}, pet=pet}
end

return function()
    local events, busy = {}, false
    local logical = {
        emit=function(_, name, id)
            events[#events+1]={'windower',name,id}
            return 1
        end,
    }
    local engine={
        is_busy=function() return busy end,
        status_change=function(new, old) events[#events+1]={'status',new,old} end,
        buff_change=function(name, gain) events[#events+1]={'buff',name,gain} end,
        pet_change=function(pet, gain) events[#events+1]={'pet',pet and pet.name,gain} end,
        sub_job_change=function(new, old) events[#events+1]={'subjob',new,old} end,
    }
    local r=state_runtime.new(engine, logical)
    r:update(snapshot('Idle', {{id=1,name='Protect'}})); a.equal(#events,0)
    r:update(snapshot('Engaged', {{id=1,name='Protect'}})); a.deep_equal(events[1], {'status','Engaged','Idle'})
    r:update(snapshot('Idle', {{id=1,name='Protect'}})); a.deep_equal(events[2], {'status','Idle','Engaged'})
    r:update(snapshot('Resting', {{id=1,name='Protect'}})); a.deep_equal(events[3], {'status','Resting','Idle'})

    -- One state diff owns both surfaces. Windower's numeric event is delivered first, then
    -- the ordinary GearSwap buff_change callback for the same transition.
    r:update(snapshot('Resting', {{id=1,name='Protect'},{id=2,name='Haste'}}))
    a.deep_equal(events[4], {'windower','gain buff',2})
    a.deep_equal(events[5], {'buff','Haste',true})

    r:update(snapshot('Resting', {{id=2,name='Haste'}}))
    a.deep_equal(events[6], {'windower','lose buff',1})
    a.deep_equal(events[7], {'buff','Protect',false})

    -- Multiplicity changes for the same numeric buff id are not gain/loss transitions.
    r:update(snapshot('Resting', {{id=2,name='Haste'},{id=2,name='Haste'}})); a.equal(#events,7)
    r:update(snapshot('Resting', {{id=2,name='Haste'}})); a.equal(#events,7)

    r:update(snapshot('Resting', {}, {id=3,name='Carbuncle'}))
    a.deep_equal(events[8], {'windower','lose buff',2})
    a.deep_equal(events[9], {'buff','Haste',false})
    a.deep_equal(events[10], {'pet','Carbuncle',true})
    r:update(snapshot('Resting', {}, nil)); a.deep_equal(events[11], {'pet','Carbuncle',false})
    r:update(snapshot('Resting', {}, nil)); a.equal(#events,11)

    -- A real subjob transition calls GearSwap exactly once; repeated identical snapshots do
    -- nothing. The callback receives three-letter new/old abbreviations.
    r:update(snapshot('Resting', {}, nil, 'DNC'))
    a.deep_equal(events[12], {'subjob','DNC','SAM'})
    r:update(snapshot('Resting', {}, nil, 'DNC'))
    a.equal(#events,12, 'unchanged subjob must not retrigger sub_job_change')

    -- Rahvin status changes and numeric Windower buff events are not gated by the action busy
    -- window. Only GearSwap's buff_change redress is deferred until the cast is no longer busy.
    busy=true
    r:update(snapshot('Engaged', {{id=4,name='March'}}, nil, 'DNC'))
    a.deep_equal(events[13], {'status','Engaged','Resting'})
    a.deep_equal(events[14], {'windower','gain buff',4})
    a.equal(#events,14, 'busy cast must defer only GearSwap buff_change')

    busy=false
    r:update(snapshot('Engaged', {{id=4,name='March'}}, nil, 'DNC'))
    a.deep_equal(events[15], {'buff','March',true})
    a.equal(#events,15)
end
