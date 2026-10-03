local M = {}

M.VERSION = 1
M.DEFAULT_PORT = 38471
M.DEFAULT_GROUP = '239.255.82.71'

local PREFIX = 'RGSIPC'

local function escape(value)
    value = tostring(value or '')
    return (value:gsub('([^%w%-%._~,])', function(ch)
        return ('%%%02X'):format(ch:byte())
    end))
end

local function unescape(value)
    return (value:gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function split_wire(raw)
    local fields = {}
    local from = 1
    while true do
        local pos = raw:find('|', from, true)
        if not pos then
            fields[#fields + 1] = raw:sub(from)
            break
        end
        fields[#fields + 1] = raw:sub(from, pos - 1)
        from = pos + 1
    end
    return fields
end

function M.encode(payload)
    if type(payload) ~= 'table' then return nil end
    local version = tonumber(payload.v)
    local timestamp = tonumber(payload.timestamp)
    if version ~= M.VERSION or not timestamp then return nil end
    if type(payload.sender) ~= 'string' or payload.sender == '' then return nil end
    if type(payload.kind) ~= 'string' or payload.kind == '' then return nil end
    if type(payload.phase) ~= 'string' or payload.phase == '' then return nil end

    return table.concat({
        PREFIX,
        tostring(version),
        escape(payload.sender),
        escape(payload.kind),
        escape(payload.phase),
        escape(payload.action or ''),
        escape(payload.target or ''),
        tostring(timestamp),
    }, '|')
end

function M.decode(raw)
    if type(raw) ~= 'string' then return nil end
    local fields = split_wire(raw)
    if #fields ~= 8 or fields[1] ~= PREFIX then return nil end

    local version = tonumber(fields[2])
    if version ~= M.VERSION then return nil end
    local timestamp = tonumber(fields[8])
    if not timestamp then return nil end

    local sender = unescape(fields[3])
    local kind = unescape(fields[4])
    local phase = unescape(fields[5])
    local action = unescape(fields[6])
    local target = unescape(fields[7])
    if sender == '' or kind == '' or phase == '' then return nil end

    return {
        v=version,
        sender=sender,
        kind=kind,
        phase=phase,
        action=action,
        target=target,
        timestamp=timestamp,
    }
end

function M.from_rahvin(message, sender, timestamp)
    if type(message) ~= 'string' then return nil end
    sender = tostring(sender or '')
    timestamp = tonumber(timestamp) or 0

    local tag, caster, target, action, sent =
        message:match('^RAHVIN|([^|]+)|([^|]+)|([^|]*)|([^|]+)|([^|]+)$')
    if tag == 'SPELL' or tag == 'ABILITY' then
        local at = tonumber(sent)
        if not at then return nil end
        return {
            v=M.VERSION,
            sender=caster,
            kind=tag,
            phase='START',
            action=action,
            target=target,
            timestamp=at,
        }
    end

    local complete_caster, complete_sent = message:match('^RAHVIN|COMPLETE|([^|]+)|([^|]+)$')
    if complete_caster then
        local at = tonumber(complete_sent)
        if not at then return nil end
        return {
            v=M.VERSION,
            sender=complete_caster,
            kind='CAST',
            phase='COMPLETE',
            action='',
            target='',
            timestamp=at,
        }
    end

    local asker = message:match('^RAHVIN|ROLLQ|([^|]+)$')
    if asker then
        return {
            v=M.VERSION,
            sender=sender,
            kind='ROLLQ',
            phase='QUERY',
            action='',
            target=asker,
            timestamp=timestamp,
        }
    end

    local to, buff, total = message:match('^RAHVIN|ROLL|([^|]+)|(%d+)|(%d+)$')
    if to then
        return {
            v=M.VERSION,
            sender=sender,
            kind='ROLL',
            phase='STATE',
            action=buff .. ',' .. total,
            target=to,
            timestamp=timestamp,
        }
    end

    return nil
end

function M.to_rahvin(payload)
    if type(payload) ~= 'table' or tonumber(payload.v) ~= M.VERSION then return nil end
    local sender = payload.sender
    local kind = payload.kind
    local phase = payload.phase
    local timestamp = tonumber(payload.timestamp)

    if (kind == 'SPELL' or kind == 'ABILITY') and phase == 'START' and sender and timestamp then
        return ('RAHVIN|%s|%s|%s|%s|%s'):format(
            kind,
            sender,
            tostring(payload.target or ''),
            tostring(payload.action or ''),
            tostring(timestamp))
    end

    if kind == 'CAST' and phase == 'COMPLETE' and sender and timestamp then
        return ('RAHVIN|COMPLETE|%s|%s'):format(sender, tostring(timestamp))
    end

    if kind == 'ROLLQ' and payload.target then
        return 'RAHVIN|ROLLQ|' .. tostring(payload.target)
    end

    if kind == 'ROLL' and payload.target then
        local buff, total = tostring(payload.action or ''):match('^(%d+),(%d+)$')
        if buff then
            return ('RAHVIN|ROLL|%s|%s|%s'):format(tostring(payload.target), buff, total)
        end
    end

    return nil
end

local function copy_payload(payload)
    return {
        v=payload.v,
        sender=payload.sender,
        kind=payload.kind,
        phase=payload.phase,
        action=payload.action,
        target=payload.target,
        timestamp=payload.timestamp,
    }
end

function M.new(transport, options)
    if type(transport) ~= 'table'
        or type(transport.send) ~= 'function'
        or type(transport.subscribe) ~= 'function' then
        error('RahvinCompatError:ipc.transport', 2)
    end

    options = options or {}
    local clock = options.clock or function() return os.clock() * 1000 end
    local max_age = tonumber(options.max_age) or 5000
    local sender = options.sender
    local subscribers = {}
    local seen = {}
    local closed = false
    local service = {}

    local function purge_seen(now)
        local cutoff = now - max_age
        for raw, at in pairs(seen) do
            if at < cutoff then seen[raw] = nil end
        end
    end

    local function receive(raw)
        if closed then return false end
        local message = M.decode(raw)
        if not message then return false end

        local now = tonumber(clock()) or 0
        if message.timestamp < (now - max_age) then return false end
        purge_seen(now)
        if seen[raw] then return false end
        seen[raw] = now

        local snapshot = {}
        for fn in pairs(subscribers) do snapshot[#snapshot + 1] = fn end
        for i=1,#snapshot do
            local ok = pcall(snapshot[i], copy_payload(message))
            if not ok then
                -- One subscriber must never prevent another Ashita client consumer from
                -- seeing the same packet. Error reporting is deliberately left to the
                -- subscriber/event layer that owns the callback.
            end
        end
        return true
    end

    local on_raw = receive
    transport.subscribe(on_raw)

    function service.send(payload)
        if closed or type(payload) ~= 'table' then return false end
        local message = copy_payload(payload)
        message.v = message.v or M.VERSION
        message.sender = message.sender or sender
        message.timestamp = message.timestamp or clock()
        local raw = M.encode(message)
        if not raw then return false end
        return transport.send(raw) ~= false
    end

    function service.send_rahvin(message, message_sender, timestamp)
        local payload = M.from_rahvin(message, message_sender or sender, timestamp or clock())
        if not payload then return false end
        return service.send(payload)
    end

    function service.subscribe(fn)
        if type(fn) ~= 'function' then error('RahvinCompatError:ipc.subscriber', 2) end
        subscribers[fn] = true
        return true
    end

    function service.unsubscribe(fn)
        subscribers[fn] = nil
        return true
    end

    function service.poll()
        if closed then return 0 end
        if type(transport.poll) == 'function' then return transport.poll() end
        return 0
    end

    function service.close()
        if closed then return true end
        closed = true
        if type(transport.unsubscribe) == 'function' then transport.unsubscribe(on_raw) end
        if type(transport.close) == 'function' then transport.close() end
        subscribers = {}
        seen = {}
        return true
    end

    return service
end

-- First-party same-machine transport. UDP multicast is confined to this host by TTL 0.
-- Every Ashita instance joins the same group/port and polls it from an Ashita frame event;
-- no daemon, Termux process or external helper is required.
function M.localhost_transport(options)
    options = options or {}
    local ok, socket = pcall(require, 'socket')
    if not ok or type(socket) ~= 'table' or type(socket.udp) ~= 'function' then
        error('RahvinCompatError:ipc.socket', 2)
    end

    local group = options.group or M.DEFAULT_GROUP
    local port = tonumber(options.port) or M.DEFAULT_PORT
    local interface = options.interface or '127.0.0.1'
    local udp = assert(socket.udp())

    pcall(function() udp:setoption('reuseaddr', true) end)
    assert(udp:setsockname('*', port))
    udp:settimeout(0)

    local joined = udp:setoption('ip-add-membership', {multiaddr=group, interface=interface})
    if joined == nil then
        assert(udp:setoption('ip-add-membership', {multiaddr=group, interface='0.0.0.0'}))
    end

    pcall(function() udp:setoption('ip-multicast-ttl', 0) end)
    pcall(function() udp:setoption('ip-multicast-loop', true) end)

    local listeners = {}
    local transport = {}

    function transport.send(raw)
        local sent, err = udp:sendto(raw, group, port)
        return sent ~= nil, err
    end

    function transport.subscribe(fn)
        listeners[fn] = true
        return true
    end

    function transport.unsubscribe(fn)
        listeners[fn] = nil
        return true
    end

    function transport.poll()
        local count = 0
        while true do
            local raw = udp:receivefrom()
            if not raw then break end
            count = count + 1
            local snapshot = {}
            for fn in pairs(listeners) do snapshot[#snapshot + 1] = fn end
            for i=1,#snapshot do snapshot[i](raw) end
        end
        return count
    end

    function transport.close()
        listeners = {}
        pcall(function()
            udp:setoption('ip-drop-membership', {multiaddr=group, interface=interface})
        end)
        udp:close()
        return true
    end

    return transport
end

return M
