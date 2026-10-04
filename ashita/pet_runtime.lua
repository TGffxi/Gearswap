local copy = require('compat.sets').copy

local M = {}
local methods = {}
methods.__index = methods

local function signature(action)
    if action == nil then return nil end
    return table.concat({
        tostring(action.action_type),
        tostring(action.id),
        tostring(action.name),
    }, '|')
end

local function invoke(self, name, action)
    local fn = self.engine[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:engine.' .. name, 3) end
    return fn(action)
end

function M.new(engine)
    return setmetatable({engine=engine or {}, active=nil}, methods)
end

function methods:_finish(interrupted)
    local active = self.active
    if not active then return false end
    self.active = nil
    local completed = copy(active.action)
    completed.interrupted = interrupted == true
    invoke(self, 'pet_aftercast', completed)
    return true
end

function methods:update(action)
    if action == nil then
        return self:_finish(false)
    end

    local next_signature = signature(action)
    if self.active and self.active.signature == next_signature then
        return false
    end

    if self.active then self:_finish(true) end
    self.active = {action=copy(action), signature=next_signature}
    invoke(self, 'pet_midcast', action)
    return true
end

function methods:is_active()
    return self.active ~= nil
end

function methods:current()
    return self.active and copy(self.active.action) or nil
end

-- Unload/reload teardown must not synthesize a pet_aftercast. It only drops adapter state.
function methods:clear()
    local had_active = self.active ~= nil
    self.active = nil
    return had_active
end

return M
