local M = {}
local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do result[copy(key, seen)] = copy(child, seen) end
    return setmetatable(result, getmetatable(value))
end
function M.copy(value) return copy(value) end
function M.combine(base, ...)
    if base == nil then base = {} end
    if type(base) ~= 'table' then error('RahvinCompatError:set_combine_argument:1', 2) end
    local result = copy(base)
    for index = 1, select('#', ...) do
        local overlay = select(index, ...)
        if overlay ~= nil then
            if type(overlay) ~= 'table' then error('RahvinCompatError:set_combine_argument:' .. (index + 1), 2) end
            for key, value in pairs(overlay) do result[copy(key)] = copy(value) end
        end
    end
    return result
end
return M
