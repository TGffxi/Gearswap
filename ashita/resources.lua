local M = {}

local bitlib = rawget(_G, 'bit') or require('bit')

local set_mt = {
    __index = {
        contains = function(self, value)
            return self[value] ~= nil and self[value] ~= false
        end,
    },
}

local function set(values)
    return setmetatable(values or {}, set_mt)
end

local function decode(value)
    if value == nil then return nil end
    if type(value) == 'string' then return value end
    return tostring(value)
end

local function first_name(value, fallback)
    if type(value) == 'table' then
        value = value[1] or value.en or value.english
    end
    value = decode(value)
    if value == nil or value == '' then return fallback end
    return value
end

local function mask_set(mask, first_bit, last_bit, offset)
    local out = {}
    mask = tonumber(mask) or 0
    offset = offset or 0
    for bit_index = first_bit, last_bit do
        if bitlib.band(mask, bitlib.lshift(1, bit_index)) ~= 0 then
            out[bit_index + offset] = true
        end
    end
    return set(out)
end

local TARGETS = {
    [0] = 'Self',
    [1] = 'Player',
    [2] = 'Party',
    [3] = 'Alliance',
    [4] = 'NPC',
    [5] = 'Enemy',
    [6] = 'Object',
    [7] = 'Corpse',
}

local function target_set(mask)
    local out = {}
    mask = tonumber(mask) or 0
    for bit_index = 0, 7 do
        if bitlib.band(mask, bitlib.lshift(1, bit_index)) ~= 0 then
            out[TARGETS[bit_index]] = true
        end
    end
    return set(out)
end

local ELEMENTS = {
    [0]  = {en='Fire',      english='Fire',      ja='火', japanese='火'},
    [1]  = {en='Ice',       english='Ice',       ja='氷', japanese='氷'},
    [2]  = {en='Wind',      english='Wind',      ja='風', japanese='風'},
    [3]  = {en='Earth',     english='Earth',     ja='土', japanese='土'},
    [4]  = {en='Lightning', english='Lightning', ja='雷', japanese='雷'},
    [5]  = {en='Water',     english='Water',     ja='水', japanese='水'},
    [6]  = {en='Light',     english='Light',     ja='光', japanese='光'},
    [7]  = {en='Dark',      english='Dark',      ja='闇', japanese='闇'},
    [15] = {en='None',      english='None',      ja='無', japanese='無'},
}

local BAGS = {
    [0]  = 'Inventory',
    [1]  = 'Safe',
    [2]  = 'Storage',
    [3]  = 'Temporary',
    [4]  = 'Locker',
    [5]  = 'Satchel',
    [6]  = 'Sack',
    [7]  = 'Case',
    [8]  = 'Wardrobe',
    [9]  = 'Safe 2',
    [10] = 'Wardrobe 2',
    [11] = 'Wardrobe 3',
    [12] = 'Wardrobe 4',
    [13] = 'Wardrobe 5',
    [14] = 'Wardrobe 6',
    [15] = 'Wardrobe 7',
    [16] = 'Wardrobe 8',
}

local ABILITY_TYPES = {
    [9]   = 'Rune',
    [101] = 'Ready',
    [172] = 'Ward',
    [173] = 'BloodPactWard',
    [174] = 'BloodPactRage',
    [192] = 'CorsairRoll',
    [194] = 'CorsairShot',
}

local function ability_type(raw)
    -- LuAshitacast classifies these families from the ability recast timer id. Keep the
    -- Rahvin-facing names here without leaking LAC's naming/indexing convention upstream.
    local recast = tonumber(raw.RecastTimerId)
    if recast == 193 then return 'CorsairRoll' end
    if recast == 195 then return 'CorsairShot' end
    if recast == 10 then return 'Rune' end
    if recast == 102 then return 'Ready' end
    if recast == 173 then return 'Ward' end
    if recast == 174 then return 'BloodPactRage' end

    local tid = tonumber(raw.Type)
    return (tid and ABILITY_TYPES[tid]) or 'JobAbility'
end

local function make_item(source, id)
    local raw = source.item(id)
    if raw == nil then return nil end
    local name = first_name(raw.Name, tostring(id))
    local log_name = first_name(raw.LogNameSingular, name)
    return {
        id=tonumber(raw.Id) or id,
        en=name,
        english=name,
        enl=log_name,
        english_log=log_name,
        level=tonumber(raw.Level),
        jobs=mask_set(raw.Jobs, 0, 23, 1),
        races=mask_set(raw.Races, 0, 7, 1),
        slots=mask_set(raw.Slots, 0, 15, 0),
        targets=target_set(raw.Targets),
        skill=tonumber(raw.Skill),
        cast_time=tonumber(raw.CastTime),
        cast_delay=tonumber(raw.CastDelay),
        recast_delay=tonumber(raw.RecastDelay),
        max_charges=tonumber(raw.MaxCharges),
        type=tonumber(raw.Type),
    }
end

local function make_spell(source, id)
    local raw = source.spell(id)
    if raw == nil then return nil end
    local name = first_name(raw.Name, tostring(id))
    return {
        id=tonumber(raw.Index) or tonumber(raw.Id) or id,
        en=name,
        english=name,
        element=tonumber(raw.Element),
        skill=tonumber(raw.Skill),
        type=tonumber(raw.Type),
        cast_time=(tonumber(raw.CastTime) or 0) / 4,
        recast=(tonumber(raw.RecastDelay) or 0) / 4,
        mp_cost=tonumber(raw.ManaCost),
        targets=target_set(raw.Targets),
    }
end

local function make_buff(source, id)
    local raw = source.buff(id)
    local name = source.string('buffs.names', id)
    if raw == nil and (name == nil or name == '') then return nil end
    name = first_name(name, tostring(id))
    return {
        id=(raw and (tonumber(raw.Id) or tonumber(raw.Index))) or id,
        en=name,
        english=name,
    }
end

local function make_job(source, id)
    local full = source.string('jobs.names', id)
    local abbr = source.string('jobs.names_abbr', id)
    if (full == nil or full == '') and (abbr == nil or abbr == '') then return nil end
    full = first_name(full, tostring(id))
    abbr = first_name(abbr, full)
    return {id=id, en=abbr, english=full, name=full}
end

local function make_zone(source, id)
    local name = source.string('zones.names', id)
    if name == nil or name == '' then return nil end
    name = first_name(name, tostring(id))
    return {id=id, en=name, english=name}
end

local function fill(collection, ids, make)
    for _, id in ipairs(ids) do
        local row = make(id)
        if row ~= nil then collection[id] = row end
    end
end

local function range_ids(first, last)
    local out = {}
    for id = first, last do out[#out + 1] = id end
    return out
end

local function build_roll_buff_index(buffs)
    local by_name = {}
    for id, row in pairs(buffs) do
        if type(row) == 'table' and type(row.en) == 'string' then
            by_name[row.en:lower()] = id
        end
    end
    return by_name
end

function M.new(source, limits)
    if type(source) ~= 'table' then error('RahvinCompatError:resources.source', 2) end
    for _, name in ipairs({'item','ability','spell','buff','string'}) do
        if type(source[name]) ~= 'function' then
            error('RahvinCompatError:resources.' .. name, 2)
        end
    end

    limits = limits or {}
    local item_ids = limits.item_ids or range_ids(0, 65535)
    local ability_ids = limits.ability_ids or range_ids(0, 2047)
    local spell_ids = limits.spell_ids or range_ids(0, 2047)
    local buff_ids = limits.buff_ids or range_ids(0, 1023)
    local zone_ids = limits.zone_ids or range_ids(0, 1023)
    local job_ids = limits.job_ids or range_ids(1, 24)

    local result = {
        items={},
        buffs={},
        job_abilities={},
        weapon_skills={},
        spells={},
        elements={},
        zones={},
        jobs={},
        bags={},
    }

    fill(result.items, item_ids, function(id) return make_item(source, id) end)
    fill(result.buffs, buff_ids, function(id) return make_buff(source, id) end)
    fill(result.spells, spell_ids, function(id) return make_spell(source, id) end)
    fill(result.zones, zone_ids, function(id) return make_zone(source, id) end)
    fill(result.jobs, job_ids, function(id) return make_job(source, id) end)

    for id, row in pairs(ELEMENTS) do
        result.elements[id] = {
            id=id,
            en=row.en, english=row.english,
            ja=row.ja, japanese=row.japanese,
        }
    end
    for id, name in pairs(BAGS) do
        result.bags[id] = {id=id, en=name, english=name}
    end

    local roll_buffs = build_roll_buff_index(result.buffs)
    for _, id in ipairs(ability_ids) do
        local raw = source.ability(id)
        if raw ~= nil then
            local name = first_name(raw.Name, tostring(id))
            local kind = ability_type(raw)
            local row = {
                id=tonumber(raw.Id) or id,
                en=name,
                english=name,
                type=kind,
                recast_id=tonumber(raw.RecastTimerId),
                tp_cost=tonumber(raw.TPCost),
                targets=target_set(raw.Targets),
            }
            if kind == 'CorsairRoll' then
                row.status = roll_buffs[name:lower()]
            end
            result.job_abilities[id] = row

            -- Ashita exposes weapon skills through the ability resource table as well.  A
            -- dedicated classification is not currently consumed by Rahvin, but preserve the
            -- collection and populate it when the resource identifies the usual WS type.
            if tonumber(raw.Type) == 3 then
                result.weapon_skills[id] = row
            end
        end
    end

    return result
end

function M.production(core, limits)
    if core == nil or type(core.GetResourceManager) ~= 'function' then
        error('RahvinCompatError:resources.core', 2)
    end
    local manager = core:GetResourceManager()
    if manager == nil then error('RahvinCompatError:resources.manager', 2) end

    local decode_fn = limits and limits.decode
    if decode_fn == nil then
        local ok, encoding = pcall(require, 'encoding')
        if ok and type(encoding) == 'table' and type(encoding.ShiftJIS_To_UTF8) == 'function' then
            decode_fn = function(value) return encoding:ShiftJIS_To_UTF8(value) end
        else
            decode_fn = function(value) return value end
        end
    end

    local source = {
        item=function(id) return manager:GetItemById(id) end,
        ability=function(id) return manager:GetAbilityById(id) end,
        spell=function(id) return manager:GetSpellById(id) end,
        buff=function(id) return manager:GetStatusIconById(id) end,
        string=function(tbl, id)
            local value = manager:GetString(tbl, id)
            if value == nil then return nil end
            return decode_fn(value)
        end,
        decode=decode_fn,
    }

    local opts = {}
    if limits then
        for key, value in pairs(limits) do
            if key ~= 'decode' then opts[key] = value end
        end
    end
    return M.new(source, opts)
end

return M
