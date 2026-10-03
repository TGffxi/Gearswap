local M = {}
local methods = {}
local mt = {__index=methods, __tostring=function(self) return tostring(self.value) end}
local function locate(self, value)
    for index, option in ipairs(self._options) do if option == value then return index end end
end
function methods:options(...)
    if self._boolean then error('RahvinCompatError:mode_boolean_options', 2) end
    self._options = {...}
    if #self._options == 0 then error('RahvinCompatError:mode_empty_options', 2) end
    self._index, self.value = 1, self._options[1]
    return self
end
function methods:cycle()
    if self._boolean then self.value = not self.value; return self.value end
    if #self._options == 0 then error('RahvinCompatError:mode_no_options', 2) end
    self._index = (self._index % #self._options) + 1
    self.value = self._options[self._index]
    return self.value
end
function methods:set(value)
    if self._boolean then
        if value == nil then value = true end
        if type(value) ~= 'boolean' then error('RahvinCompatError:mode_invalid_boolean:' .. tostring(value), 2) end
        self.value = value; return value
    end
    local index = locate(self, value)
    if not index then error('RahvinCompatError:mode_invalid_option:' .. tostring(value), 2) end
    self._index, self.value = index, value
    return value
end
function methods:toggle()
    if not self._boolean then error('RahvinCompatError:mode_not_boolean', 2) end
    self.value = not self.value
    return self.value
end
function methods:reset()
    if self._boolean then self.value = self._default
    elseif #self._options > 0 then self._index, self.value = 1, self._options[1] end
    return self.value
end
function M.M(spec)
    if type(spec) == 'boolean' then return setmetatable({_boolean=true, _default=spec, value=spec, _options={false,true}}, mt) end
    spec = spec or {}
    if type(spec) ~= 'table' then error('RahvinCompatError:mode_constructor', 2) end
    return setmetatable({description=spec.description, _options={}, _index=0}, mt)
end
return M
