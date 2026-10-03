local a = require('tests.lib.assertions')
local harness = require('tests.lib.rahvin_harness')

local function action(values)
    local spell={
        name='Test', english='Test', id=1, recast_id=1,
        action_type='Magic', type='WhiteMagic', skill='Enhancing Magic',
        element='Light', element_id=6,
        target={id=1,index=1,name='Tester',type='SELF'},
    }
    for key,value in pairs(values or {}) do spell[key]=value end
    return spell
end

return function()
    local h=harness.new({job='WAR'})
    local e=h.env

    -- The compatibility test must execute Rahvin's unchanged builders, not replay a list of
    -- layers prepared by the test. Keep weapon selection inert unless a case is about it.
    h:set_weapon_mode({'OFF'}, 'OFF')
    e.sets.Weapons={OFF={}}
    h:set_offense({'TP','ACC','DT','PDL','SB','CRIT','MEVA'}, 'TP')

    -- choose_set: idle and engaged decisions plus the actual offense-mode child lookup.
    e.sets.Idle={body='IdleBody',feet='IdleFeet',TP={head='IdleTP'}}
    e.player.status='Idle'
    local built=h:choose()
    a.equal(built.body,'IdleBody','Rahvin idle builder base')
    a.equal(built.feet,'IdleFeet','Rahvin idle builder feet')
    a.equal(built.head,'IdleTP','Rahvin idle builder offense child')

    e.sets.OffenseMode={body='EngagedBase',TP={body='TPBody',hands='TPHands'},
        ACC={hands='ACCHands'},DT={body='DTBody'},PDL={legs='PDLLegs'},
        SB={waist='SBWaist'},CRIT={feet='CRITFeet'},MEVA={body='MEVABody'}}
    e.player.status='Engaged'
    local mode_expect={
        TP={'body','TPBody'}, ACC={'hands','ACCHands'}, DT={'body','DTBody'},
        PDL={'legs','PDLLegs'}, SB={'waist','SBWaist'}, CRIT={'feet','CRITFeet'},
        MEVA={'body','MEVABody'},
    }
    for mode,expected in pairs(mode_expect) do
        e.state.OffenseMode:set(mode)
        built=h:choose()
        a.equal(built[expected[1]], expected[2], 'Rahvin engaged '..mode..' decision')
    end

    -- Aftermath is selected by Rahvin itself, not represented as a preselected test layer.
    e.state.OffenseMode:set('TP')
    e.sets.OffenseMode.AM3={head='AM3Head'}
    e.buffactive['Aftermath: Lv.3']=true
    built=h:choose()
    a.equal(built.head,'AM3Head','Rahvin Aftermath tier decision')
    e.buffactive['Aftermath: Lv.3']=nil

    -- precastequip: named melee weaponskill and the family taxonomy used by DNC/SCH/RUN.
    e.sets.Idle={body='IdleFloor'}
    e.sets.WS={head='WSBase'}
    e.sets.WS['Savage Blade']={head='SavageHead',body='SavageBody'}
    built=h:precast(action({name='Savage Blade',english='Savage Blade',type='WeaponSkill',
        action_type='Ability',skill='Great Sword',target={id=2,index=2,name='Mob',type='MONSTER'}}))
    a.equal(built.head,'SavageHead','Rahvin named WS overlay')
    a.equal(built.body,'SavageBody','Rahvin named WS body')

    e.sets.JA={head='JABase'}
    e.sets.Waltz={body='WaltzBody'}
    e.sets.Jig={body='JigBody'}
    e.sets.Samba={body='SambaBody'}
    e.sets.Step={body='StepBody'}
    e.sets.Flourish={body='FlourishBody'}
    local family_cases={
        {'Scholar','head','JABase'}, {'Rune','head','JABase'}, {'Ward','head','JABase'},
        {'Effusion','head','JABase'}, {'Waltz','body','WaltzBody'}, {'Jig','body','JigBody'},
        {'Samba','body','SambaBody'}, {'Step','body','StepBody'},
        {'Flourish1','body','FlourishBody'}, {'Flourish2','body','FlourishBody'},
        {'Flourish3','body','FlourishBody'},
    }
    for _,row in ipairs(family_cases) do
        built=h:precast(action({name=row[1]..' Test',english=row[1]..' Test',type=row[1],action_type='Ability'}))
        a.equal(built[row[2]],row[3],'Rahvin precast family '..row[1])
    end

    -- midcastequip: SELF is semantically significant in Rahvin. These cases prove the
    -- translated target reaches the unchanged builder decisions rather than only lac_data.
    e.sets.Midcast.Enhancing={body='EnhancingBody',Others={hands='OthersHands'}}
    built=h:midcast(action({name='Haste',english='Haste',type='WhiteMagic',skill='Enhancing Magic',
        target={id=1,index=1,name='Tester',type='SELF'}}))
    a.equal(built.body,'EnhancingBody','self enhancing base')
    a.equal(built.hands,nil,'self enhancing must not take Others')

    built=h:midcast(action({name='Haste',english='Haste',type='WhiteMagic',skill='Enhancing Magic',
        target={id=2,index=2,name='Other',type='PLAYER'}}))
    a.equal(built.body,'EnhancingBody','other enhancing base')
    a.equal(built.hands,'OthersHands','other enhancing must take Others')

    e.sets.Midcast.Enhancing={head='NinjutsuSelf',Others={}}
    built=h:midcast(action({name='Myoshu: Ichi',english='Myoshu: Ichi',type='Ninjutsu',skill='Ninjutsu',
        element='Fire',element_id=0,target={id=1,index=1,name='Tester',type='SELF'}}))
    a.equal(built.head,'NinjutsuSelf','self-target Ninjutsu enhancing decision')

    e.sets.Geomancy={Indi={body='IndiBody',Entrust={hands='EntrustHands'}},Geo={body='GeoBody'}}
    built=h:midcast(action({name='Indi-Haste',english='Indi-Haste',type='Geomancy',skill='Geomancy',
        target={id=1,index=1,name='Tester',type='SELF'}}))
    a.equal(built.body,'IndiBody','self Indi decision')
    a.equal(built.hands,nil,'self Indi must not use Entrust')

    built=h:midcast(action({name='Indi-Haste',english='Indi-Haste',type='Geomancy',skill='Geomancy',
        target={id=2,index=2,name='Other',type='PLAYER'}}))
    a.equal(built.body,'IndiBody','Entrust Indi base')
    a.equal(built.hands,'EntrustHands','other-target Indi must use Entrust')
end
