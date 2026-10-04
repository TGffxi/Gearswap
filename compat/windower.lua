local M = {}
local function required(platform, name)
    return function(...)
        local fn = platform[name]
        if type(fn) ~= 'function' then error('RahvinCompatError:windower.' .. name, 2) end
        return fn(platform, ...)
    end
end
function M.new(platform)
    platform = platform or {}
    local w = {
        add_to_chat=required(platform, 'chat'), send_command=required(platform, 'send_command'),
        send_ipc_message=required(platform, 'send_ipc'), register_event=required(platform, 'register_event'),
        raw_register_event=required(platform, 'raw_register_event'), get_windower_settings=required(platform, 'window_settings'),
        wc_match=required(platform, 'wc_match'),
        chat={input=required(platform, 'input')},
        ffxi={
            get_info=required(platform, 'get_info'), get_items=required(platform, 'get_items'),
            get_abilities=required(platform, 'get_abilities'), get_ability_recasts=required(platform, 'get_ability_recasts'),
            get_spell_recasts=required(platform, 'get_spell_recasts'), get_party=required(platform, 'get_party'),
            get_mob_by_id=required(platform, 'get_mob_by_id'), get_mob_by_index=required(platform, 'get_mob_by_index'),
            get_player=required(platform, 'get_player'),
        },
        packets={inject_outgoing=required(platform, 'inject_outgoing')},
        prim=setmetatable({}, {__index=function(_, key) return required(platform, 'prim_' .. key) end}),
    }
    return w
end
return M
