local M = {}

M.EQUIPPABLE_BAGS = {0, 8, 10, 11, 12, 13, 14, 15, 16}

local function field(item, upper, lower)
    local value = item and item[upper]
    if value == nil and item then value = item[lower] end
    return value
end

local function normalize(item, bag, index)
    if type(item) ~= 'table' and type(item) ~= 'userdata' then return nil end
    local id = tonumber(field(item, 'Id', 'id')) or 0
    local count = tonumber(field(item, 'Count', 'count')) or 0
    if id == 0 or count <= 0 then return nil end

    return {
        bag = bag,
        index = index,
        id = id,
        count = count,
        status = tonumber(field(item, 'Status', 'status')) or 0,
        extra = field(item, 'Extra', 'extra'),
        raw = field(item, 'Raw', 'raw') or item,
    }
end

function M.new(source)
    if type(source) ~= 'table' then error('RahvinCompatError:inventory.source', 2) end
    if type(source.container_max) ~= 'function' or type(source.container_item) ~= 'function' then
        error('RahvinCompatError:inventory.source', 2)
    end

    local service = {}

    function service.iter_bag(bag)
        bag = tonumber(bag)
        if bag == nil then error('RahvinCompatError:inventory.bag', 2) end
        local maximum = tonumber(source.container_max(bag)) or 0
        local result = {}
        for index = 1, maximum do
            local entry = normalize(source.container_item(bag, index), bag, index)
            if entry then result[#result + 1] = entry end
        end
        return result
    end

    function service.find_all(descriptor)
        if type(descriptor) ~= 'table' and type(descriptor) ~= 'string' then
            error('RahvinCompatError:inventory.descriptor', 2)
        end
        if type(source.compare_item) ~= 'function' then
            error('RahvinCompatError:inventory.compare_item', 2)
        end

        local result = {}
        for _, bag in ipairs(M.EQUIPPABLE_BAGS) do
            local entries = service.iter_bag(bag)
            for _, entry in ipairs(entries) do
                if source.compare_item(descriptor, entry.raw, bag) then
                    result[#result + 1] = entry
                end
            end
        end
        return result
    end

    return service
end

local default_service

local function production_source()
    local core = rawget(_G, 'AshitaCore')
    if not core or type(core.GetMemoryManager) ~= 'function' then
        error('RahvinCompatError:inventory.ashita_unavailable', 3)
    end
    local memory = core:GetMemoryManager()
    local manager = memory and memory:GetInventory()
    if not manager then error('RahvinCompatError:inventory.ashita_unavailable', 3) end

    return {
        container_max = function(bag)
            local n = manager:GetContainerCountMax(bag)
            n = tonumber(n) or 0
            if n < 0 then return 0 end
            if n > 80 then return 80 end
            return n
        end,
        container_item = function(bag, index)
            return manager:GetContainerItem(bag, index)
        end,
        compare_item = function(descriptor, item, bag)
            local gfunc = rawget(_G, 'gFunc')
            if type(gfunc) ~= 'table' or type(gfunc.CompareItem) ~= 'function' then
                error('RahvinCompatError:inventory.compare_item', 2)
            end
            return gfunc.CompareItem(descriptor, item, bag)
        end,
    }
end

local function production_service()
    if not default_service then default_service = M.new(production_source()) end
    return default_service
end

function M.iter_bag(bag)
    return production_service().iter_bag(bag)
end

function M.find_all(descriptor)
    return production_service().find_all(descriptor)
end

return M
