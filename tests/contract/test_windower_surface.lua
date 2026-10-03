local a = require('tests.lib.assertions')
local windower = require('compat.windower')

return function()
    local w = windower.new({})
    local observed = {
        {'add_to_chat'}, {'send_command'}, {'send_ipc_message'}, {'register_event'},
        {'raw_register_event'}, {'get_windower_settings'}, {'wc_match'}, {'chat', 'input'},
        {'packets', 'inject_outgoing'}, {'ffxi', 'get_info'}, {'ffxi', 'get_items'},
        {'ffxi', 'get_abilities'}, {'ffxi', 'get_ability_recasts'},
        {'ffxi', 'get_spell_recasts'}, {'ffxi', 'get_mob_by_id'},
        {'ffxi', 'get_mob_by_index'}, {'ffxi', 'get_party'}, {'ffxi', 'get_player'},
        {'prim', 'create'}, {'prim', 'delete'}, {'prim', 'set_color'},
        {'prim', 'set_position'}, {'prim', 'set_size'}, {'prim', 'set_visibility'},
    }
    for _, path in ipairs(observed) do
        local value = w
        for _, key in ipairs(path) do value = value[key] end
        a.equal(type(value), 'function', table.concat(path, '.'))
    end
    a.raises(function() w.ffxi.get_party() end, 'RahvinCompatError:windower.get_party')
    a.raises(function() w.ffxi.get_spell_recasts() end, 'RahvinCompatError:windower.get_spell_recasts')
end
