local M = {}

local action_types = {
    Spell={'Magic', nil}, Weaponskill={'Ability', 'WeaponSkill'},
    Ability={'Ability', nil}, Ranged={'Ranged Attack', 'Ranged Attack'},
    Item={'Item', 'Item'},
}
local spell_types = {['White Magic']='WhiteMagic', ['Black Magic']='BlackMagic',
    Summoning='SummonerPact', ['Bard Song']='BardSong', ['Blue Magic']='BlueMagic'}
local ability_types = {['Quick Draw']='CorsairShot', ['Corsair Roll']='CorsairRoll',
    ['Blood Pact: Rage']='BloodPactRage', ['Blood Pact: Ward']='BloodPactWard',
    Ready='PetCommand'}
local entity_types = {PC='PLAYER', Monster='MONSTER', NPC='NPC', Party='PLAYER', Alliance='PLAYER'}

local function get(gData, name)
    local fn = gData and gData[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:gData.' .. name, 3) end
    return fn()
end

local function entity(value)
    if value == nil then return nil end
    return {id=value.Id, index=value.Index, name=value.Name, distance=value.Distance,
        status=value.Status, type=entity_types[value.Type] or value.Type, hpp=value.HPP, tp=value.TP}
end

function M.action(gData)
    local value = get(gData, 'GetAction')
    if value == nil then return nil end
    local kind = action_types[value.ActionType]
    if not kind then error('RahvinCompatError:unknown_action_type:' .. tostring(value.ActionType), 2) end
    local resource = value.Resource
    local recast_id = resource and (resource.RecastTimerId or resource.RecastId) or nil
    local rahvin_type = kind[2] or value.Type
    if value.ActionType == 'Spell' then rahvin_type = spell_types[value.Type] or value.Type
    elseif value.ActionType == 'Ability' then rahvin_type = ability_types[value.Type] or 'JobAbility' end
    return {
        english=value.Name, name=value.Name, id=value.Id, action_type=kind[1],
        type=rahvin_type, skill=value.Skill, element=value.Element,
        element_id=resource and resource.Element or nil,
        cast_time=value.CastTime, recast=value.Recast, recast_id=recast_id,
        target=entity(get(gData, 'GetActionTarget')),
    }
end

function M.target(gData) return entity(get(gData, 'GetTarget')) end
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
