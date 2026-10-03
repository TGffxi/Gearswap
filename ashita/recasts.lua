local M = {}

local TICKS_PER_SECOND = 60

local function normalize(entries, key_name)
    if entries == nil then return nil end
    local result = {}
    for _, entry in ipairs(entries) do
        if type(entry) == 'table' then
            local key = tonumber(entry[key_name])
            local ticks = tonumber(entry.ticks)
            if key ~= nil and ticks ~= nil then
                result[key] = ticks / TICKS_PER_SECOND
            end
        end
    end
    return result
end

function M.new(source)
    source = source or {}
    local service = {}

    function service.abilities()
        if type(source.ability_entries) ~= 'function' then return nil end
        return normalize(source.ability_entries(), 'timer_id')
    end

    function service.spells()
        if type(source.spell_entries) ~= 'function' then return nil end
        return normalize(source.spell_entries(), 'id')
    end

    return service
end

local default_service

local function production_source()
    local core = rawget(_G, 'AshitaCore')
    if not core or type(core.GetMemoryManager) ~= 'function' then
        error('RahvinCompatError:recasts.ashita_unavailable', 3)
    end
    local memory = core:GetMemoryManager()
    local recast = memory and memory:GetRecast()
    local player = memory and memory:GetPlayer()
    if not recast then error('RahvinCompatError:recasts.ashita_unavailable', 3) end

    return {
        ability_entries = function()
            local result = {}
            for index = 0, 31 do
                local timer_id = tonumber(recast:GetAbilityTimerId(index)) or 0
                local ticks = tonumber(recast:GetAbilityTimer(index)) or 0
                -- Slot zero legitimately uses timer id zero for the one-hour ability.
                if timer_id ~= 0 or index == 0 then
                    result[#result + 1] = {timer_id=timer_id, ticks=ticks}
                end
            end
            return result
        end,
        spell_entries = function()
            local result = {}
            for id = 0, 1024 do
                local known = true
                if player and type(player.HasSpell) == 'function' then
                    known = player:HasSpell(id)
                end
                if known then
                    result[#result + 1] = {id=id, ticks=tonumber(recast:GetSpellTimer(id)) or 0}
                end
            end
            return result
        end,
    }
end

local function production_service()
    if not default_service then default_service = M.new(production_source()) end
    return default_service
end

function M.abilities()
    return production_service().abilities()
end

function M.spells()
    return production_service().spells()
end

return M
