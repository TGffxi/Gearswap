local a = require('tests.lib.assertions')
local state_runtime = require('ashita.state_runtime')

local function snapshot(status, buffs, pet)
    return {player={status=status}, buffs=buffs or {}, pet=pet}
end

return function()
    local events, busy = {}, false
    local engine={
        is_busy=function() return busy end,
        status_change=function(new, old) events[#events+1]={'status',new,old} end,
        buff_change=function(name, gain) events[#events+1]={'buff',name,gain} end,
        pet_change=function(pet, gain) events[#events+1]={'pet',pet and pet.name,gain} end,
    }
    local r=state_runtime.new(engine)
    r:update(snapshot('Idle', {{id=1,name='Protect'}})); a.equal(#events,0)
    r:update(snapshot('Engaged', {{id=1,name='Protect'}})); a.deep_equal(events[1], {'status','Engaged','Idle'})
    r:update(snapshot('Idle', {{id=1,name='Protect'}})); a.deep_equal(events[2], {'status','Idle','Engaged'})
    r:update(snapshot('Resting', {{id=1,name='Protect'}})); a.deep_equal(events[3], {'status','Resting','Idle'})
    r:update(snapshot('Resting', {{id=1,name='Protect'},{id=2,name='Haste'}}))
    a.deep_equal(events[4], {'buff','Haste',true})
    r:update(snapshot('Resting', {{id=2,name='Haste'}})); a.deep_equal(events[5], {'buff','Protect',false})
    r:update(snapshot('Resting', {{id=2,name='Haste'},{id=2,name='Haste'}})); a.equal(#events,5)
    r:update(snapshot('Resting', {{id=2,name='Haste'}})); a.equal(#events,5)
    r:update(snapshot('Resting', {}, {id=3,name='Carbuncle'})); a.deep_equal(events[6], {'buff','Haste',false})
    a.deep_equal(events[7], {'pet','Carbuncle',true})
    r:update(snapshot('Resting', {}, nil)); a.deep_equal(events[8], {'pet','Carbuncle',false})
    r:update(snapshot('Resting', {}, nil)); a.equal(#events,8)
    busy=true; r:update(snapshot('Engaged', {{id=4,name='March'}})); a.equal(#events,8)
    busy=false; r:update(snapshot('Engaged', {{id=4,name='March'}})); a.equal(#events,10)
    a.deep_equal(events[9], {'status','Engaged','Resting'}); a.deep_equal(events[10], {'buff','March',true})
end
