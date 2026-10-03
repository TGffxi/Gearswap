local M = {}

local function default_error(err)
    local message = 'RahvinCompatError:scheduler_callback:' .. tostring(err)
    if type(print) == 'function' then print(message) end
end

function M.new(clock, on_error)
    clock = clock or os.clock
    on_error = on_error or default_error
    if type(clock) ~= 'function' then error('RahvinCompatError:scheduler_clock', 2) end

    local queue = {}
    local sequence = 0
    local service = {}

    local function report(err)
        pcall(on_error, err)
    end

    function service.schedule(fn, delay)
        if type(fn) ~= 'function' then error('RahvinCompatError:scheduler_callback', 2) end
        delay = delay or 0
        if type(delay) ~= 'number' or delay < 0 then error('RahvinCompatError:scheduler_delay', 2) end
        sequence = sequence + 1
        local task = {fn=fn, due=clock() + delay, sequence=sequence}
        queue[#queue + 1] = task
        return task
    end

    function service.tick(now)
        now = now or clock()
        table.sort(queue, function(a, b)
            if a.due == b.due then return a.sequence < b.sequence end
            return a.due < b.due
        end)

        local due, pending = {}, {}
        for _, task in ipairs(queue) do
            if task.due <= now then due[#due + 1] = task
            else pending[#pending + 1] = task end
        end
        queue = pending

        for _, task in ipairs(due) do
            local ok, err = pcall(task.fn)
            if not ok then report(err) end
        end
        return #due
    end

    function service.clear()
        local count = #queue
        queue = {}
        return count
    end

    return service
end

local default_service = M.new(os.clock, default_error)
local frame_bound = false

local function ensure_frame_binding()
    if frame_bound then return end
    local root = rawget(_G, 'ashita')
    if not (root and type(root.events) == 'table') then return end
    local events = require('ashita.events')
    events.register('d3d_present', 'rahvings_scheduler_tick', function()
        default_service.tick(os.clock())
    end)
    frame_bound = true
end

function M.schedule(fn, delay)
    ensure_frame_binding()
    return default_service.schedule(fn, delay)
end

function M.tick(now)
    return default_service.tick(now)
end

function M.clear()
    return default_service.clear()
end

return M
