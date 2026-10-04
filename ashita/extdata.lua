local M = {}

local EPOCH_CORRECTION = 18000

local function need(value, label)
    if value == nil then error('RahvinCompatError:extdata.' .. label, 3) end
    return value
end

local function field(item, upper, lower)
    local value = item and item[upper]
    if value == nil and item then value = item[lower] end
    return value
end

local function clamp_wait(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    return value
end

local function augment_strings(value)
    local out = {}
    if type(value) ~= 'table' or value.Type == 'Unaugmented' then return out end
    local augs = value.Augs or value.augments
    if type(augs) ~= 'table' then return out end
    for _, entry in pairs(augs) do
        local text
        if type(entry) == 'table' then
            text = entry.String or entry.string
        elseif type(entry) == 'string' then
            text = entry
        end
        if type(text) == 'string' and text ~= '' then
            out[#out + 1] = text
        end
    end
    return out
end

function M.new(deps)
    deps = deps or {}
    local clock = need(deps.clock, 'clock')
    local timer = need(deps.timer, 'timer')
    local augment = need(deps.augment, 'augment')

    local service = {}

    function service.decode(item)
        if type(item) ~= 'table' and type(item) ~= 'userdata' then
            error('RahvinCompatError:extdata.item', 2)
        end

        local equipped = tonumber(field(item, 'Status', 'status')) == 5
        local timers = timer(item, equipped) or {}
        local now = tonumber(clock())
        if now == nil then error('RahvinCompatError:extdata.clock', 2) end
        local base = now - EPOCH_CORRECTION

        local recast = clamp_wait(timers.recast)
        local activation = clamp_wait(timers.activation)
        local usable = timers.usable
        if usable == nil then usable = recast <= 0 and activation <= 0 end

        return {
            usable=usable == true,
            next_use_time=base + recast,
            activation_time=base + activation,
            augments=augment_strings(augment(item)),
        }
    end

    return service
end

local function require_module(name, label)
    local ok, value = pcall(require, name)
    if not ok then
        error('RahvinCompatError:extdata.' .. label .. ':' .. tostring(value), 3)
    end
    return value
end

function M.production(deps)
    deps = deps or {}

    local core = deps.core or rawget(_G, 'AshitaCore')
    if core == nil or type(core.GetResourceManager) ~= 'function' then
        error('RahvinCompatError:extdata.core', 2)
    end
    local manager = core:GetResourceManager()
    if manager == nil or type(manager.GetItemById) ~= 'function' then
        error('RahvinCompatError:extdata.resources', 2)
    end

    local gData = deps.gData or rawget(_G, 'gData')
    if type(gData) ~= 'table' or type(gData.GetAugment) ~= 'function' then
        error('RahvinCompatError:extdata.gData', 2)
    end

    local itemdata = deps.itemdata or require_module('ffxi.itemdata', 'itemdata')
    local time = deps.time or require_module('ffxi.time', 'time')
    if type(itemdata.parse_timer_info) ~= 'function' then
        error('RahvinCompatError:extdata.itemdata.parse_timer_info', 2)
    end
    if type(time.game_time_diff) ~= 'function' then
        error('RahvinCompatError:extdata.time.game_time_diff', 2)
    end

    local clock = deps.clock or os.time

    local function timer(item, equipped)
        local id = tonumber(field(item, 'Id', 'id'))
        if id == nil or id == 0 then
            error('RahvinCompatError:extdata.item_id', 2)
        end
        local resource = manager:GetItemById(id)
        if resource == nil then
            return {recast=0, activation=0, usable=true}
        end

        -- Ashita's parser only exposes the packed timer timestamps in raw mode. Enable that
        -- mode for this one parse and restore the caller's setting immediately afterwards.
        local config = itemdata.config
        local previous_raw
        if type(config) == 'table' then
            previous_raw = config.use_raw
            config.use_raw = true
        end
        local ok, parsed = pcall(itemdata.parse_timer_info, item, resource, equipped)
        if type(config) == 'table' then config.use_raw = previous_raw end
        if not ok then error(parsed, 2) end
        parsed = parsed or {}

        local recast, activation = 0, 0
        local raw = parsed.raw
        if type(raw) == 'table' and raw.time_value1 ~= nil then
            recast = clamp_wait(time.game_time_diff(raw.time_value1))
        elseif parsed.use_delay ~= nil then
            recast = clamp_wait(parsed.use_delay)
        end

        if not equipped then
            activation = clamp_wait(parsed.cast_delay or resource.CastDelay)
        elseif type(raw) == 'table' and raw.time_value2 ~= nil then
            activation = clamp_wait(time.game_time_diff(raw.time_value2))
        end

        -- Match Ashita's own timer parser: zero remaining charges means no timer wait for
        -- ordinary charged items; infinite-charge items (255) retain the timer value.
        local max_charges = tonumber(parsed.max_charges or resource.MaxCharges)
        local remaining = tonumber(parsed.remaining_charges)
        if max_charges ~= nil and max_charges ~= 255 and remaining == 0 then
            recast = 0
        end

        return {
            recast=recast,
            activation=activation,
            usable=recast <= 0 and activation <= 0,
        }
    end

    return M.new({
        clock=clock,
        timer=timer,
        augment=function(item) return gData.GetAugment(item) end,
    })
end

return M
