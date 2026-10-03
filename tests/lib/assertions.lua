local M = {}
local function render(value, seen)
    if type(value) ~= 'table' then return tostring(value) end
    seen = seen or {}
    if seen[value] then return '<cycle>' end
    seen[value] = true
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local out = {}
    for _, key in ipairs(keys) do out[#out + 1] = ('[%s]=%s'):format(render(key, seen), render(value[key], seen)) end
    seen[value] = nil
    return '{' .. table.concat(out, ',') .. '}'
end
function M.equal(actual, expected, message)
    if actual ~= expected then error((message or 'values differ') .. (': expected %s, got %s'):format(render(expected), render(actual)), 2) end
end
local function same(a, b, seen)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    seen = seen or {}
    if seen[a] == b then return true end
    seen[a] = b
    for key, value in pairs(a) do if not same(value, b[key], seen) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
function M.deep_equal(actual, expected, message)
    if not same(actual, expected) then error((message or 'tables differ') .. (': expected %s, got %s'):format(render(expected), render(actual)), 2) end
end
function M.raises(fn, pattern, message)
    local ok, err = pcall(fn)
    if ok then error(message or 'expected an error', 2) end
    if pattern and not tostring(err):match(pattern) then error((message or 'wrong error') .. (': expected /%s/, got %s'):format(pattern, tostring(err)), 2) end
    return err
end
return M
