local copy = require('compat.sets').copy
local M = {}
local required = {'begin_snapshot','player','world','buffs','pet','equipment','inventory'}
local Snapshot = {}; Snapshot.__index = Snapshot
local function call(provider, name, generation)
    local fn = provider[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:snapshot_provider:' .. name, 3) end
    return copy(fn(provider, generation))
end
function M.new(provider)
    if type(provider) ~= 'table' then error('RahvinCompatError:snapshot_provider', 2) end
    return setmetatable({_provider=provider}, Snapshot)
end
function Snapshot:capture()
    local provider = self._provider
    local generation = call(provider, 'begin_snapshot')
    local buffs = call(provider, 'buffs', generation) or {}
    local active = {}
    for _, buff in ipairs(buffs) do
        if type(buff) ~= 'table' or buff.id == nil or buff.name == nil then error('RahvinCompatError:snapshot_buff', 2) end
        active[buff.id] = (active[buff.id] or 0) + 1
        active[buff.name] = (active[buff.name] or 0) + 1
    end
    return {
        generation=generation,
        player=call(provider, 'player', generation), world=call(provider, 'world', generation),
        buffactive=active, buffs=buffs, pet=call(provider, 'pet', generation),
        equipment=call(provider, 'equipment', generation), inventory=call(provider, 'inventory', generation),
    }
end


local BAG_FIELDS = {
    [0]='inventory',
    [8]='wardrobe',
    [10]='wardrobe2',
    [11]='wardrobe3',
    [12]='wardrobe4',
    [13]='wardrobe5',
    [14]='wardrobe6',
    [15]='wardrobe7',
    [16]='wardrobe8',
}

local EQUIPMENT_SLOTS = {
    'main','sub','range','ammo','head','neck','left_ear','right_ear',
    'body','hands','left_ring','right_ring','back','waist','legs','feet',
}

local function need_method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:snapshot.production.' .. (label or name), 3)
    end
    return fn
end

local function normalize_entity(value)
    if value == nil then return nil end
    return {
        id=value.Id or value.id,
        index=value.Index or value.index,
        name=value.Name or value.name,
        distance=value.Distance or value.distance,
        status=value.Status or value.status,
        type=value.Type or value.type,
        hpp=value.HPP or value.hpp,
        tp=value.TP or value.tp,
    }
end

local function build_equipment(gData)
    local slots = require('compat.slots')
    local raw = need_method(gData, 'GetEquipment', 'gData.GetEquipment')() or {}
    local equipment = {}
    for _, slot in ipairs(EQUIPMENT_SLOTS) do equipment[slot] = 'empty' end
    for lac_slot, entry in pairs(raw) do
        local ok, canonical = pcall(slots.to_gearswap, lac_slot)
        if ok and canonical then
            local name
            if type(entry) == 'table' then
                name = entry.Name or entry.name
                if name == nil and type(entry.Item) == 'table' then
                    name = entry.Item.Name or entry.Item.name
                end
            elseif type(entry) == 'string' then
                name = entry
            end
            if type(name) == 'string' and name ~= '' then equipment[canonical] = name end
        end
    end
    return equipment
end

local function build_bags(inventory, resources)
    local bags = {}
    for bag, field_name in pairs(BAG_FIELDS) do
        local view = {}
        local rows = inventory.iter_bag(bag) or {}
        for _, entry in ipairs(rows) do
            local row = resources.items and resources.items[entry.id]
            local name = row and (row.en or row.english)
            if type(name) == 'string' and name ~= '' then
                local current = view[name]
                if current == nil then
                    current = {
                        id=entry.id,
                        count=0,
                        bag=bag,
                    }
                    view[name] = current
                end
                current.count = current.count + (tonumber(entry.count) or 0)
            end
        end
        bags[field_name] = view
    end
    return bags
end

local function build_buffs(memory_player, resources)
    local ids = need_method(memory_player, 'GetBuffs', 'player.GetBuffs')(memory_player) or {}
    local list, active = {}, {}
    for _, id in ipairs(ids) do
        id = tonumber(id)
        if id and id > 0 and id ~= 255 then
            local row = resources.buffs and resources.buffs[id]
            local name = row and (row.en or row.english) or tostring(id)
            list[#list + 1] = {id=id, name=name}
            active[id] = (active[id] or 0) + 1
            active[name] = (active[name] or 0) + 1
        end
    end
    return ids, list, active
end

function M.production(deps)
    deps = deps or {}
    local core = deps.core or rawget(_G, 'AshitaCore')
    local gData = deps.gData or rawget(_G, 'gData')
    local inventory = deps.inventory or require('ashita.inventory')
    local resources = deps.resources

    if core == nil or type(core.GetMemoryManager) ~= 'function' then
        error('RahvinCompatError:snapshot.production.core', 2)
    end
    if type(gData) ~= 'table' then
        error('RahvinCompatError:snapshot.production.gData', 2)
    end
    if type(inventory) ~= 'table' or type(inventory.iter_bag) ~= 'function' then
        error('RahvinCompatError:snapshot.production.inventory', 2)
    end
    if type(resources) ~= 'table' then
        local resource_module = require('ashita.resources')
        resources = resource_module.production(core)
    end

    local memory = core:GetMemoryManager()
    if memory == nil then error('RahvinCompatError:snapshot.production.memory', 2) end
    local party = need_method(memory, 'GetParty', 'memory.GetParty')(memory)
    local memory_player = need_method(memory, 'GetPlayer', 'memory.GetPlayer')(memory)
    local entity = need_method(memory, 'GetEntity', 'memory.GetEntity')(memory)
    if party == nil or memory_player == nil or entity == nil then
        error('RahvinCompatError:snapshot.production.memory', 2)
    end

    local get_player = need_method(gData, 'GetPlayer', 'gData.GetPlayer')
    local get_environment = need_method(gData, 'GetEnvironment', 'gData.GetEnvironment')
    local get_pet = need_method(gData, 'GetPet', 'gData.GetPet')
    local get_target = need_method(gData, 'GetTarget', 'gData.GetTarget')

    return function()
        local lac_player = get_player() or {}
        local environment = get_environment() or {}
        local equipment = build_equipment(gData)
        local bags = build_bags(inventory, resources)
        local raw_buff_ids, buffs, buffactive = build_buffs(memory_player, resources)

        local index = tonumber(party:GetMemberTargetIndex(0)) or 0
        local id = tonumber(party:GetMemberServerId(0)) or 0
        local main_job_id = tonumber(memory_player:GetMainJob()) or 0
        local sub_job_id = tonumber(memory_player:GetSubJob()) or 0

        local jobs = {}
        local job_points = {}
        for job_id, row in pairs(resources.jobs or {}) do
            local abbr = row.en or row.name
            if type(abbr) == 'string' and abbr ~= '' then
                local level = tonumber(memory_player:GetJobLevel(job_id)) or 0
                jobs[abbr] = level
                job_points[abbr:lower()] = {
                    jp=tonumber(memory_player:GetJobPoints(job_id)) or 0,
                    jp_spent=tonumber(memory_player:GetJobPointsSpent(job_id)) or 0,
                }
            end
        end

        local player = {
            name=lac_player.Name or lac_player.name,
            id=id,
            index=index,
            main_job=lac_player.MainJob or lac_player.main_job,
            main_job_id=main_job_id,
            main_job_level=lac_player.MainJobLevel or lac_player.main_job_level,
            main_job_sync=lac_player.MainJobSync or lac_player.main_job_sync,
            sub_job=lac_player.SubJob or lac_player.sub_job,
            sub_job_id=sub_job_id,
            sub_job_level=lac_player.SubJobLevel or lac_player.sub_job_level,
            sub_job_sync=lac_player.SubJobSync or lac_player.sub_job_sync,
            status=lac_player.Status or lac_player.status,
            hp=lac_player.HP or lac_player.hp,
            max_hp=lac_player.MaxHP or lac_player.max_hp,
            hpp=lac_player.HPP or lac_player.hpp,
            mp=lac_player.MP or lac_player.mp,
            max_mp=lac_player.MaxMP or lac_player.max_mp,
            mpp=lac_player.MPP or lac_player.mpp,
            tp=lac_player.TP or lac_player.tp,
            is_moving=(lac_player.IsMoving == true or lac_player.is_moving == true),
            race_id=tonumber(entity:GetRace(index)),
            jobs=jobs,
            job_points=job_points,
            target=normalize_entity(get_target()),
            buffs=raw_buff_ids,
            equipment=equipment,
        }
        for field_name, bag in pairs(bags) do player[field_name] = bag end

        local weather = environment.Weather or environment.weather
        local weather_element = environment.WeatherElement or environment.weather_element
        local intensity
        if type(weather) == 'string' and weather:match(' x2$') then
            intensity = 2
        elseif weather_element ~= nil and weather_element ~= 'None' then
            intensity = 1
        else
            intensity = 0
        end
        local world = {
            area=environment.Area or environment.area,
            day=environment.Day or environment.day,
            day_element=environment.DayElement or environment.day_element,
            weather=weather,
            weather_element=weather_element,
            raw_weather=environment.RawWeather or environment.raw_weather,
            raw_weather_element=environment.RawWeatherElement or environment.raw_weather_element,
            time=environment.Time or environment.time,
            timestamp=environment.Timestamp or environment.timestamp,
            moon=environment.MoonPhase or environment.moon,
            moon_pct=environment.MoonPercent or environment.moon_pct,
            weather_intensity=intensity,
        }

        local pet_raw = get_pet()
        local pet = normalize_entity(pet_raw) or {}
        pet.isvalid = pet_raw ~= nil

        return {
            player=player,
            world=world,
            buffs=buffs,
            buffactive=buffactive,
            pet=pet,
            equipment=equipment,
            inventory=bags.inventory,
        }
    end
end

return M
