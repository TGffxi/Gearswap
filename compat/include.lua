local M = {}
local source = debug.getinfo(1, 'S').source:sub(2)
local root = source:match('^(.*)[/\\]compat[/\\]include%.lua$') or '.'
local aliases = {Modes='compat/modes.lua'}
local function normalize(path)
    if type(path) ~= 'string' or path == '' or path:find('%.%.', 1, true) or path:match('^[/\\]') then
        error('RahvinCompatError:invalid_include:' .. tostring(path), 3)
    end
    path = path:gsub('\\', '/'):gsub('%.lua$', '')
    return aliases[path] or (path .. '.lua')
end
function M.load(path, env)
    local relative = normalize(path)
    local full = root .. '/' .. relative
    local file = io.open(full, 'rb')
    if not file then error('RahvinCompatError:include_not_found:' .. tostring(path), 2) end
    file:close()
    local chunk, err = loadfile(full)
    if not chunk then error('RahvinCompatError:include_compile:' .. tostring(path) .. ':' .. tostring(err), 2) end
    setfenv(chunk, env)
    return chunk()
end
return M
