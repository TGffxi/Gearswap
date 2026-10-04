local composition = require('ashita.composition')

local M = {}

local LAC_SLOTS = {
    'Main','Sub','Range','Ammo','Head','Body','Hands','Legs','Feet',
    'Neck','Waist','Back','Ear1','Ear2','Ring1','Ring2',
}

local function count_keys(t)
    local n=0
    for _ in pairs(t) do n=n+1 end
    return n
end

function M.new_shared()
    local s = {
        tasks={},
        native_handlers={},
        command_owner=nil,
        bindings={},
        disabled_slots={},
        active_fonts=0,
        active_ipc=0,
        ipc_subscriptions=0,
        closed_ipc=0,
        generation=0,
        native_commands={},
        chats={},
        saves=0,
        primitive_objects={},
    }

    s.scheduler = {
        schedule=function(fn, delay)
            local task={fn=fn,delay=delay}
            s.tasks[#s.tasks+1]=task
            return task
        end,
        tick=function() return 0 end,
        clear=function()
            local n=#s.tasks
            for i=#s.tasks,1,-1 do s.tasks[i]=nil end
            return n
        end,
    }

    s.events = {
        register=function(event, alias, fn)
            local key=event .. ':' .. alias
            if s.native_handlers[key] ~= nil then
                error('Wave8DuplicateNativeEvent:' .. key)
            end
            s.native_handlers[key]=fn
            return true
        end,
        unregister_all=function()
            local n=count_keys(s.native_handlers)
            for key in pairs(s.native_handlers) do s.native_handlers[key]=nil end
            return n
        end,
    }

    s.fonts = {
        new=function(settings)
            s.active_fonts=s.active_fonts+1
            local destroyed=false
            local font={
                visible=settings.visible,
                locked=settings.locked,
                can_focus=settings.can_focus,
                font_family=settings.font_family,
                font_height=settings.font_height,
                bold=settings.bold,
                italic=settings.italic,
                right_justified=settings.right_justified,
                color=settings.color,
                color_outline=settings.color_outline,
                padding=settings.padding,
                position_x=settings.position_x,
                position_y=settings.position_y,
                text=settings.text,
                background={
                    visible=settings.background and settings.background.visible or false,
                    color=settings.background and settings.background.color or 0,
                    locked=settings.background and settings.background.locked or false,
                    can_focus=settings.background and settings.background.can_focus or false,
                },
            }
            function font:get_text_size() return 100,20 end
            function font:register() return true end
            function font:unregister() return true end
            function font:destroy()
                if not destroyed then
                    destroyed=true
                    s.active_fonts=s.active_fonts-1
                end
                return true
            end
            return font
        end,
    }

    return s
end

local function make_commands(shared, generation)
    local registered=false
    return {
        register=function()
            if registered then return true end
            if shared.command_owner ~= nil then
                error('Wave8DuplicateCommandOwner:' .. tostring(shared.command_owner))
            end
            shared.command_owner=generation
            registered=true
            return true
        end,
        unregister=function()
            if not registered then return true end
            if shared.command_owner ~= generation then
                error('Wave8WrongCommandOwner:' .. tostring(shared.command_owner))
            end
            shared.command_owner=nil
            registered=false
            return true
        end,
    }
end

local function make_ipc(shared, generation)
    shared.active_ipc=shared.active_ipc+1
    local listener
    local closed=false
    return {
        subscribe=function(fn)
            if listener ~= nil then error('Wave8DuplicateIpcSubscription') end
            listener=fn
            shared.ipc_subscriptions=shared.ipc_subscriptions+1
            return true
        end,
        unsubscribe=function(fn)
            if listener == nil then return true end
            if fn ~= listener then error('Wave8WrongIpcListener') end
            listener=nil
            shared.ipc_subscriptions=shared.ipc_subscriptions-1
            return true
        end,
        send_rahvin=function() return true end,
        poll=function() return 0 end,
        close=function()
            if not closed then
                closed=true
                shared.active_ipc=shared.active_ipc-1
                shared.closed_ipc=shared.closed_ipc+1
            end
            return true
        end,
        generation=generation,
    }
end

local function make_native(shared, generation, resources)
    local primitive_seq=0

    local function send_command(command)
        command=tostring(command or '')
        shared.native_commands[#shared.native_commands+1]={generation=generation,command=command}

        local key=command:match('^%s*bind%s+(%S+)')
        if key then
            key=key:lower()
            local owner=shared.bindings[key]
            if owner ~= nil and owner ~= generation then
                error('Wave8StaleKeybind:' .. key .. ':' .. tostring(owner))
            end
            shared.bindings[key]=generation
            return true
        end

        key=command:match('^%s*unbind%s+(%S+)')
        if key then
            shared.bindings[key:lower()]=nil
            return true
        end
        return true
    end

    local prim={}
    function prim.create(name)
        name=tostring(name or '')
        if shared.primitive_objects[name] ~= nil then error('Wave8DuplicatePrimitive:' .. name) end
        primitive_seq=primitive_seq+1
        shared.primitive_objects[name]={generation=generation,sequence=primitive_seq}
        return true
    end
    function prim.delete(name)
        shared.primitive_objects[tostring(name or '')]=nil
        return true
    end
    function prim.set_position() return true end
    function prim.set_size() return true end
    function prim.set_color() return true end
    function prim.set_visibility() return true end

    return {
        resources=resources,
        chat=function(mode,message)
            shared.chats[#shared.chats+1]={generation=generation,mode=mode,message=message}
            return true
        end,
        send_command=send_command,
        input=function(command)
            shared.native_commands[#shared.native_commands+1]={generation=generation,command='input '..tostring(command)}
            return true
        end,
        cancel_buff=function() return true end,
        execute_script=function() return true end,
        window_settings=function() return {ui_x_res=1920,ui_y_res=1080} end,
        wc_match=function(value,pattern)
            if value==nil or pattern==nil then return false end
            local escaped=tostring(pattern):gsub('([^%w])','%%%1'):gsub('%%%*','.*'):gsub('%%%?','.')
            return tostring(value):lower():match('^'..escaped:lower()..'$') ~= nil
        end,
        get_info=function() return {language='english',logged_in=true,zone=1} end,
        get_abilities=function() return {job_traits={}} end,
        get_party=function() return {p0={name='Tester'}} end,
        get_mob_by_id=function() return nil end,
        get_mob_by_index=function() return nil end,
        get_player=function()
            return {id=111,index=22,name='Tester',main_job='WAR',sub_job='SAM'}
        end,
        inject_outgoing=function() return true end,
        schedule=function(fn,delay) return shared.scheduler.schedule(fn,delay) end,
        gettime=function() return 100 end,
        load_config=function(_,defaults) return defaults end,
        save_config=function() shared.saves=shared.saves+1; return true end,
        decode_item=function(item) return item and item.raw or {} end,
        new_file=function(path)
            return {path=path,exists=function() return false end,read=function() return nil end}
        end,
        prim=prim,
    }
end

function M.build(shared, job)
    shared.generation=shared.generation+1
    local generation=shared.generation

    local resources={
        items={},buffs={},job_abilities={},weapon_skills={},spells={},
        elements={},zones={},jobs={},bags={},
    }

    local action, pet_action
    local gData={
        GetAction=function() return action end,
        GetPetAction=function() return pet_action end,
        GetActionTarget=function()
            if action == nil then return nil end
            return {Id=999,Index=77,Name='Target',Type='Monster',Distance=4,HPP=100,TP=0}
        end,
        GetPlayer=function()
            return {Name='Tester',MainJob=job,SubJob='SAM',MainJobLevel=99,SubJobLevel=49}
        end,
    }

    local gFunc={}
    function gFunc.EquipSet() return true end
    function gFunc.Enable(slot) shared.disabled_slots[slot]=nil; return true end
    function gFunc.Disable(slot) shared.disabled_slots[slot]=generation; return true end
    function gFunc.CancelAction() return true end

    local snapshot=function()
        return {
            player={
                name='Tester',id=111,index=22,main_job=job,sub_job='SAM',
                main_job_level=99,sub_job_level=49,status='Idle',
                hp=2000,hpp=100,max_hp=2000,mp=1000,mpp=100,max_mp=1000,tp=0,
                equipment={},inventory={},
            },
            world={day='Firesday',weather='Clear',area='Test'},
            buffactive={},buffs={},pet={isvalid=false},equipment={},inventory={},
        }
    end

    local native=make_native(shared,generation,resources)
    local inventory={iter_bag=function() return {} end}
    local recasts={abilities=function() return {} end,spells=function() return {} end}

    local display={
        hide=function() return true end,
        destroy=function() return true end,
    }
    local keybinds={
        apply=function() return true end,
        clear=function() return true end,
    }

    local commands=make_commands(shared,generation)
    local graph=composition.new({
        inventory=inventory,
        recasts=recasts,
        events=shared.events,
        scheduler=shared.scheduler,
        ipc_factory=function() return make_ipc(shared,generation) end,
        ipc_to_rahvin=function(payload) return payload and payload.message or nil end,
        gData=gData,
        gFunc=gFunc,
        native=native,
        snapshot=snapshot,
        job_path='Sample Job Files/' .. job,
        settings={Keybinds={}},
        fonts=shared.fonts,
        display=display,
        keybinds=keybinds,
        commands=commands,
        release_slots=function()
            for _,slot in ipairs(LAC_SLOTS) do shared.disabled_slots[slot]=nil end
            return true
        end,
        reset_special=function() return true end,
    })

    local fixture={
        generation=generation,
        job=job,
        graph=graph,
        gData=gData,
    }

    function fixture.set_action(value) action=value end
    function fixture.set_pet_action(value) pet_action=value end

    return fixture
end

function M.count(t) return count_keys(t) end

return M
