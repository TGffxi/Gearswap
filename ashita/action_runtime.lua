local copy = require('compat.sets').copy
local M = {}
local methods = {}
methods.__index = methods

local function signature(action)
    if action == nil then return nil end
    local target = action.target or {}
    return table.concat({tostring(action.action_type), tostring(action.id),
        tostring(target.id), tostring(target.index)}, '|')
end

local function invoke(self, name, action)
    local fn = self.engine[name]
    if type(fn) ~= 'function' then error('RahvinCompatError:engine.' .. name, 3) end
    return fn(action)
end

function M.new(engine, clock)
    return setmetatable({engine=engine or {}, clock=clock or os.clock, generation=0, active=nil}, methods)
end

function methods:_finish(interrupted)
    local active = self.active
    if not active or active.finished then return false end
    active.finished = true
    self.active = nil
    local completed = copy(active.action)
    completed.interrupted = interrupted == true
    invoke(self, 'aftercast', completed)
    return true
end

function methods:begin(action)
    if action == nil then error('RahvinCompatError:action.begin_nil', 2) end
    if self.active then self:_finish(true) end
    self.generation = self.generation + 1
    self.active = {action=copy(action), signature=signature(action), generation=self.generation,
        started_at=self.clock(), finished=false}
    invoke(self, 'pretarget', action)
    invoke(self, action.action_type == 'Ranged Attack' and 'preshot' or 'precast', action)
    return self.active.generation
end

function methods:midcast(action)
    if not self.active then self:begin(action) end
    return invoke(self, action.action_type == 'Ranged Attack' and 'midshot' or 'midcast', action)
end

function methods:tick(current)
    if not self.active then
        if current ~= nil then self:begin(current) end
        return false
    end
    local current_signature = signature(current)
    if current_signature == self.active.signature then return false end
    if current == nil then return self:_finish(false) end
    self:_finish(true)
    self:begin(current)
    return true
end

function methods:cancelled() return self:_finish(true) end
function methods:interrupted() return self:_finish(true) end
function methods:reset() return self:_finish(true) end
function methods:is_active() return self.active ~= nil end

return M
