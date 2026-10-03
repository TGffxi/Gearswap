local M = {}
local gs_to_lac = {main='Main', sub='Sub', range='Range', ammo='Ammo', head='Head', body='Body', hands='Hands', legs='Legs', feet='Feet', neck='Neck', waist='Waist', lear='Ear1', rear='Ear2', lring='Ring1', rring='Ring2', back='Back'}
local lac_to_gs = {}
for gs, lac in pairs(gs_to_lac) do lac_to_gs[lac:lower()] = gs end
local function unknown(name) error('RahvinCompatError:unknown_slot:' .. tostring(name), 3) end
function M.to_lac(name)
    if type(name) ~= 'string' then return unknown(name) end
    return gs_to_lac[name:lower()] or unknown(name)
end
function M.to_gearswap(name)
    if type(name) ~= 'string' then return unknown(name) end
    return lac_to_gs[name:lower()] or gs_to_lac[name:lower()] and name:lower() or unknown(name)
end
return M
