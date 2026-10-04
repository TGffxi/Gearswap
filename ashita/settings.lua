local M = {}

local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    local mt = getmetatable(value)
    if mt then setmetatable(out, mt) end
    return out
end

local function merge(defaults, saved)
    if type(defaults) ~= 'table' then return copy(saved) end
    local out = copy(defaults)
    if type(saved) ~= 'table' then return out end
    for key, value in pairs(saved) do
        if type(value) == 'table' and type(out[key]) == 'table' then
            out[key] = merge(out[key], value)
        else
            out[key] = copy(value)
        end
    end
    return out
end

local function key_order(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == 'number' then return a < b end
    return tostring(a) < tostring(b)
end

local function serialize_value(value, seen, depth)
    local kind = type(value)
    if kind == 'nil' then return 'nil' end
    if kind == 'boolean' then return value and 'true' or 'false' end
    if kind == 'number' then
        if value ~= value or value == math.huge or value == -math.huge then
            error('RahvinCompatError:settings.unsupported_number', 3)
        end
        return tostring(value)
    end
    if kind == 'string' then return string.format('%q', value) end
    if kind ~= 'table' then
        error('RahvinCompatError:settings.unsupported_type:' .. kind, 3)
    end
    if seen[value] then error('RahvinCompatError:settings.cycle', 3) end
    seen[value] = true

    local keys = {}
    for key in pairs(value) do
        local kt = type(key)
        if kt ~= 'string' and kt ~= 'number' and kt ~= 'boolean' then
            error('RahvinCompatError:settings.unsupported_key:' .. kt, 3)
        end
        keys[#keys + 1] = key
    end
    table.sort(keys, key_order)

    local indent = string.rep('    ', depth)
    local child_indent = string.rep('    ', depth + 1)
    local lines = {'{'}
    for _, key in ipairs(keys) do
        local rendered_key = '[' .. serialize_value(key, seen, depth + 1) .. ']'
        local rendered_value = serialize_value(value[key], seen, depth + 1)
        lines[#lines + 1] = child_indent .. rendered_key .. ' = ' .. rendered_value .. ','
    end
    lines[#lines + 1] = indent .. '}'
    seen[value] = nil
    return table.concat(lines, '\n')
end

local function serialize(value)
    return 'return ' .. serialize_value(value, {}, 0) .. '\n'
end

local function decode(raw)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local loader = loadstring or load
    local chunk, err = loader(raw, '@rahvings/settings.lua')
    if not chunk then return nil, err end
    if setfenv then setfenv(chunk, {}) end
    local ok, value = pcall(chunk)
    if not ok or type(value) ~= 'table' then return nil, ok and 'settings root is not a table' or value end
    return value
end

local function separator_for(base)
    return base:find('\\', 1, true) and '\\' or '/'
end

local function strip_trailing(path)
    return (path:gsub('[\\/]+$', ''))
end

local function identity_part(value, label)
    value = tostring(value or '')
    if value == '' then error('RahvinCompatError:settings.identity.' .. label, 3) end
    local cleaned = value:gsub('[^%w%._%-]', '_')
    if cleaned == '' then error('RahvinCompatError:settings.identity.' .. label, 3) end
    return cleaned
end

local tmp_sequence = 0

function M.new(fs, base)
    if type(fs) ~= 'table' or type(fs.exists) ~= 'function' or type(fs.read) ~= 'function'
        or type(fs.mkdirp) ~= 'function' or type(fs.write) ~= 'function'
        or type(fs.rename) ~= 'function' or type(fs.remove) ~= 'function' then
        error('RahvinCompatError:settings.fs', 2)
    end
    if type(base) ~= 'string' or base == '' then error('RahvinCompatError:settings.base', 2) end

    base = strip_trailing(base)
    local sep = separator_for(base)
    local store = {}

    function store.path(identity)
        if type(identity) ~= 'table' then error('RahvinCompatError:settings.identity', 2) end
        local name = identity_part(identity.name, 'name')
        local id = identity_part(identity.id, 'id')
        return table.concat({base, name .. '_' .. id, 'rahvings', 'settings.lua'}, sep)
    end

    function store.load(identity, defaults)
        defaults = type(defaults) == 'table' and defaults or {}
        local path = store.path(identity)
        if not fs.exists(path) then return copy(defaults) end
        local raw = fs.read(path)
        local saved = decode(raw)
        if type(saved) ~= 'table' then return copy(defaults) end
        return merge(defaults, saved)
    end

    function store.save(identity, value)
        if type(value) ~= 'table' then error('RahvinCompatError:settings.value', 2) end
        local path = store.path(identity)
        local directory = path:match('^(.*)[\\/][^\\/]+$')
        if not directory or fs.mkdirp(directory) == false then return false end

        local ok, data = pcall(serialize, value)
        if not ok then error(data, 2) end

        tmp_sequence = tmp_sequence + 1
        local temp = path .. '.tmp.' .. tostring(tmp_sequence)
        pcall(fs.remove, temp)
        if fs.write(temp, data) == false then
            pcall(fs.remove, temp)
            return false
        end
        if fs.rename(temp, path) ~= false then
            return true
        end

        -- Some Windows/Ashita file-system implementations refuse rename(temp, final) while
        -- final already exists. Preserve the last valid file until the replacement is ready:
        -- move it aside, install the fully-written temp file, then delete the backup. If the
        -- install fails, restore the backup before returning failure.
        if not fs.exists(path) then
            pcall(fs.remove, temp)
            return false
        end

        tmp_sequence = tmp_sequence + 1
        local backup = path .. '.bak.' .. tostring(tmp_sequence)
        pcall(fs.remove, backup)

        if fs.rename(path, backup) == false then
            pcall(fs.remove, temp)
            return false
        end

        if fs.rename(temp, path) == false then
            local restored = fs.rename(backup, path)
            pcall(fs.remove, temp)
            if restored ~= false then
                pcall(fs.remove, backup)
            end
            return false
        end

        pcall(fs.remove, backup)
        return true
    end

    return store
end

local function production_fs()
    local root = rawget(_G, 'ashita')
    local afs = root and root.fs
    if type(afs) ~= 'table' or type(afs.exists) ~= 'function'
        or type(afs.create_directory) ~= 'function' or type(afs.rename) ~= 'function'
        or type(afs.remove) ~= 'function' then
        error('RahvinCompatError:settings.ashita_fs', 3)
    end

    return {
        exists=function(path) return afs.exists(path) end,
        read=function(path)
            local file = io.open(path, 'rb')
            if not file then return nil end
            local data = file:read('*a')
            file:close()
            return data
        end,
        mkdirp=function(path)
            if afs.exists(path) then return true end
            return afs.create_directory(path) ~= false
        end,
        write=function(path, data)
            local file = io.open(path, 'wb')
            if not file then return false end
            local ok = file:write(data) ~= nil
            file:flush()
            file:close()
            return ok
        end,
        rename=function(from, to) return afs.rename(from, to) ~= false end,
        remove=function(path)
            if not afs.exists(path) then return true end
            return afs.remove(path) ~= false
        end,
    }
end

local default_store
local function production_store()
    if default_store then return default_store end
    local core = rawget(_G, 'AshitaCore')
    if not core or type(core.GetInstallPath) ~= 'function' then
        error('RahvinCompatError:settings.install_path', 3)
    end
    local install = core:GetInstallPath()
    if type(install) ~= 'string' or install == '' then
        error('RahvinCompatError:settings.install_path', 3)
    end
    local base = strip_trailing(install) .. '\\config\\addons\\luashitacast'
    default_store = M.new(production_fs(), base)
    return default_store
end

function M.path(identity)
    return production_store().path(identity)
end

function M.load(identity, defaults)
    return production_store().load(identity, defaults)
end

function M.save(identity, value)
    return production_store().save(identity, value)
end

return M
