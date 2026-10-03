local a = require('tests.lib.assertions')
local lac_data = require('ashita.lac_data')
local runtime = require('ashita.action_runtime')
local state_runtime = require('ashita.state_runtime')

local function player(name)
    return {Name=name or 'Tester', MainJob='WAR', MainJobLevel=99, MainJobSync=99,
        SubJob='SAM', SubJobLevel=49, SubJobSync=49, Status='Idle', HP=1000, MaxHP=1200,
        HPP=83, MP=50, MaxMP=100, MPP=50, TP=1234, IsMoving=false}
end

local function provider(action, target, player_value)
    target = target or {Id=99, Index=7, Name='Target', Distance=4.5, Status='Engaged', Type='Monster', HPP=88}
    player_value = player_value or player('Tester')
    return {
        GetAction=function() return action end,
        GetActionTarget=function() return target end,
        GetTarget=function() return target end,
        GetPlayer=function() return player_value end,
        GetPet=function() return nil end,
        GetEnvironment=function() return {Area='Test Zone', Day='Firesday', DayElement='Fire',
            Weather='Clear', WeatherElement='None', RawWeather='Clear', RawWeatherElement='None', Time=12.00} end,
    }
end

local function action(kind, id, resend)
    return {action_type=kind, id=id, name=kind..id, english=kind..id, resend=resend == true,
        target={id=10,index=10,name='Target',type='MONSTER'}}
end

return function()
    -- Pinned Ashita MagicType resource values: Geomancy=7, Trust=8.
    local geo = lac_data.action(provider({ActionType='Spell',Name='Geo-Fury',Id=768,Type='Unknown',Skill='Geomancy',
        Resource={Index=768,Type=7,Element=3}}))
    a.equal(geo.type, 'Geomancy', 'Geomancy must be recovered from the real spell resource type')
    local trust = lac_data.action(provider({ActionType='Spell',Name='Valaineral',Id=896,Type='Unknown',Skill='Unknown',
        Resource={Index=896,Type=8,Element=15}}))
    a.equal(trust.type, 'Trust', 'Trust must be recovered from the real spell resource type')

    -- Spell recast_id must not depend on a nonexistent ISpell.RecastTimerId field.
    local fire = lac_data.action(provider({ActionType='Spell',Name='Fire',Id=144,Type='Black Magic',Skill='Elemental Magic',
        Element='Fire',Resource={Index=144,Id=144,Type=2,Element=0}}))
    a.equal(fire.recast_id, 144, 'spell recast id must come from the real spell identity')

    -- Pinned Ashita AbilityType resource values must preserve Rahvin/GearSwap families.
    local ability_types = {
        [0]='JobAbility', [1]='JobAbility', [2]='PetCommand', [6]='BloodPactRage',
        [8]='CorsairRoll', [9]='CorsairShot', [10]='BloodPactWard', [11]='Samba',
        [12]='Waltz', [13]='Step', [14]='Flourish1', [15]='Scholar', [16]='Jig',
        [17]='Flourish2', [18]='PetCommand', [19]='Flourish3', [21]='Rune',
        [22]='Ward', [23]='Effusion',
    }
    for resource_type, expected in pairs(ability_types) do
        local got = lac_data.action(provider({ActionType='Ability',Name='Ability'..resource_type,Id=100+resource_type,
            Type='Unknown',Resource={Type=resource_type,RecastTimerId=resource_type+1}}))
        a.equal(got.type, expected, 'ability resource type '..resource_type)
        a.equal(got.recast_id, resource_type+1, 'ability recast id '..resource_type)
    end

    -- SELF must be distinguishable from another PC using only fields pinned LAC actually exposes.
    local self_target = {Id=1,Index=1,Name='Tester',Distance=0,Status='Idle',Type='PC',HPP=100}
    local other_target = {Id=2,Index=2,Name='Other',Distance=4,Status='Idle',Type='PC',HPP=100}
    local self_spell = lac_data.action(provider({ActionType='Spell',Name='Sneak',Id=71,Type='White Magic',
        Resource={Index=71,Type=1,Element=6}}, self_target, player('Tester')))
    local other_spell = lac_data.action(provider({ActionType='Spell',Name='Protect',Id=43,Type='White Magic',
        Resource={Index=43,Type=1,Element=6}}, other_target, player('Tester')))
    a.equal(self_spell.target.type, 'SELF')
    a.equal(other_spell.target.type, 'PLAYER')

    -- LAC Resend is part of the action identity contract.
    local resent = lac_data.action(provider({ActionType='Ability',Name='Provoke',Id=5,Type='Unknown',Resend=true,
        Resource={Type=1,RecastTimerId=5}}))
    a.equal(resent.resend, true)

    -- A genuine identical next start without an intervening HandleDefault is a new generation.
    local calls = {}
    local engine = {}
    for _, name in ipairs({'pretarget','precast','midcast','preshot','midshot','aftercast'}) do
        engine[name]=function(value) calls[#calls+1]={name=name,action=value} end
    end
    local r = runtime.new(engine, function() return 10 end)
    local g1 = r:begin(action('Magic', 1, false))
    local g2 = r:begin(action('Magic', 1, false))
    a.equal(g2, g1 + 1, 'identical non-resend next action must get a new generation')
    a.equal(calls[3].name, 'aftercast', 'previous identical action must close exactly once')
    r:tick(nil)
    local after=0; for _,call in ipairs(calls) do if call.name=='aftercast' then after=after+1 end end
    a.equal(after, 2, 'two genuine identical actions must produce two aftercasts')

    calls={}
    local rr = runtime.new(engine, function() return 10 end)
    local rg1 = rr:begin(action('Magic', 2, false))
    local rg2 = rr:begin(action('Magic', 2, true))
    a.equal(rg2, rg1, 'LAC resend must stay in the same generation')
    local resent_after=0; for _,call in ipairs(calls) do if call.name=='aftercast' then resent_after=resent_after+1 end end
    a.equal(resent_after, 0, 'resend must not close the active action')

    -- Rahvin busy semantics: status and pet are immediate; only buff-driven redress is deferred.
    local events, busy = {}, false
    local state_engine={
        is_busy=function() return busy end,
        status_change=function(new, old) events[#events+1]={'status',new,old} end,
        buff_change=function(name, gain) events[#events+1]={'buff',name,gain} end,
        pet_change=function(pet, gain) events[#events+1]={'pet',pet and pet.name,gain} end,
    }
    local s=state_runtime.new(state_engine)
    s:update({player={status='Idle'},buffs={},pet=nil})
    busy=true
    s:update({player={status='Engaged'},buffs={{id=33,name='Haste'}},pet={id=3,name='Carbuncle'}})
    a.deep_equal(events[1], {'status','Engaged','Idle'}, 'status must not be blocked by busy')
    a.deep_equal(events[2], {'pet','Carbuncle',true}, 'pet transition must not be blocked by busy')
    a.equal(#events, 2, 'buff change alone should remain deferred while busy')
    busy=false
    s:update({player={status='Engaged'},buffs={{id=33,name='Haste'}},pet={id=3,name='Carbuncle'}})
    a.deep_equal(events[3], {'buff','Haste',true}, 'deferred buff change must be replayed')
end
