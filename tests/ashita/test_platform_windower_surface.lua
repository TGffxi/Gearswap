local a = require('tests.lib.assertions')

return function()
    package.loaded['ashita.platform'] = nil
    local platform = require('ashita.platform')

    local calls = {}
    local function mark(name, value)
        return function(...)
            calls[#calls + 1] = {name=name, args={...}}
            return value
        end
    end

    local native = {
        chat=mark('chat', 'chat-ok'),
        send_command=mark('send_command', 'command-ok'),
        input=mark('input', 'input-ok'),
        window_settings=mark('window_settings', {ui_x_res=1920, ui_y_res=1080}),
        wc_match=mark('wc_match', true),
        get_info=mark('get_info', {language='english', logged_in=true}),
        get_abilities=mark('get_abilities', {job_traits={18}}),
        get_party=mark('get_party', {party1_count=1}),
        get_mob_by_id=mark('get_mob_by_id', {id=111}),
        get_mob_by_index=mark('get_mob_by_index', {index=22}),
        get_player=mark('get_player', {id=111,index=22,name='Tester'}),
        inject_outgoing=mark('inject_outgoing', 'packet-ok'),
        schedule=mark('schedule', 'schedule-ok'),
        gettime=mark('gettime', 123.5),
        load_config=mark('load_config', {loaded=true}),
        save_config=mark('save_config', true),
        decode_item=mark('decode_item', {status=5}),
        new_file=mark('new_file', {exists=function() return false end}),
    }
    native.resources = {items={{id=1}}, buffs={}, job_abilities={}, weapon_skills={}, spells={}, elements={}, zones={}, jobs={}, bags={}}
    native.prim = {}
    for _, op in ipairs({'create','delete','set_position','set_size','set_color','set_visibility'}) do
        native.prim[op] = mark('prim_' .. op, true)
    end

    local inventory = {iter_bag=function(bag) return {{bag=bag,id=100,count=1}} end}
    local recasts = {abilities=function() return {[1]=2} end, spells=function() return {[3]=4} end}
    local p = platform.new({
        inventory=inventory,
        recasts=recasts,
        ipc_to_rahvin=function() return nil end,
        native=native,
    })

    local required = {
        'chat','send_command','input','window_settings','wc_match','get_info','get_items',
        'get_abilities','get_ability_recasts','get_spell_recasts','get_party','get_mob_by_id',
        'get_mob_by_index','get_player','inject_outgoing','schedule','gettime','load_config',
        'save_config','decode_item','new_file','prim_create','prim_delete','prim_set_position',
        'prim_set_size','prim_set_color','prim_set_visibility',
    }
    for _, name in ipairs(required) do
        a.equal(type(p[name]), 'function', 'platform missing Windower/runtime method: ' .. name)
    end
    a.equal(type(p.resources), 'table', 'platform must expose resources to compat.resources')
    a.equal(p.resources, native.resources, 'production resource surface must be shared, not copied')

    a.equal(p:chat(7, 'hello'), 'chat-ok')
    a.equal(p:send_command('/echo hi'), 'command-ok')
    a.equal(p:input('/ma "Cure" <me>'), 'input-ok')
    a.deep_equal(p:window_settings(), {ui_x_res=1920,ui_y_res=1080})
    a.equal(p:wc_match('Cure IV', 'Cure*'), true)
    a.deep_equal(p:get_info(), {language='english',logged_in=true})
    a.deep_equal(p:get_items(8), {{bag=8,id=100,count=1}})
    a.deep_equal(p:get_abilities(), {job_traits={18}})
    a.deep_equal(p:get_ability_recasts(), {[1]=2})
    a.deep_equal(p:get_spell_recasts(), {[3]=4})
    a.deep_equal(p:get_party(), {party1_count=1})
    a.deep_equal(p:get_mob_by_id(111), {id=111})
    a.deep_equal(p:get_mob_by_index(22), {index=22})
    a.deep_equal(p:get_player(), {id=111,index=22,name='Tester'})
    a.equal(p:inject_outgoing(0xF1, 'raw'), 'packet-ok')
    a.equal(p:schedule(function() end, 1.5), 'schedule-ok')
    a.equal(p:gettime(), 123.5)
    a.deep_equal(p:load_config('settings', {x=1}), {loaded=true})
    a.equal(p:save_config({x=2}), true)
    a.deep_equal(p:decode_item({Extra='x'}), {status=5})
    a.equal(type(p:new_file('foo').exists), 'function')
    a.equal(p:prim_create('box'), true)
    a.equal(p:prim_delete('box'), true)
    a.equal(p:prim_set_position('box', 1, 2), true)
    a.equal(p:prim_set_size('box', 3, 4), true)
    a.equal(p:prim_set_color('box', 1, 2, 3, 4), true)
    a.equal(p:prim_set_visibility('box', true), true)
end
