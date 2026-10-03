local M = {}
local methods = {}
methods.__index = methods

local function buff_state(values)
    local counts, names = {}, {}
    for key, value in pairs(values or {}) do
        local id, name, count
        if type(value) == 'table' then id, name, count = value.id, value.name, 1
        elseif type(key) == 'number' and type(value) == 'number' then id, name, count = value, tostring(value), 1
        else id, name, count = key, tostring(key), type(value) == 'number' and value or (value and 1 or 0) end
        if id ~= nil and count > 0 then counts[id]=(counts[id] or 0)+count; names[id]=name or tostring(id) end
    end
    return counts, names
end

local function call(engine, name, ...)
    local fn=engine[name]
    if type(fn)~='function' then error('RahvinCompatError:engine.'..name,3) end
    return fn(...)
end

function M.new(engine)
    return setmetatable({engine=engine or {}, previous=nil, pending={}}, methods)
end

function methods:_busy()
    local fn=self.engine.is_busy
    return type(fn)=='function' and fn() == true
end

-- Rahvin intentionally does not blanket-gate state hooks while an action is busy.
-- Status and pet transitions must reach their hooks immediately. Buff-driven redress is
-- the one transition family that is deferred by this adapter while the engine is busy.
function methods:_emit(name, ...)
    return call(self.engine,name,...)
end

function methods:_emit_buff(...)
    local event={name='buff_change',args={...}}
    if self:_busy() then self.pending[#self.pending+1]=event
    else call(self.engine,event.name,unpack(event.args)) end
end

function methods:_flush()
    if self:_busy() then return end
    local pending=self.pending; self.pending={}
    for _,event in ipairs(pending) do call(self.engine,event.name,unpack(event.args)) end
end

function methods:update(snapshot)
    if type(snapshot)~='table' or type(snapshot.player)~='table' then
        error('RahvinCompatError:state_snapshot',2)
    end
    self:_flush()
    local counts,names=buff_state(snapshot.buffs)
    local current={status=snapshot.player.status,buffs=counts,names=names,pet=snapshot.pet}
    local old=self.previous
    if not old then self.previous=current; return false end
    if current.status~=old.status then self:_emit('status_change',current.status,old.status) end
    local ids={}; for id in pairs(old.buffs) do ids[id]=true end; for id in pairs(current.buffs) do ids[id]=true end
    local ordered={}; for id in pairs(ids) do ordered[#ordered+1]=id end
    table.sort(ordered,function(a,b) return tostring(a)<tostring(b) end)
    for _,id in ipairs(ordered) do
        local before=(old.buffs[id] or 0)>0; local after=(current.buffs[id] or 0)>0
        if before~=after then self:_emit_buff(current.names[id] or old.names[id] or tostring(id),after) end
    end
    local old_id=old.pet and (old.pet.id or old.pet.index); local new_id=current.pet and (current.pet.id or current.pet.index)
    if old_id~=new_id then
        if old.pet then self:_emit('pet_change',old.pet,false) end
        if current.pet then self:_emit('pet_change',current.pet,true) end
    end
    self.previous=current
    return true
end

return M
