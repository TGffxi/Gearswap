local a = require('tests.lib.assertions')
local bootstrap = require('ashita.bootstrap')

return function()
    local entry=require('ashita.profile')
    for _, name in ipairs({'OnLoad','OnUnload','HandleCommand','HandleDefault','HandleAbility','HandleItem',
        'HandlePrecast','HandleMidcast','HandlePreshot','HandleMidshot','HandleWeaponskill'}) do
        a.equal(type(entry[name]),'function','profile.'..name)
    end
    a.raises(function() entry.OnLoad() end,'RahvinCompatError:profile_not_configured')
    local log, current = {}, nil
    local snapshot_count, state_updates = 0, 0
    local target={Id=2,Index=3,Name='Target',Distance=4,Status='Idle',Type='Monster'}
    local gData={
        GetAction=function() return current end,
        GetActionTarget=function() return target end,
        GetPlayer=function() return {Name='Tester'} end,
    }
    local gFunc={EquipSet=function() end,Enable=function() end,Disable=function() end,CancelAction=function() end}
    local engine={}
    for _, name in ipairs({'load','unload','command','default','pretarget','precast','midcast','preshot','midshot','aftercast'}) do
        engine[name]=function(value) log[#log+1]={name,value} end
    end
    local state={update=function(_, snapshot)
        state_updates=state_updates+1
        log[#log+1]={'state',snapshot}
    end}
    local profile=bootstrap.create({gData=gData,gFunc=gFunc,engine=engine,state_runtime=state,
        snapshot=function()
            snapshot_count=snapshot_count+1
            log[#log+1]={'snapshot',snapshot_count}
            return {player={status='Idle'}}
        end})
    local expected={'OnLoad','OnUnload','HandleCommand','HandleDefault','HandleAbility','HandleItem',
        'HandlePrecast','HandleMidcast','HandlePreshot','HandleMidshot','HandleWeaponskill'}
    for _, name in ipairs(expected) do a.equal(type(profile[name]), 'function', name) end
    a.equal(profile.Aftercast, nil)
    profile.OnLoad(); profile.HandleCommand({'mode','cycle'})
    a.equal(log[1][1], 'load'); a.equal(log[2][1], 'command')

    -- GearSwap refreshes its user-facing globals at every player-action callback boundary.
    -- The refresh must happen before Rahvin sees the action, but must not also run the state
    -- diff hooks; those remain owned by HandleDefault/state_runtime.
    local function action_call(method)
        local log_before = #log
        local snapshots_before = snapshot_count
        local state_before = state_updates
        profile[method]()
        a.equal(snapshot_count, snapshots_before + 1,
            method .. ' must refresh the GearSwap snapshot before the action handler')
        a.equal(log[log_before + 1][1], 'snapshot',
            method .. ' must refresh before Rahvin action callbacks run')
        a.equal(state_updates, state_before,
            method .. ' snapshot refresh must not duplicate state-diff callbacks')
    end

    -- Pinned LAC does not call HandleDefault while PlayerAction is active. Completion clears
    -- PlayerAction first; the next outgoing chunk then reaches HandleDefault with GetAction=nil.
    local callbacks={{'HandleAbility','Ability'},{'HandleItem','Item'},{'HandleWeaponskill','Weaponskill'}}
    local after=0
    for index, row in ipairs(callbacks) do
        current={ActionType=row[2],Name=row[2],Id=index,Resend=false}
        action_call(row[1])
        current=nil
        profile.HandleDefault()
        profile.HandleDefault()
    end

    -- Spell and ranged callbacks happen pre -> mid while the action is active, then the same
    -- nil/default completion path. There is no GearSwap-style Aftercast profile callback.
    current={ActionType='Spell',Name='Fire',Id=20,Type='Black Magic',Resend=false,Resource={Index=20,Type=2}}
    action_call('HandlePrecast'); action_call('HandleMidcast'); current=nil; profile.HandleDefault(); profile.HandleDefault()
    current={ActionType='Ranged',Name='Ranged',Id=0,Resend=false}
    action_call('HandlePreshot'); action_call('HandleMidshot'); current=nil; profile.HandleDefault(); profile.HandleDefault()

    local saw_midcast,saw_midshot=false,false
    for _, item in ipairs(log) do
        if item[1]=='aftercast' then after=after+1 end
        saw_midcast=saw_midcast or item[1]=='midcast'
        saw_midshot=saw_midshot or item[1]=='midshot'
    end
    a.equal(after, #callbacks + 2, 'one aftercast per completed LAC action')
    a.equal(saw_midcast,true); a.equal(saw_midshot,true)

    -- A later identical non-resend cast is a new action even though its signature matches the
    -- previous cast. LAC marks packet duplicates explicitly with Resend instead.
    local before=after
    for _=1,2 do
        current={ActionType='Spell',Name='Fire',Id=20,Type='Black Magic',Resend=false,Resource={Index=20,Type=2}}
        action_call('HandlePrecast'); action_call('HandleMidcast'); current=nil; profile.HandleDefault()
    end
    after=0; for _, item in ipairs(log) do if item[1]=='aftercast' then after=after+1 end end
    a.equal(after,before+2,'identical sequential casts complete independently')

    profile.OnUnload(); a.equal(log[#log][1], 'unload')
end
