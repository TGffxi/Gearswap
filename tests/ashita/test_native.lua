local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.native'] = nil
    local native_module = require('ashita.native')
    a.equal(type(native_module.new), 'function', 'production native adapter must expose new(deps)')

    local calls = {}
    local function log(name, ...)
        calls[#calls + 1] = {name=name, args={...}}
    end

    local chat = {
        AddChatMessage=function(_, mode, indent, message)
            log('chat', mode, indent, message)
            return true
        end,
        QueueCommand=function(_, mode, command)
            log('queue', mode, command)
            return true
        end,
        SetInputText=function(_, value)
            log('input_text', value)
            return true
        end,
        ExecuteScript=function(_, file, args, threaded)
            log('script', file, args, threaded)
            return true
        end,
    }

    local entities = {
        [100]={id=1111,name='Tester',x=1,y=2,z=3,distance=0,spawn=2,hpp=100,status=1},
        [101]={id=2222,name='PartyMate',x=4,y=6,z=3,distance=25,spawn=14,hpp=100,status=1},
        [200]={id=3333,name='TargetMob',x=10,y=20,z=30,distance=49,spawn=17,hpp=75,status=1},
    }
    local entity = {
        GetEntityMapSize=function() return 512 end,
        GetServerId=function(_, index) return entities[index] and entities[index].id or 0 end,
        GetName=function(_, index) return entities[index] and entities[index].name or '' end,
        GetLocalPositionX=function(_, index) return entities[index] and entities[index].x or 0 end,
        GetLocalPositionY=function(_, index) return entities[index] and entities[index].y or 0 end,
        GetLocalPositionZ=function(_, index) return entities[index] and entities[index].z or 0 end,
        GetDistance=function(_, index) return entities[index] and entities[index].distance or 0 end,
        GetSpawnFlags=function(_, index) return entities[index] and entities[index].spawn or 0 end,
        GetHPPercent=function(_, index) return entities[index] and entities[index].hpp or 0 end,
        GetStatus=function(_, index) return entities[index] and entities[index].status or 0 end,
    }

    local members = {
        [0]={active=1,id=1111,index=100,name='Tester',zone=55},
        [1]={active=1,id=2222,index=101,name='PartyMate',zone=55},
    }
    local party = {
        GetMemberIsActive=function(_, slot) return members[slot] and members[slot].active or 0 end,
        GetMemberServerId=function(_, slot) return members[slot] and members[slot].id or 0 end,
        GetMemberTargetIndex=function(_, slot) return members[slot] and members[slot].index or 0 end,
        GetMemberName=function(_, slot) return members[slot] and members[slot].name or '' end,
        GetMemberZone=function(_, slot) return members[slot] and members[slot].zone or 0 end,
    }

    local player = {
        GetLoginStatus=function() return 1 end,
        HasTrait=function(_, id) return id == 18 end,
    }

    local memory = {
        GetEntity=function() return entity end,
        GetParty=function() return party end,
        GetPlayer=function() return player end,
    }

    local packet = {
        AddOutgoingPacket=function(_, id, bytes)
            log('packet', id, bytes)
            return true
        end,
    }

    local core = {
        GetChatManager=function() return chat end,
        GetMemoryManager=function() return memory end,
        GetPacketManager=function() return packet end,
    }

    local gData = {
        GetPlayer=function()
            return {
                Name='Tester', MainJob='WAR', MainJobLevel=99, MainJobSync=99,
                SubJob='SAM', SubJobLevel=49, SubJobSync=49,
                Status='Idle', HP=1000, MaxHP=1000, HPP=100,
                MP=100, MaxMP=100, MPP=100, TP=1234,
            }
        end,
    }

    local scheduled = {}
    local scheduler = {
        schedule=function(fn, delay)
            scheduled[#scheduled + 1] = {fn=fn, delay=delay}
            return scheduled[#scheduled]
        end,
    }

    local settings_loads, settings_saves = {}, {}
    local settings_store = {
        load=function(identity, defaults)
            settings_loads[#settings_loads + 1] = {identity=identity, defaults=defaults}
            return {visible=false, marker='loaded'}
        end,
        save=function(identity, value)
            settings_saves[#settings_saves + 1] = {identity=identity, value=value}
            return true
        end,
    }

    local prim_objects = {}
    local primitives = {
        new=function(settings)
            local p = {
                position_x=settings.position_x or 0,
                position_y=settings.position_y or 0,
                width=settings.width or 0,
                height=settings.height or 0,
                color=settings.color or 0,
                visible=settings.visible == true,
                destroyed=false,
            }
            function p:destroy() self.destroyed = true end
            prim_objects[#prim_objects + 1] = p
            return p
        end,
    }

    local resources = {
        items={}, buffs={}, job_abilities={}, weapon_skills={}, spells={},
        elements={}, zones={}, jobs={}, bags={},
    }

    local native = native_module.new({
        core=core,
        gData=gData,
        scheduler=scheduler,
        settings=settings_store,
        resources=resources,
        primitives=primitives,
        viewport=function() return 1920, 1080 end,
        clock=function() return 123.5 end,
        decode_item=function(item) return {decoded=item} end,
    })

    for _, name in ipairs({
        'chat','send_command','input','window_settings','wc_match','get_info',
        'get_abilities','get_party','get_mob_by_id','get_mob_by_index','get_player',
        'inject_outgoing','cancel_buff','execute_script','schedule','gettime',
        'load_config','save_config','decode_item','new_file',
    }) do
        a.equal(type(native[name]), 'function', 'native adapter missing method: ' .. name)
    end
    for _, name in ipairs({'create','delete','set_position','set_size','set_color','set_visibility'}) do
        a.equal(type(native.prim[name]), 'function', 'native primitive adapter missing method: ' .. name)
    end
    a.equal(native.resources, resources, 'native resources must preserve one shared identity')

    native.chat(123, 'hello')
    a.equal(calls[#calls].name, 'chat')
    a.equal(calls[#calls].args[1], 123)
    a.equal(calls[#calls].args[3], 'hello')

    native.send_command('input /echo hello')
    a.equal(calls[#calls].name, 'queue')
    a.equal(calls[#calls].args[1], -1)
    a.equal(calls[#calls].args[2], 'input /echo hello')

    local bridged_commands = {}
    local bridged_native = native_module.new({
        core=core,
        gData=gData,
        scheduler=scheduler,
        settings=settings_store,
        resources=resources,
        primitives=primitives,
        viewport=function() return 1920, 1080 end,
        clock=function() return 123.5 end,
        decode_item=function(item) return {decoded=item} end,
        keybind_command=function(command)
            bridged_commands[#bridged_commands + 1] = command
            return true
        end,
    })
    bridged_native.send_command('bind ~f9 gs c WeaponMode')
    bridged_native.send_command('unbind ~f9')
    a.deep_equal(bridged_commands, {
        'bind ~f9 gs c WeaponMode',
        'unbind ~f9',
    }, 'Rahvin bind/unbind commands must route through the Ashita keybind adapter')
    a.equal(calls[#calls].args[2], 'input /echo hello',
        'bridged bind commands must not also be queued as raw Ashita commands')

    -- Windower chat.input executes the command immediately. It must never merely populate
    -- Ashita's input line via SetInputText.
    native.input('/ma Cure <me>')
    a.equal(calls[#calls].name, 'queue')
    a.equal(calls[#calls].args[1], 1,
        'windower.chat.input must use Ashita typed-command execution mode')
    a.equal(calls[#calls].args[2], '/ma Cure <me>')

    native.execute_script('profiles/WAR_SAM_Tester')
    a.equal(calls[#calls].name, 'script')
    a.deep_equal(calls[#calls].args, {'profiles/WAR_SAM_Tester','',false},
        'Windower exec compatibility must use pinned Ashita ExecuteScript')

    a.deep_equal(native.window_settings(), {ui_x_res=1920, ui_y_res=1080})
    a.equal(native.wc_match('Aftermath: Lv.3', 'Aftermath*'), true)
    a.equal(native.wc_match('Doom', 'D?om'), true)
    a.equal(native.wc_match('Doom', 'Curse*'), false)

    local info = native.get_info()
    a.equal(info.language, 'english')
    a.equal(info.logged_in, true)
    a.equal(info.zone, 55)

    local abilities = native.get_abilities()
    a.equal(type(abilities.job_traits), 'table')
    a.equal(abilities.job_traits[1], 18)

    local p = native.get_party()
    a.equal(p.p0.name, 'Tester')
    a.equal(p.p1.name, 'PartyMate')
    a.equal(p.p1.mob.id, 2222)
    a.equal(p.p1.mob.x, 4)
    a.equal(p.p1.mob.y, 6)
    a.equal(p.p1.mob.z, 3)
    a.equal(p.p1.mob.spawn_type, 13, 'Ashita party spawn flag 14 maps to Windower 13')

    local mob = native.get_mob_by_index(200)
    a.equal(mob.id, 3333)
    a.equal(mob.spawn_type, 16, 'Ashita monster spawn flag 17 maps to Windower 16')
    a.equal(mob.is_npc, true)
    a.equal(type(mob.distance), 'table',
        'Windower mob distance must preserve the :sqrt() surface Rahvin calls')
    a.equal(mob.distance.squared, 49)
    a.equal(mob.distance:sqrt(), 7,
        'Ashita squared entity distance must expose Windower-compatible sqrt yalms')
    local by_id = native.get_mob_by_id(3333)
    a.equal(by_id.index, 200)
    a.equal(by_id.distance:sqrt(), 7,
        'get_mob_by_id and get_mob_by_index must expose the same distance contract')
    a.equal(native.get_mob_by_id(9999), nil)

    local me = native.get_player()
    a.equal(me.name, 'Tester')
    a.equal(me.id, 1111)
    a.equal(me.index, 100)
    a.equal(me.main_job, 'WAR')
    a.equal(me.sub_job, 'SAM')

    native.inject_outgoing(0xF1, string.char(0xF1,0x04,0,0,15,0,0,0))
    a.equal(calls[#calls].name, 'packet')
    a.equal(calls[#calls].args[1], 0xF1)
    a.equal(type(calls[#calls].args[2]), 'table')
    a.equal(calls[#calls].args[2][1], 0xF1)
    a.equal(calls[#calls].args[2][5], 15)

    -- Ashita's pinned debuff addon cancels a status with outgoing packet 0xF1 and the buff
    -- id as little-endian uint16 at bytes 5/6. Reuse that exact primitive for Windower
    -- 'cancel <id>' instead of depending on an optional addon.
    native.cancel_buff(71)
    a.equal(calls[#calls].name, 'packet')
    a.equal(calls[#calls].args[1], 0xF1)
    a.equal(calls[#calls].args[2][1], 0xF1)
    a.equal(calls[#calls].args[2][2], 0x04)
    a.equal(calls[#calls].args[2][5], 71)
    a.equal(calls[#calls].args[2][6], 0)

    local ran = false
    native.schedule(function() ran=true end, 2.5)
    a.equal(#scheduled, 1)
    a.equal(scheduled[1].delay, 2.5)
    a.equal(ran, false)
    a.equal(native.gettime(), 123.5)

    local loaded = native.load_config('data/Tester/settings.xml', {visible=true})
    a.equal(loaded.marker, 'loaded')
    a.equal(settings_loads[1].identity.name, 'Tester')
    a.equal(settings_loads[1].identity.id, 1111)
    a.equal(native.save_config({visible=false}), true)
    a.equal(settings_saves[1].identity.name, 'Tester')
    a.equal(settings_saves[1].identity.id, 1111)
    a.equal(settings_saves[1].value.visible, false)

    local pseudo = native.new_file('data/Tester/settings.xml')
    a.equal(pseudo:exists(), false,
        'Rahvin XML probe remains virtual so Ashita Lua settings bypass XML parsing/migration')
    a.equal(pseudo:read(), nil)

    local raw = {Extra='x'}
    a.deep_equal(native.decode_item(raw), {decoded=raw})

    native.prim.create('panel')
    a.equal(#prim_objects, 1)
    native.prim.set_position('panel', 10, 20)
    native.prim.set_size('panel', 100, 40)
    native.prim.set_color('panel', 200, 1, 2, 3)
    native.prim.set_visibility('panel', true)
    a.equal(prim_objects[1].position_x, 10)
    a.equal(prim_objects[1].position_y, 20)
    a.equal(prim_objects[1].width, 100)
    a.equal(prim_objects[1].height, 40)
    a.equal(prim_objects[1].visible, true)
    native.prim.delete('panel')
    a.equal(prim_objects[1].destroyed, true)

    a.raises(function() native.prim.set_visibility('missing', true) end,
        'RahvinCompatError:native.prim.missing',
        'missing primitive names must fail loudly')

    -- Production builder: resolve the normal Ashita/LAC runtime instead of requiring a
    -- hand-assembled dependency table from each LuAshitacast profile.
    a.equal(type(native_module.production), 'function',
        'native.production must expose the real Ashita/LAC dependency builder')

    local previous_core = rawget(_G, 'AshitaCore')
    local previous_gdata = rawget(_G, 'gData')
    local module_names = {'ashita.settings','ashita.resources','ashita.extdata','ashita.keybinds','primitives','d3d8','socket'}
    local previous_loaded, previous_preload = {}, {}
    for _, name in ipairs(module_names) do
        previous_loaded[name] = package.loaded[name]
        previous_preload[name] = package.preload[name]
        package.loaded[name] = nil
    end

    local production_resources = {
        items={}, buffs={}, job_abilities={}, weapon_skills={}, spells={},
        elements={}, zones={}, jobs={}, bags={},
    }
    local resource_builds = 0
    local production_settings = {
        load=function(who, defaults)
            return {marker='production', who=who, defaults=defaults}
        end,
        save=function() return true end,
    }
    local production_primitives = {
        new=function(settings)
            local p = {
                position_x=settings.position_x or 0, position_y=settings.position_y or 0,
                width=settings.width or 0, height=settings.height or 0,
                color=settings.color or 0, visible=settings.visible == true,
            }
            function p:destroy() return true end
            return p
        end,
    }
    local viewport_device = {
        GetViewport=function()
            return 0, {Width=2560, Height=1440}
        end,
    }

    package.preload['ashita.settings'] = function() return production_settings end
    package.preload['ashita.resources'] = function()
        return {
            production=function(received_core)
                a.equal(received_core, core, 'resource builder must receive the active AshitaCore')
                resource_builds = resource_builds + 1
                return production_resources
            end,
        }
    end
    package.preload['ashita.extdata'] = function()
        return {decode=function(item) return {production_decoded=item} end}
    end
    package.preload['primitives'] = function() return production_primitives end
    package.preload['d3d8'] = function()
        return {get_device=function() return viewport_device end}
    end
    package.preload['socket'] = function()
        return {gettime=function() return 987.25 end}
    end

    rawset(_G, 'AshitaCore', core)
    rawset(_G, 'gData', gData)

    local production_keybind_commands = {}
    package.loaded['ashita.keybinds'] = {
        bridge=function(command)
            production_keybind_commands[#production_keybind_commands + 1] = command
            return true
        end,
    }
    local production_native = native_module.production({scheduler=scheduler})
    production_native.send_command('bind ^f12 gs c OffenseMode')
    a.deep_equal(production_keybind_commands, {'bind ^f12 gs c OffenseMode'},
        'production native builder must route Rahvin keybind ownership through ashita.keybinds')
    a.equal(resource_builds, 1, 'production native builder must build Ashita resources once')
    a.equal(production_native.resources, production_resources,
        'production native adapter must expose the production resource identity')
    a.deep_equal(production_native.window_settings(), {ui_x_res=2560, ui_y_res=1440},
        'production viewport must come from Ashita d3d8')
    a.equal(production_native.gettime(), 987.25,
        'production wall clock must use LuaSocket gettime')
    a.deep_equal(production_native.decode_item(raw), {production_decoded=raw},
        'production extdata decode must route through the Ashita extdata adapter')
    local production_loaded = production_native.load_config(
        'data/Tester/settings.xml', {visible=true})
    a.equal(production_loaded.marker, 'production',
        'production settings must route through ashita.settings')

    rawset(_G, 'AshitaCore', previous_core)
    rawset(_G, 'gData', previous_gdata)
    for _, name in ipairs(module_names) do
        package.loaded[name] = previous_loaded[name]
        package.preload[name] = previous_preload[name]
    end
end
