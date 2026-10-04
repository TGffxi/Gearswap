local M = {}

local action_types = {
    Spell={'Magic', nil, '/magic'}, Weaponskill={'Ability', 'WeaponSkill', '/weaponskill'},
    Ability={'Ability', nil, '/jobability'}, Ranged={'Ranged Attack', 'Ranged Attack', '/range'},
    Item={'Item', 'Item', '/item'},
}
local spell_types = {['White Magic']='WhiteMagic', ['Black Magic']='BlackMagic',
    Summoning='SummonerPact', ['Bard Song']='BardSong', ['Blue Magic']='BlueMagic'}
-- Ashita v4 MagicType values from the pinned SDK. LAC can surface Type='Unknown'
-- while still exposing the underlying ISpell resource, so recover the GearSwap/Rahvin
-- family from the real resource instead of inventing LAC fields or spell-name rules.
local resource_magic_types = {
    [1]='WhiteMagic', [2]='BlackMagic', [3]='SummonerPact', [4]='Ninjutsu',
    [5]='BardSong', [6]='BlueMagic', [7]='Geomancy', [8]='Trust',
}
local ability_types = {['Quick Draw']='CorsairShot', ['Corsair Roll']='CorsairRoll',
    ['Blood Pact: Rage']='BloodPactRage', ['Blood Pact: Ward']='BloodPactWard',
    Ready='PetCommand'}
-- Ashita v4 AbilityType values from the pinned SDK. These resource types retain the
-- distinctions Rahvin/GearSwap uses even when LAC reports the high-level Type as Unknown.
local resource_ability_types = {
    [0]='JobAbility', [1]='JobAbility', [2]='PetCommand', [3]='WeaponSkill',
    [6]='BloodPactRage', [8]='CorsairRoll', [9]='CorsairShot', [10]='BloodPactWard',
    [11]='Samba', [12]='Waltz', [13]='Step', [14]='Flourish1', [15]='Scholar',
    [16]='Jig', [17]='Flourish2', [18]='PetCommand', [19]='Flourish3',
    [21]='Rune', [22]='Ward', [23]='Effusion',
}
local entity_types = {PC='PLAYER', Monster='MONSTER', NPC='NPC', Party='PLAYER', Alliance='PLAYER'}
local player_entity_types = {PC=true, Party=true, Alliance=true}

local function get(gData, name)
    local fn = gData and gData[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:gData.' .. name, 3) end
    return fn()
end

local function entity(value, player_name)
    if value == nil then return nil end
    local target_type = entity_types[value.Type] or value.Type
    -- Pinned LAC GetPlayer exposes the player's name while GetActionTarget/GetTarget expose
    -- entity Name + spawn classification but not a shared player id/index.  For a player-like
    -- target, matching the local player's name is therefore the strongest available identity
    -- signal and restores GearSwap's SELF category without inventing unsupported fields.
    if player_name ~= nil and value.Name == player_name and player_entity_types[value.Type] then
        target_type = 'SELF'
    end
    return {id=value.Id, index=value.Index, name=value.Name, distance=value.Distance,
        status=value.Status, type=target_type, hpp=value.HPP, tp=value.TP}
end

function M.action(gData)
    local value = get(gData, 'GetAction')
    if value == nil then return nil end
    local kind = action_types[value.ActionType]
    if not kind then error('RahvinCompatError:unknown_action_type:' .. tostring(value.ActionType), 2) end
    local resource = value.Resource
    local recast_id
    if value.ActionType == 'Spell' then
        -- Windower resources intentionally use the spell id as recast_id; SE changed the
        -- in-memory spell recast table to be indexed by spell id rather than a separate
        -- recast timer id. Ashita ISpell has no RecastTimerId field.
        recast_id = (resource and (resource.Id or resource.Index)) or value.Id
    elseif value.ActionType == 'Ability' or value.ActionType == 'Weaponskill' then
        recast_id = resource and resource.RecastTimerId or nil
    end
    local rahvin_type = kind[2] or value.Type
    if value.ActionType == 'Spell' then
        rahvin_type = spell_types[value.Type] or (resource and resource_magic_types[resource.Type]) or value.Type
    elseif value.ActionType == 'Ability' then
        rahvin_type = ability_types[value.Type]
            or (resource and resource_ability_types[resource.Type])
            or 'JobAbility'
    end
    local player = get(gData, 'GetPlayer')
    return {
        english=value.Name, name=value.Name, id=value.Id, action_type=kind[1],
        type=rahvin_type, prefix=kind[3], skill=value.Skill,
        skill_id=resource and resource.Skill or nil, element=value.Element,
        element_id=resource and resource.Element or nil,
        cast_time=value.CastTime, recast=value.Recast, recast_id=recast_id,
        target=entity(get(gData, 'GetActionTarget'), player and player.Name or nil),
        resend=value.Resend == true,
    }
end

function M.target(gData)
    local player = get(gData, 'GetPlayer')
    return entity(get(gData, 'GetTarget'), player and player.Name or nil)
end
function M.pet(gData) return entity(get(gData, 'GetPet')) end

function M.player(gData)
    local value = get(gData, 'GetPlayer')
    if value == nil then return nil end
    return {name=value.Name, main_job=value.MainJob, main_job_level=value.MainJobLevel,
        main_job_sync=value.MainJobSync, sub_job=value.SubJob, sub_job_level=value.SubJobLevel,
        sub_job_sync=value.SubJobSync, status=value.Status, hp=value.HP, max_hp=value.MaxHP,
        hpp=value.HPP, mp=value.MP, max_mp=value.MaxMP, mpp=value.MPP, tp=value.TP,
        is_moving=value.IsMoving}
end

function M.world(gData)
    local value = get(gData, 'GetEnvironment')
    if value == nil then return nil end
    local intensity = value.Weather and value.Weather:match(' x2$') and 2
        or (value.WeatherElement and value.WeatherElement ~= 'None' and 1 or 0)
    return {area=value.Area, day=value.Day, day_element=value.DayElement, weather=value.Weather,
        weather_element=value.WeatherElement, raw_weather=value.RawWeather,
        raw_weather_element=value.RawWeatherElement, time=value.Time, timestamp=value.Timestamp,
        moon=value.MoonPhase, moon_pct=value.MoonPercent, weather_intensity=intensity}
end

return M
