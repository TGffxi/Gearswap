local a = require('tests.lib.assertions')
return function()
    local environment = require('compat.environment')
    local gearswap = require('compat.gearswap')
    local windower = require('compat.windower')
    local events, scheduled = {}, {}
    local platform = {
        resources={elements={}, items={}, buffs={}, job_abilities={}, weapon_skills={}, spells={}, zones={}, bags={}, jobs={}},
        chat=function() end, send_command=function() end, send_ipc=function() end, input=function() end,
        register_event=function(_, name, fn) events[#events+1]={name=name,fn=fn}; return #events end,
        schedule=function(_, fn, delay) scheduled[#scheduled+1]={fn=fn,delay=delay} end,
        get_info=function() return {language='english', logged_in=true} end,
        get_items=function() return {max=0} end, get_abilities=function() return {job_traits={}} end,
        get_ability_recasts=function() return {} end, get_mob_by_id=function() end, get_mob_by_index=function() end,
        get_player=function() return {id=1,index=1} end, window_settings=function() return {ui_x_res=1920,ui_y_res=1080} end,
        inject_outgoing=function() end, load_config=function(_,_,defaults) return defaults end, save_config=function() end,
        decode_item=function() return {} end,
        new_file=function(_, path) return {path=path, exists=function() return false end, read=function() return nil end} end,
    }
    for _, op in ipairs({'create','delete','set_position','set_size','set_color','set_visibility'}) do platform['prim_'..op]=function() end end
    local env = environment.new(platform)
    env.player={name='Tester', main_job='WAR', sub_job='SAM', id=1, index=1, status='Idle', equipment={}}
    env.world={day='Firesday', weather='Clear', area='Test'}; env.buffactive={}; env.pet=nil
    env.texts={new=function(_, cfg)
        cfg.text.fonts = cfg.text.fonts or {}
        cfg.flags.italic = cfg.flags.italic or false; cfg.flags.right = cfg.flags.right or false; cfg.flags.bottom = cfg.flags.bottom or false
        local box={_x=cfg.pos and cfg.pos.x or 0,_y=cfg.pos and cfg.pos.y or 0}
        return setmetatable(box,{__index=function(_, key)
            if key=='pos' then return function(self,x,y) if x then self._x,self._y=x,y else return self._x,self._y end end end
            if key=='extents' then return function() return 100,20 end end
            return function() end
        end})
    end}
    gearswap.install(env, {equip=function() end,enable=function() end,disable=function() end,cancel_action=function() end})
    env.windower=windower.new(platform)
    environment.install_runtime(env, platform)
    env.include('RahvinGS/interface')
    a.equal(env.Rahvin_GS, '2.1')
    env.include('RahvinGS/Rahvin-Engine')
    a.equal(type(env.precast), 'function'); a.equal(#events > 0, true); a.equal(#scheduled, 11)
    a.raises(function() windower.new({}).send_command('x') end, 'RahvinCompatError:windower.send_command')
end
