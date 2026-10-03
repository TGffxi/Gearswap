local M = {}

local canonical_to_lac = {
    main='Main', sub='Sub', range='Range', ammo='Ammo', head='Head', body='Body',
    hands='Hands', legs='Legs', feet='Feet', neck='Neck', waist='Waist', back='Back',
    left_ear='Ear1', right_ear='Ear2', left_ring='Ring1', right_ring='Ring2',
}
local aliases = {
    ranged='range', ear1='left_ear', lear='left_ear', learring='left_ear',
    ear2='right_ear', rear='right_ear', rearring='right_ear',
    ring1='left_ring', lring='left_ring', ring2='right_ring', rring='right_ring',
}
local lac_to_canonical = {}
for canonical, lac in pairs(canonical_to_lac) do lac_to_canonical[lac:lower()] = canonical end

local function unknown(name) error('RahvinCompatError:unknown_slot:' .. tostring(name), 3) end
local function canonical(name)
    if type(name) ~= 'string' then return unknown(name) end
    local lowered = name:lower()
    return aliases[lowered] or canonical_to_lac[lowered] and lowered or lac_to_canonical[lowered] or unknown(name)
end

function M.to_lac(name) return canonical_to_lac[canonical(name)] end
function M.to_gearswap(name) return canonical(name) end

return M
