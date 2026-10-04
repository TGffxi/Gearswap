local M = {}

local function need(value, label)
    if value == nil then error('RahvinCompatError:native.' .. label, 3) end
    return value
end

local function method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:native.' .. (label or name), 3)
    end
    return fn
end

local function clamp_byte(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return math.floor(value)
end

local function argb(alpha, red, green, blue)
    return clamp_byte(alpha) * 0x1000000
        + clamp_byte(red) * 0x10000
        + clamp_byte(green) * 0x100
        + clamp_byte(blue)
end

local function wildcard_pattern(value)
    value = tostring(value or '')
    value = value:gsub('([%^%$%(%)%%%.%[%]%+%-])', '%%%1')
    value = value:gsub('%*', '.*')
    value = value:gsub('%?', '.')
    return '^' .. value .. '$'
end

local distance_mt = {}
distance_mt.__index = distance_mt

function distance_mt:sqrt()
    return math.sqrt(self.squared)
end

function distance_mt:__tostring()
    return tostring(self.squared)
end

local function windower_distance(value)
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    return setmetatable({squared=value}, distance_mt)
end

local function bytes_from_string(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' then
        error('RahvinCompatError:native.packet_data', 3)
    end
    local out = {}
    for i = 1, #value do out[i] = value:byte(i) end
    return out
end

function M.new(deps)
    deps = deps or {}

    local core = need(deps.core, 'core')
    local gData = need(deps.gData, 'gData')
    local scheduler = need(deps.scheduler, 'scheduler')
    local settings = need(deps.settings, 'settings')
    local resources = need(deps.resources, 'resources')
    local primitives = need(deps.primitives, 'primitives')
    local viewport = need(deps.viewport, 'viewport')
    local clock = need(deps.clock, 'clock')
    local decode_item = need(deps.decode_item, 'decode_item')

    local get_chat_manager = method(core, 'GetChatManager', 'core.GetChatManager')
    local get_memory_manager = method(core, 'GetMemoryManager', 'core.GetMemoryManager')
    local get_packet_manager = method(core, 'GetPacketManager', 'core.GetPacketManager')
    local schedule = method(scheduler, 'schedule', 'scheduler.schedule')
    local settings_load = method(settings, 'load', 'settings.load')
    local settings_save = method(settings, 'save', 'settings.save')
    local primitive_new = method(primitives, 'new', 'primitives.new')

    local primitive_objects = {}
    local native = {resources=resources, prim={}}

    local function managers()
        local memory = get_memory_manager(core)
        if memory == nil then error('RahvinCompatError:native.memory', 3) end
        local entity = method(memory, 'GetEntity', 'memory.GetEntity')(memory)
        local party = method(memory, 'GetParty', 'memory.GetParty')(memory)
        local player = method(memory, 'GetPlayer', 'memory.GetPlayer')(memory)
        if entity == nil or party == nil or player == nil then
            error('RahvinCompatError:native.memory', 3)
        end
        return memory, entity, party, player
    end

    local function identity()
        local _, _, party = managers()
        local current = method(gData, 'GetPlayer', 'gData.GetPlayer')()
        current = type(current) == 'table' and current or {}
        local name = current.Name or current.name
            or method(party, 'GetMemberName', 'party.GetMemberName')(party, 0)
        local id = method(party, 'GetMemberServerId', 'party.GetMemberServerId')(party, 0)
        if name == nil or tostring(name) == '' or tonumber(id) == nil or tonumber(id) == 0 then
            error('RahvinCompatError:native.identity', 3)
        end
        return {name=tostring(name), id=tonumber(id)}
    end

    local function mob_by_index(index)
        index = tonumber(index)
        if index == nil or index <= 0 then return nil end

        local _, entity = managers()
        local get_id = method(entity, 'GetServerId', 'entity.GetServerId')
        local id = tonumber(get_id(entity, index)) or 0
        if id == 0 then return nil end

        local spawn = tonumber(method(entity, 'GetSpawnFlags', 'entity.GetSpawnFlags')(entity, index)) or 0
        local distance = windower_distance(
            method(entity, 'GetDistance', 'entity.GetDistance')(entity, index))

        return {
            id=id,
            index=index,
            name=method(entity, 'GetName', 'entity.GetName')(entity, index),
            x=tonumber(method(entity, 'GetLocalPositionX', 'entity.GetLocalPositionX')(entity, index)) or 0,
            y=tonumber(method(entity, 'GetLocalPositionY', 'entity.GetLocalPositionY')(entity, index)) or 0,
            z=tonumber(method(entity, 'GetLocalPositionZ', 'entity.GetLocalPositionZ')(entity, index)) or 0,
            distance=distance,
            spawn_type=spawn > 0 and (spawn - 1) or 0,
            is_npc=(spawn == 3 or spawn == 17),
            hpp=tonumber(method(entity, 'GetHPPercent', 'entity.GetHPPercent')(entity, index)) or 0,
            status=tonumber(method(entity, 'GetStatus', 'entity.GetStatus')(entity, index)) or 0,
        }
    end

    function native.chat(mode, message)
        local chat = get_chat_manager(core)
        if chat == nil then error('RahvinCompatError:native.chat_manager', 2) end
        local write = chat.AddChatMessage or chat.Write
        if type(write) ~= 'function' then error('RahvinCompatError:native.chat_write', 2) end
        write(chat, tonumber(mode) or 0, false, tostring(message or ''))
        return true
    end

    function native.send_command(command)
        command = tostring(command or '')
        if command:match('^%s*bind%s+') or command:match('^%s*unbind%s+') then
            local bridge = deps.keybind_command
            if type(bridge) ~= 'function' then
                error('RahvinCompatError:native.keybind_bridge', 2)
            end
            local ok, result = pcall(bridge, command)
            if not ok then error(result, 2) end
            if result == false then
                error('RahvinCompatError:native.keybind_bridge:' .. command, 2)
            end
            return true
        end

        local chat = get_chat_manager(core)
        if chat == nil then error('RahvinCompatError:native.chat_manager', 2) end
        method(chat, 'QueueCommand', 'chat.QueueCommand')(chat, -1, command)
        return true
    end

    function native.input(value)
        local chat = get_chat_manager(core)
        if chat == nil then error('RahvinCompatError:native.chat_manager', 2) end
        method(chat, 'SetInputText', 'chat.SetInputText')(chat, tostring(value or ''))
        return true
    end

    function native.window_settings()
        local width, height = viewport()
        width, height = tonumber(width), tonumber(height)
        if width == nil or height == nil then
            error('RahvinCompatError:native.viewport', 2)
        end
        return {ui_x_res=width, ui_y_res=height}
    end

    function native.wc_match(value, pattern)
        if value == nil or pattern == nil then return false end
        return tostring(value):lower():match(wildcard_pattern(tostring(pattern):lower())) ~= nil
    end

    function native.get_info()
        local _, _, party, player = managers()
        local login = tonumber(method(player, 'GetLoginStatus', 'player.GetLoginStatus')(player)) or 0
        local zone = tonumber(method(party, 'GetMemberZone', 'party.GetMemberZone')(party, 0)) or 0
        return {
            language=tostring(deps.language or 'english'):lower(),
            logged_in=login == 1,
            zone=zone,
        }
    end

    function native.get_abilities()
        local _, _, _, player = managers()
        local has_trait = method(player, 'HasTrait', 'player.HasTrait')
        local traits = {}
        for id = 0, 255 do
            if has_trait(player, id) == true then traits[#traits + 1] = id end
        end
        return {job_traits=traits}
    end

    function native.get_party()
        local _, _, party = managers()
        local result = {}
        local active = method(party, 'GetMemberIsActive', 'party.GetMemberIsActive')
        local member_name = method(party, 'GetMemberName', 'party.GetMemberName')
        local member_id = method(party, 'GetMemberServerId', 'party.GetMemberServerId')
        local member_index = method(party, 'GetMemberTargetIndex', 'party.GetMemberTargetIndex')

        local function key(slot)
            if slot < 6 then return 'p' .. tostring(slot) end
            if slot < 12 then return 'a1' .. tostring(slot - 6) end
            return 'a2' .. tostring(slot - 12)
        end

        for slot = 0, 17 do
            if tonumber(active(party, slot)) == 1 then
                local index = tonumber(member_index(party, slot)) or 0
                local row = {
                    id=tonumber(member_id(party, slot)) or 0,
                    index=index,
                    name=member_name(party, slot),
                    mob=mob_by_index(index),
                }
                result[key(slot)] = row
            end
        end
        return result
    end

    function native.get_mob_by_index(index)
        return mob_by_index(index)
    end

    function native.get_mob_by_id(server_id)
        server_id = tonumber(server_id)
        if server_id == nil or server_id == 0 then return nil end
        local _, entity = managers()
        local map_size = tonumber(method(entity, 'GetEntityMapSize', 'entity.GetEntityMapSize')(entity)) or 0
        local get_id = method(entity, 'GetServerId', 'entity.GetServerId')
        for index = 0, map_size - 1 do
            if tonumber(get_id(entity, index)) == server_id then
                return mob_by_index(index)
            end
        end
        return nil
    end

    function native.get_player()
        local _, _, party = managers()
        local current = method(gData, 'GetPlayer', 'gData.GetPlayer')()
        if type(current) ~= 'table' then return nil end
        local index = tonumber(method(party, 'GetMemberTargetIndex', 'party.GetMemberTargetIndex')(party, 0)) or 0
        local id = tonumber(method(party, 'GetMemberServerId', 'party.GetMemberServerId')(party, 0)) or 0
        return {
            id=id,
            index=index,
            name=current.Name or current.name,
            main_job=current.MainJob or current.main_job,
            main_job_level=current.MainJobLevel or current.main_job_level,
            main_job_sync=current.MainJobSync or current.main_job_sync,
            sub_job=current.SubJob or current.sub_job,
            sub_job_level=current.SubJobLevel or current.sub_job_level,
            sub_job_sync=current.SubJobSync or current.sub_job_sync,
            status=current.Status or current.status,
            hp=current.HP or current.hp,
            max_hp=current.MaxHP or current.max_hp,
            hpp=current.HPP or current.hpp,
            mp=current.MP or current.mp,
            max_mp=current.MaxMP or current.max_mp,
            mpp=current.MPP or current.mpp,
            tp=current.TP or current.tp,
            is_moving=current.IsMoving == true or current.is_moving == true,
        }
    end

    function native.inject_outgoing(id, data)
        local packet = get_packet_manager(core)
        if packet == nil then error('RahvinCompatError:native.packet_manager', 2) end
        method(packet, 'AddOutgoingPacket', 'packet.AddOutgoingPacket')(
            packet, tonumber(id) or 0, bytes_from_string(data))
        return true
    end

    function native.schedule(fn, delay)
        return schedule(fn, delay)
    end

    function native.gettime()
        return clock()
    end

    function native.load_config(path, defaults)
        local who = identity()
        local named = type(path) == 'string' and path:match('^data[\\/]([^\\/]+)[\\/]settings%.xml$')
        if named and named ~= '' then who.name = named end
        return settings_load(who, defaults)
    end

    function native.save_config(value)
        return settings_save(identity(), value)
    end

    function native.decode_item(item)
        return decode_item(item)
    end

    function native.new_file(_)
        return {
            exists=function() return false end,
            read=function() return nil end,
        }
    end

    function native.prim.create(name)
        name = tostring(name or '')
        if name == '' then error('RahvinCompatError:native.prim.name', 2) end
        if primitive_objects[name] ~= nil then
            error('RahvinCompatError:native.prim.duplicate:' .. name, 2)
        end
        local object = primitive_new({
            visible=false,
            position_x=0,
            position_y=0,
            width=0,
            height=0,
            color=0xFFFFFFFF,
            locked=true,
            can_focus=false,
        })
        if object == nil then error('RahvinCompatError:native.prim.create:' .. name, 2) end
        primitive_objects[name] = object
        return true
    end

    local function primitive(name)
        local object = primitive_objects[tostring(name or '')]
        if object == nil then error('RahvinCompatError:native.prim.missing:' .. tostring(name), 3) end
        return object
    end

    function native.prim.delete(name)
        local object = primitive(name)
        local destroy = method(object, 'destroy', 'prim.destroy')
        destroy(object)
        primitive_objects[tostring(name)] = nil
        return true
    end

    function native.prim.set_position(name, x, y)
        local object = primitive(name)
        object.position_x = tonumber(x) or 0
        object.position_y = tonumber(y) or 0
        return true
    end

    function native.prim.set_size(name, width, height)
        local object = primitive(name)
        object.width = tonumber(width) or 0
        object.height = tonumber(height) or 0
        return true
    end

    function native.prim.set_color(name, alpha, red, green, blue)
        primitive(name).color = argb(alpha, red, green, blue)
        return true
    end

    function native.prim.set_visibility(name, visible)
        primitive(name).visible = visible == true
        return true
    end

    return native
end

local function load_module(name, label)
    local ok, value = pcall(require, name)
    if not ok then
        error('RahvinCompatError:native.' .. label .. ':' .. tostring(value), 3)
    end
    return value
end

function M.production(deps)
    deps = deps or {}

    local core = deps.core or rawget(_G, 'AshitaCore')
    if core == nil then error('RahvinCompatError:native.core', 2) end

    local gData = deps.gData or rawget(_G, 'gData')
    if type(gData) ~= 'table' then error('RahvinCompatError:native.gData', 2) end

    local scheduler = need(deps.scheduler, 'scheduler')

    local settings = deps.settings
    if settings == nil then settings = load_module('ashita.settings', 'settings_module') end

    local resources = deps.resources
    if resources == nil then
        local resources_module = load_module('ashita.resources', 'resources_module')
        local production = method(resources_module, 'production', 'resources.production')
        resources = production(core)
    end

    local primitives = deps.primitives
    if primitives == nil then primitives = load_module('primitives', 'primitives_module') end

    local d3d8 = deps.d3d8
    if d3d8 == nil then d3d8 = load_module('d3d8', 'd3d8_module') end

    local socket = deps.socket
    if socket == nil then socket = load_module('socket', 'socket_module') end

    local get_device = method(d3d8, 'get_device', 'd3d8.get_device')
    local gettime = method(socket, 'gettime', 'socket.gettime')

    local extdata = deps.extdata
    if extdata == nil then
        local extdata_module = load_module('ashita.extdata', 'extdata_module')
        if type(extdata_module.decode) == 'function' then
            extdata = extdata_module
        else
            local production = method(extdata_module, 'production', 'extdata.production')
            extdata = production({
                core=core,
                gData=gData,
                clock=function() return gettime() end,
            })
        end
    end

    local keybind_command = deps.keybind_command
    if keybind_command == nil then
        local keybinds = load_module('ashita.keybinds', 'keybinds_module')
        keybind_command = method(keybinds, 'bridge', 'keybinds.bridge')
    end

    local decode = method(extdata, 'decode', 'extdata.decode')

    local function viewport()
        local device = get_device()
        if device == nil then error('RahvinCompatError:native.viewport_device', 3) end
        local get_viewport = method(device, 'GetViewport', 'd3d8.GetViewport')
        local result, value = get_viewport(device)
        if tonumber(result) ~= 0 or value == nil then
            error('RahvinCompatError:native.viewport', 3)
        end
        local width = tonumber(value.Width or value.width)
        local height = tonumber(value.Height or value.height)
        if width == nil or height == nil then
            error('RahvinCompatError:native.viewport', 3)
        end
        return width, height
    end

    return M.new({
        core=core,
        gData=gData,
        scheduler=scheduler,
        settings=settings,
        resources=resources,
        primitives=primitives,
        viewport=viewport,
        clock=function() return gettime() end,
        decode_item=function(item) return decode(item) end,
        keybind_command=keybind_command,
        language=deps.language,
    })
end

return M
