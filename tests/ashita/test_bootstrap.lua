local a = require('tests.lib.assertions')
local bootstrap = require('ashita.bootstrap')

return function()
    a.equal(type(require('ashita.profile')), 'function')
    local log, current = {}, nil
    local target={Id=2,Index=3,Name='Target',Distance=4,Status='Idle'}
    local gData={GetAction=function() return current end, GetActionTarget=function() return target end}
    local gFunc={EquipSet=function() end,Enable=function() end,Disable=function() end,CancelAction=function() end}
    local engine={}
    for _, name in ipairs({'load','unload','command','default','pretarget','precast','midcast','preshot','midshot','aftercast'}) do
        engine[name]=function(value) log[#log+1]={name,value} end
    end
    local state={update=function(_, snapshot) log[#log+1]={'state',snapshot} end}
    local profile=bootstrap.create({gData=gData,gFunc=gFunc,engine=engine,state_runtime=state,
        snapshot=function() return {player={status='Idle'}} end})
    local expected={'OnLoad','OnUnload','HandleCommand','HandleDefault','HandleAbility','HandleItem',
        'HandlePrecast','HandleMidcast','HandlePreshot','HandleMidshot','HandleWeaponskill'}
    for _, name in ipairs(expected) do a.equal(type(profile[name]), 'function', name) end
    a.equal(profile.Aftercast, nil)
    profile.OnLoad(); profile.HandleCommand({'mode','cycle'})
    a.equal(log[1][1], 'load'); a.equal(log[2][1], 'command')

    local callbacks={{'HandlePrecast','Spell'},{'HandleAbility','Ability'},{'HandleItem','Item'},
        {'HandlePreshot','Ranged'},{'HandleWeaponskill','Weaponskill'}}
    for index, row in ipairs(callbacks) do
        current={ActionType=row[2],Name=row[2],Id=index}
        profile[row[1]](); profile.HandleDefault(); current=nil; profile.HandleDefault(); profile.HandleDefault()
    end
    local after=0; for _, entry in ipairs(log) do if entry[1]=='aftercast' then after=after+1 end end
    a.equal(after, #callbacks)
    current={ActionType='Spell',Name='Fire',Id=20}; profile.HandlePrecast(); profile.HandleMidcast()
    current={ActionType='Ranged',Name='Ranged',Id=0}; profile.HandlePreshot(); profile.HandleMidshot()
    local saw_midcast,saw_midshot=false,false
    for _, entry in ipairs(log) do saw_midcast=saw_midcast or entry[1]=='midcast'; saw_midshot=saw_midshot or entry[1]=='midshot' end
    a.equal(saw_midcast,true); a.equal(saw_midshot,true)
    profile.OnUnload(); a.equal(log[#log][1], 'unload')
end
