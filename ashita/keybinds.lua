local M = {}

-- Rahvin keeps keys in Windower spelling.  Ashita uses the same Ctrl (^) and Alt (!)
-- prefixes, but Shift is '+' rather than '~'.  Keep the persisted spelling on the Rahvin
-- side and translate only at the command boundary.
local ACTIONS = {
    { word = 'offensemode',    command = 'OffenseMode' },
    { word = 'weaponmode',     command = 'WeaponMode' },
    { word = 'weaponlock',     command = 'WeaponLock' },
    { word = 'treasurehunter', command = 'TreasureHunter' },
    { word = 'jobmode',        command = 'JobMode' },
    { word = 'jobmode2',       command = 'JobMode2' },
    { word = 'hoxne',          command = 'Hoxne' },
    { word = 'spellreceived',  command = 'SpellReceived' },
}

local ACTION_BY_WORD = {}
for _, row in ipairs(ACTIONS) do ACTION_BY_WORD[row.word] = row end

local function valid_key(value)
    if value == '' then return true end
    if type(value) ~= 'string' then return false end
    local prefix, number = value:match('^([%^!~]?)f(%d+)$')
    local n = tonumber(number)
    return prefix ~= nil and n ~= nil and n >= 1 and n <= 12 and number == tostring(n)
end

local function ashita_key(value)
    if value == '' then return '' end
    local prefix, number = value:match('^([%^!~]?)f(%d+)$')
    if prefix == '~' then prefix = '+' end
    return prefix .. 'F' .. number
end

local function bind_command(row, key)
    return '/bind ' .. ashita_key(key) .. ' /lac fwd ' .. row.command
end

local function unbind_command(key)
    return '/unbind ' .. ashita_key(key)
end

local function production_execute(command)
    local core = rawget(_G, 'AshitaCore')
    if core == nil or type(core.GetChatManager) ~= 'function' then
        error('RahvinCompatError:keybinds.chat_manager_unavailable', 3)
    end
    local chat = core:GetChatManager()
    if chat == nil or type(chat.QueueCommand) ~= 'function' then
        error('RahvinCompatError:keybinds.queue_command_unavailable', 3)
    end
    chat:QueueCommand(1, command)
    return true
end

local bridged_held = {}

local function bridge_run(execute, command)
    local ok, result = pcall(execute, command)
    if not ok then
        error('RahvinCompatError:keybinds.bridge.execute:' .. tostring(result), 3)
    end
    if result == false then
        error('RahvinCompatError:keybinds.bridge.execute:' .. command, 3)
    end
    return true
end

function M.bridge(command, execute)
    if type(command) ~= 'string' then
        error('RahvinCompatError:keybinds.bridge.command', 2)
    end
    execute = execute or production_execute
    if type(execute) ~= 'function' then
        error('RahvinCompatError:keybinds.bridge.executor', 2)
    end

    local key, forwarded = command:match('^%s*bind%s+(%S+)%s+gs%s+c%s+(.+)%s*$')
    if key then
        key = key:lower()
        if not valid_key(key) or key == '' then
            error('RahvinCompatError:keybinds.bridge.key:' .. tostring(key), 2)
        end
        local translated = ashita_key(key)
        bridge_run(execute, '/bind ' .. translated .. ' /lac fwd ' .. forwarded)
        bridged_held[translated] = true
        return true
    end

    key = command:match('^%s*unbind%s+(%S+)%s*$')
    if key then
        key = key:lower()
        if not valid_key(key) or key == '' then
            error('RahvinCompatError:keybinds.bridge.key:' .. tostring(key), 2)
        end
        local translated = ashita_key(key)
        bridge_run(execute, '/unbind ' .. translated)
        bridged_held[translated] = nil
        return true
    end

    error('RahvinCompatError:keybinds.bridge.command:' .. command, 2)
end

function M.clear_bridged(execute)
    execute = execute or production_execute
    if type(execute) ~= 'function' then
        error('RahvinCompatError:keybinds.bridge.executor', 2)
    end

    local keys = {}
    for key in pairs(bridged_held) do keys[#keys + 1] = key end
    table.sort(keys)

    for _, key in ipairs(keys) do
        bridge_run(execute, '/unbind ' .. key)
        bridged_held[key] = nil
    end
    return true
end

function M.new(execute)
    if type(execute) ~= 'function' then
        error('RahvinCompatError:keybinds.executor', 2)
    end

    -- held contains only binds this adapter created.  Never infer ownership from Ashita's
    -- global bind table: teardown must not disturb a user's unrelated binds.
    local held = {}
    local settings_ref
    local service = {}

    local function run(command)
        local ok, result = pcall(execute, command)
        if not ok then
            error('RahvinCompatError:keybinds.execute:' .. tostring(result), 3)
        end
        if result == false then
            error('RahvinCompatError:keybinds.execute:' .. command, 3)
        end
        return true
    end

    function service.apply(settings)
        if type(settings) ~= 'table' then
            error('RahvinCompatError:keybinds.settings', 2)
        end
        local keys = settings.Keybinds
        if type(keys) ~= 'table' then
            error('RahvinCompatError:keybinds.settings.Keybinds', 2)
        end

        -- Resolve ownership first, in Rahvin's key-list order.  The first action naming a
        -- key owns it for this session; later collisions are deliberately left unbound.
        local desired, taken = {}, {}
        for _, row in ipairs(ACTIONS) do
            local key = keys[row.word]
            if key == nil then key = '' end
            if not valid_key(key) then key = '' end
            if key ~= '' then
                if taken[key] then
                    key = ''
                else
                    taken[key] = row.word
                end
            end
            desired[row.word] = key
        end

        -- Release every stale binding before creating replacements.  This preserves swaps
        -- and mirrors Rahvin's own three-pass keybind_apply ordering.
        for _, row in ipairs(ACTIONS) do
            local old = held[row.word]
            if old and old ~= desired[row.word] then
                run(unbind_command(old))
                held[row.word] = nil
            end
        end

        for _, row in ipairs(ACTIONS) do
            local key = desired[row.word]
            if key ~= '' and held[row.word] ~= key then
                run(bind_command(row, key))
                held[row.word] = key
            end
        end

        settings_ref = settings
        return true
    end

    function service.clear()
        for _, row in ipairs(ACTIONS) do
            local key = held[row.word]
            if key then
                run(unbind_command(key))
                held[row.word] = nil
            end
        end
        return true
    end

    function service.rebind(action, key)
        local row = ACTION_BY_WORD[action]
        if not row or not valid_key(key) then return false end
        if type(settings_ref) ~= 'table' or type(settings_ref.Keybinds) ~= 'table' then
            return false
        end

        if key ~= '' then
            for _, other in ipairs(ACTIONS) do
                if other.word ~= action and held[other.word] == key then
                    return false, 'collision'
                end
            end
        end

        local old = held[action]
        if old == key then
            settings_ref.Keybinds[action] = key
            return true, key
        end

        if old then
            run(unbind_command(old))
            held[action] = nil
        end
        if key ~= '' then
            run(bind_command(row, key))
            held[action] = key
        end

        settings_ref.Keybinds[action] = key
        return true, key
    end

    return service
end

local default_service

function M.configure(execute)
    if default_service then default_service.clear() end
    default_service = M.new(execute or production_execute)
    return default_service
end

local function service()
    if not default_service then default_service = M.new(production_execute) end
    return default_service
end

function M.apply(settings)
    return service().apply(settings)
end

function M.clear()
    if not default_service then return true end
    return default_service.clear()
end

function M.rebind(action, key)
    return service().rebind(action, key)
end

return M
