local a = require('tests.lib.assertions')
local lac_data = require('ashita.lac_data')

local function provider(action, pet_action)
    local target = {Id=99, Index=7, Name='Target', Distance=4.5, Status='Engaged', Type='Monster', HPP=88}
    return {
        GetAction=function() return action end,
        GetPetAction=function() return pet_action end,
        GetActionTarget=function() return target end,
        GetTarget=function() return target end,
        GetPlayer=function() return {Name='Tester', MainJob='WAR', MainJobLevel=99, MainJobSync=99,
            SubJob='SAM', SubJobLevel=49, SubJobSync=49, Status='Idle', HP=1000, MaxHP=1200,
            HPP=83, MP=50, MaxMP=100, MPP=50, TP=1234, IsMoving=true} end,
        GetPet=function() return {Id=44, Index=8, Name='Pet', Distance=2, Status='Idle', HPP=90, TP=500} end,
        GetEnvironment=function() return {Area='Test Zone', Day='Firesday', DayElement='Fire',
            Weather='Fire x2', WeatherElement='Fire', RawWeather='Fire', RawWeatherElement='Fire', Time=12.30} end,
    }
end

return function()
    local cases = {
        {{ActionType='Spell', Name='Fire', Id=144, Type='Black Magic', Skill='Elemental Magic', Element='Fire',
            CastTime=2000, Recast=8000, Resource={Index=144,Type=2,Element=0,Skill=36}},
            'Magic', 'BlackMagic', '/magic'},
        {{ActionType='Weaponskill', Name='Savage Blade', Id=42},
            'Ability', 'WeaponSkill', '/weaponskill'},
        {{ActionType='Ability', Name='Provoke', Id=5, Type='Unknown', Resource={RecastTimerId=1}},
            'Ability', 'JobAbility', '/jobability'},
        {{ActionType='Ranged', Name='Ranged', Id=0},
            'Ranged Attack', 'Ranged Attack', '/range'},
        {{ActionType='Item', Name='Echo Drops', Id=100, CastTime=1000, Recast=0},
            'Item', 'Item', '/item'},
    }
    for _, case in ipairs(cases) do
        local got = lac_data.action(provider(case[1]))
        a.equal(got.action_type, case[2]); a.equal(got.type, case[3])
        a.equal(got.prefix, case[4], 'GearSwap action prefix must be preserved for ' .. case[1].ActionType)
        a.equal(got.name, case[1].Name); a.equal(got.english, case[1].Name); a.equal(got.id, case[1].Id)
        a.equal(got.target.id, 99); a.equal(got.target.index, 7); a.equal(got.target.name, 'Target')
        a.equal(got.target.distance, 4.5); a.equal(got.target.status, 'Engaged')
    end
    local spell = lac_data.action(provider(cases[1][1]))
    a.equal(spell.element, 'Fire'); a.equal(spell.element_id, 0); a.equal(spell.skill, 'Elemental Magic'); a.equal(spell.recast_id, 144)
    a.equal(spell.skill_id, 36, 'GearSwap numeric skill_id must come from the pinned LAC spell resource')
    a.equal(lac_data.action(provider({ActionType='Ability',Name='Light Shot',Id=1,Type='Quick Draw'})).type,'CorsairShot')
    a.equal(lac_data.action(provider({ActionType='Spell',Name='Cure',Id=1,Type='White Magic'})).type,'WhiteMagic')
    a.equal(lac_data.action(provider(nil)), nil)
    -- Pinned LAC GetPetAction is a separate shape from GetAction and does not expose a
    -- target. Normalize only fields that LAC actually supplies into the GearSwap pet spell.
    local pet_spell = lac_data.pet_action(provider(nil, {
        ActionType='Spell', Name='Fire II', Id=145, Type='Black Magic',
        Skill='Elemental Magic', Element='Fire', CastTime=2250, Recast=9000, MpCost=24,
    }))
    a.equal(pet_spell.name, 'Fire II'); a.equal(pet_spell.english, 'Fire II')
    a.equal(pet_spell.id, 145); a.equal(pet_spell.action_type, 'Magic')
    a.equal(pet_spell.type, 'BlackMagic'); a.equal(pet_spell.prefix, '/pet')
    a.equal(pet_spell.skill, 'Elemental Magic'); a.equal(pet_spell.element, 'Fire')
    a.equal(pet_spell.cast_time, 2250); a.equal(pet_spell.recast, 9000)
    a.equal(pet_spell.mp_cost, 24); a.equal(pet_spell.target, nil)

    local pet_ability = lac_data.pet_action(provider(nil, {
        ActionType='Ability', Name='Predator Claws', Id=173, Type='Blood Pact: Rage',
    }))
    a.equal(pet_ability.name, 'Predator Claws'); a.equal(pet_ability.english, 'Predator Claws')
    a.equal(pet_ability.action_type, 'Ability'); a.equal(pet_ability.type, 'BloodPactRage')
    a.equal(pet_ability.prefix, '/pet')

    local pet_mobskill = lac_data.pet_action(provider(nil, {
        ActionType='MobSkill', Name='Swooping Frenzy', Id=999,
    }))
    a.equal(pet_mobskill.name, 'Swooping Frenzy'); a.equal(pet_mobskill.english, 'Swooping Frenzy')
    a.equal(pet_mobskill.id, 999); a.equal(pet_mobskill.action_type, 'Monster Move')
    a.equal(pet_mobskill.prefix, '/pet')
    a.equal(lac_data.pet_action(provider(nil, nil)), nil)

    local p = lac_data.player(provider()); a.equal(p.name, 'Tester'); a.equal(p.main_job, 'WAR'); a.equal(p.is_moving, true)
    local pet = lac_data.pet(provider()); a.equal(pet.id, 44); a.equal(pet.name, 'Pet')
    local world = lac_data.world(provider()); a.equal(world.day, 'Firesday'); a.equal(world.weather, 'Fire x2')
    a.equal(world.day_element, 'Fire'); a.equal(world.weather_element, 'Fire'); a.equal(world.weather_intensity, 2)
    local target = lac_data.target(provider()); a.equal(target.id, 99); a.equal(target.index, 7)
    a.equal(target.type, 'MONSTER')
end
