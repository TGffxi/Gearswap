local slots = require('compat.slots')
local sets = require('compat.sets')
local M = {}
local methods = {}
methods.__index = methods

local function call(self, name, ...)
    local fn = self.gFunc[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:gFunc.' .. name, 3) end
    return fn(...)
end

function M.new(gFunc)
    return setmetatable({gFunc=gFunc or {}, pending={}}, methods)
end

function methods:equip(set)
    if type(set) ~= 'table' then error('RahvinCompatError:equip_set', 2) end
    for slot, item in pairs(set) do self.pending[slots.to_lac(slot)] = sets.copy(item) end
end

function methods:enable(slot) return call(self, 'Enable', slots.to_lac(slot)) end
function methods:disable(slot) return call(self, 'Disable', slots.to_lac(slot)) end
function methods:cancel_action() return call(self, 'CancelAction') end

function methods:flush()
    if next(self.pending) == nil then return false end
    local pending = self.pending
    self.pending = {}
    call(self, 'EquipSet', pending)
    return true
end

return M
