local M = {}
local collection_mt = {__index={with=function(self, key, value)
    for _, row in pairs(self) do if type(row) == 'table' and row[key] == value then return row end end
end}}
local function collection(rows) return setmetatable(rows or {}, collection_mt) end
function M.new(platform)
    platform = platform or {}
    local source = platform.resources or {}
    local result = {}
    for _, name in ipairs({'items','buffs','job_abilities','weapon_skills','spells','elements','zones','jobs','bags'}) do
        result[name] = collection(source[name])
    end
    return result
end
return M
