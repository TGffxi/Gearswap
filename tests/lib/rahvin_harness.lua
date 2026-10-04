local environment = require('compat.environment')
local gearswap = require('compat.gearswap')
local windower = require('compat.windower')
local set_utils = require('compat.sets')

local M = {}
local methods = {}
methods.__index = methods

local function text_box(cfg)
    cfg.text.fonts = cfg.text.fonts or {}
    cfg.flags.italic = cfg.flags.italic or false
    cfg.flags.right = cfg.flags.right or false
    cfg.flags.bottom = cfg.flags.bottom or false
    local box={_x=cfg.pos and cfg.pos.x or 0,_y=cfg.pos and cfg.pos.y or 0}
    return setmetatable(box,{__index=function(_, key)
        if key=='pos' then
            return function(self,x,y)
                if x then self._x,self._y=x,y else return self._x,self._y end
            end
        end
        if key=='extents' then return function() return 100,20 end end
        return function() end
    end})
end

local function make_platform(opts)
    opts = opts or {}
    local events, scheduled, chat_lines, saves = {}, {}, {}, {}
    local platform = {
        resources={elements={}, items={}, buffs={}, job_abilities={}, weapon_skills={}, spells={}, zones={}, bags={}, jobs={}},
        chat=function(_, mode, message)
            chat_lines[#chat_lines+1]={mode=mode,message=message}
            if type(opts.on_chat)=='function' then opts.on_chat(mode,message) end
        end,
        send_command=function() end,
        send_ipc=function() end,
        input=function() end,
        register_event=function(_, name, fn)
            events[#events+1]={name=name,fn=fn,mode='wrapped'}
            return #events
        end,
        raw_register_event=function(_, name, fn)
            events[#events+1]={name=name,fn=fn,mode='raw'}
            return #events
        end,
        schedule=function(_, fn, delay) scheduled[#scheduled+1]={fn=fn,delay=delay} end,
        get_info=function() return {language='english', logged_in=true} end,
        get_items=function() return {max=0} end,
        get_abilities=function() return {job_traits={}} end,
        get_ability_recasts=function() return {} end,
        get_spell_recasts=function() return {} end,
        get_mob_by_id=function() end,
        get_mob_by_index=function() end,
        get_party=function() return {party1_count=1} end,
        get_player=function() return {id=1,index=1,name='Tester'} end,
        window_settings=function() return {ui_x_res=1920,ui_y_res=1080} end,
        inject_outgoing=function() end,
        load_config=function(_,path,defaults)
            for key, value in pairs(opts.settings or {}) do defaults[key] = value end
            if type(opts.load_config)=='function' then
                return opts.load_config(path, defaults)
            end
            return defaults
        end,
        save_config=function(_,value)
            saves[#saves+1]=set_utils.copy(value)
            if type(opts.save_config)=='function' then return opts.save_config(value) end
            return true
        end,
        decode_item=function() return {} end,
        new_file=function(_, path)
            return {path=path, exists=function() return false end, read=function() return nil end}
        end,
    }
    for _, op in ipairs({'create','delete','set_position','set_size','set_color','set_visibility'}) do
        platform['prim_'..op]=function() end
    end
    platform._events=events
    platform._scheduled=scheduled
    platform._chat=chat_lines
    platform._saves=saves
    return platform
end

function M.new(opts)
    opts=opts or {}
    local platform=make_platform(opts)
    local env=environment.new(platform)
    env.player={
        name='Tester', main_job=opts.job or 'WAR', sub_job=opts.sub_job or 'SAM',
        id=1, index=1, status=opts.status or 'Idle', tp=3000,
        hp=1000, max_hp=1000, hpp=100, mp=500, max_mp=500, mpp=100,
        equipment={main='empty',sub='empty',range='empty',ammo='empty'}, inventory={},
    }
    env.world={
        day='Firesday', day_element='Fire', weather='Clear', weather_element='None',
        area='Test', time=1200,
    }
    env.buffactive={}
    env.pet={isvalid=false}
    env.texts={new=function(_, cfg) return text_box(cfg) end}

    local equipped={}
    local backend={
        equip=function(_, set) equipped[#equipped+1]=set_utils.copy(set) end,
        enable=function() end,
        disable=function() end,
        cancel_action=function() env._global=env._global or {}; env._global.cancel_spell=true end,
    }
    gearswap.install(env, backend)
    env.windower=windower.new(platform)
    environment.install_runtime(env, platform)
    env.include('RahvinGS/Rahvin-Engine')

    return setmetatable({env=env, platform=platform, equipped=equipped}, methods)
end

function methods:event(name, occurrence)
    occurrence = occurrence or 1
    local seen = 0
    for _, entry in ipairs(self.platform._events) do
        if entry.name == name then
            seen = seen + 1
            if seen == occurrence then return entry.fn end
        end
    end
    return nil
end

function methods:set_offense(options, value)
    local mode=self.env.state.OffenseMode
    mode:options(unpack(options))
    mode:set(value)
end

function methods:set_weapon_mode(options, value)
    local mode=self.env.state.WeaponMode
    mode:options(unpack(options))
    mode:set(value)
end

function methods:choose()
    return self.env.choose_set()
end

function methods:precast(spell)
    return self.env.precastequip(spell)
end

function methods:midcast(spell)
    return self.env.midcastequip(spell)
end

function methods:aftercast(spell)
    return self.env.aftercastequip(spell)
end

return M
