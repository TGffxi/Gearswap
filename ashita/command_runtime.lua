local M = {}
local methods = {}
methods.__index = methods

local function need(deps, name)
    local fn = deps and deps[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:command_runtime.' .. name, 3)
    end
    return fn
end

local function trim(value)
    return (tostring(value or ''):gsub('^%s*(.-)%s*$', '%1'))
end

local function split_chain(command)
    local out, buf = {}, {}
    local quote
    local escaped = false
    local text = tostring(command or '')
    for i = 1, #text do
        local ch = text:sub(i, i)
        if escaped then
            buf[#buf + 1] = ch
            escaped = false
        elseif ch == '\\' then
            buf[#buf + 1] = ch
            escaped = true
        elseif quote then
            buf[#buf + 1] = ch
            if ch == quote then quote = nil end
        elseif ch == '"' or ch == "'" then
            quote = ch
            buf[#buf + 1] = ch
        elseif ch == ';' then
            out[#out + 1] = trim(table.concat(buf))
            buf = {}
        else
            buf[#buf + 1] = ch
        end
    end
    out[#out + 1] = trim(table.concat(buf))
    return out
end

function M.new(deps)
    deps = deps or {}
    return setmetatable({
        schedule=need(deps, 'schedule'),
        input=need(deps, 'input'),
        raw_command=need(deps, 'raw_command'),
        cancel_buff=need(deps, 'cancel_buff'),
        execute_script=need(deps, 'execute_script'),
        self_command=need(deps, 'self_command'),
        validate=need(deps, 'validate'),
    }, methods)
end

function methods:_unsupported(command)
    error('RahvinCompatError:command_unsupported:' .. tostring(command), 3)
end

function methods:_execute(segment)
    segment = trim(segment)
    if segment == '' then return true end

    local self_command = segment:match('^gs%s+c%s+(.+)$')
    if self_command then
        return self.self_command(trim(self_command))
    end

    local validate_args = segment:match('^gs%s+validate%s*(.*)$')
    if validate_args ~= nil then
        local args = {}
        for word in trim(validate_args):gmatch('%S+') do args[#args + 1] = word end
        return self.validate(args)
    end

    local cancel = segment:match('^cancel%s+([%+%-]?%d+)%s*$')
    if cancel then
        local id = tonumber(cancel)
        if id == nil or id < 0 or id > 65535 or id ~= math.floor(id) then
            error('RahvinCompatError:command_cancel_id:' .. tostring(cancel), 3)
        end
        return self.cancel_buff(id)
    end

    local script = segment:match('^exec%s+(.+)$')
    if script then return self.execute_script(trim(script)) end

    if segment == 'terminate' then
        return self:_unsupported('terminate')
    end
    if segment:match('^lua%s+') then
        return self:_unsupported(segment)
    end
    if segment:match('^send%s+@') then
        return self:_unsupported(segment)
    end
    if segment:match('^gs%s+') then
        return self:_unsupported(segment)
    end

    local input = segment:match('^input%s+(.+)$')
    if input then
        input = trim(input)
        if input:sub(1, 2) == '//' then
            return self.raw_command('/' .. input:sub(3))
        end
        return self.input(input)
    end

    -- Bind/unbind remain owned by the already-tested native keybind bridge.
    if segment:match('^bind%s+') or segment:match('^unbind%s+') then
        return self.raw_command(segment)
    end

    -- External Ashita addon commands use normal slash command syntax.  Rahvin sample jobs
    -- use bare Windower forms such as "aset set tanking".
    if segment:sub(1, 1) == '/' then
        return self.raw_command(segment)
    end
    return self.raw_command('/' .. segment)
end

function methods:_run(parts, index)
    local i = index or 1
    while i <= #parts do
        local segment = trim(parts[i])
        if segment ~= '' then
            local delay = segment:match('^wait%s+([%d%.]+)%s*$')
            if delay then
                delay = tonumber(delay)
                if delay == nil or delay < 0 then
                    error('RahvinCompatError:command_wait:' .. tostring(parts[i]), 3)
                end
                local next_index = i + 1
                if next_index <= #parts then
                    self.schedule(function()
                        self:_run(parts, next_index)
                    end, delay)
                end
                return true
            elseif segment:match('^wait%s+') then
                error('RahvinCompatError:command_wait:' .. segment, 3)
            else
                self:_execute(segment)
            end
        end
        i = i + 1
    end
    return true
end

function methods:send(command)
    if type(command) ~= 'string' then
        error('RahvinCompatError:command_string', 2)
    end
    return self:_run(split_chain(command), 1)
end

return M
