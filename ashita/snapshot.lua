local copy = require('compat.sets').copy
local M = {}
local required = {'begin_snapshot','player','world','buffs','pet','equipment','inventory'}
local Snapshot = {}; Snapshot.__index = Snapshot
local function call(provider, name, generation)
    local fn = provider[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:snapshot_provider:' .. name, 3) end
    return copy(fn(provider, generation))
end
function M.new(provider)
    if type(provider) ~= 'table' then error('RahvinCompatError:snapshot_provider', 2) end
    return setmetatable({_provider=provider}, Snapshot)
end
function Snapshot:capture()
    local provider = self._provider
    local generation = call(provider, 'begin_snapshot')
    local buffs = call(provider, 'buffs', generation) or {}
    local active = {}
    for _, buff in ipairs(buffs) do
        if type(buff) ~= 'table' or buff.id == nil or buff.name == nil then error('RahvinCompatError:snapshot_buff', 2) end
        active[buff.id] = (active[buff.id] or 0) + 1
        active[buff.name] = (active[buff.name] or 0) + 1
    end
    return {
        generation=generation,
        player=call(provider, 'player', generation), world=call(provider, 'world', generation),
        buffactive=active, buffs=buffs, pet=call(provider, 'pet', generation),
        equipment=call(provider, 'equipment', generation), inventory=call(provider, 'inventory', generation),
    }
end
return M
