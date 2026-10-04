local sets = require('compat.sets')

local M = {}

-- GearSwap exposes one stable table sentinel named `empty`.  set_combine() deep-copies
-- tables, so mark the sentinel by metatable as well as by identity; compat.sets.copy()
-- preserves metatables and therefore preserves empty semantics through combined sets.
local EMPTY_MT = {}
local EMPTY = setmetatable({}, EMPTY_MT)
M.empty = EMPTY

local aliases = {
    name=true,
    priority=true,
    augments=true,
    augment=true,
    bag=true,
}

local function is_empty(item)
    return item == EMPTY or (type(item) == 'table' and getmetatable(item) == EMPTY_MT)
end

local function first(item, canonical, ...)
    local value = rawget(item, canonical)
    if value ~= nil then return value end
    for index = 1, select('#', ...) do
        value = rawget(item, select(index, ...))
        if value ~= nil then return value end
    end
    return nil
end

function M.normalize(item)
    if is_empty(item) then return 'remove' end
    if type(item) ~= 'table' then return item end

    -- Copy every non-GearSwap-alias field first.  This preserves LAC metadata such as
    -- AugPath/AugRank/AugTrial (and any future passthrough fields) without mutating Rahvin's
    -- source set. Canonical LAC spellings deliberately win if both shapes are present.
    local result = {}
    for key, value in pairs(item) do
        if not aliases[key] then
            result[sets.copy(key)] = sets.copy(value)
        end
    end

    local name = first(item, 'Name', 'name')
    if name ~= nil then result.Name = sets.copy(name) end

    local priority = first(item, 'Priority', 'priority')
    if priority ~= nil then result.Priority = sets.copy(priority) end

    local augment = first(item, 'Augment', 'augments', 'augment')
    if augment ~= nil then result.Augment = sets.copy(augment) end

    local bag = first(item, 'Bag', 'bag')
    if bag ~= nil then result.Bag = sets.copy(bag) end

    return setmetatable(result, getmetatable(item))
end

return M
