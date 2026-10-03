local M = {}

M.styles = {'classic', 'harness', 'lattice', 'halo'}

local SLOT_ORDER = {
    'main', 'sub', 'range', 'ammo',
    'head', 'body', 'hands', 'legs',
    'feet', 'neck', 'waist', 'back',
    'lear', 'rear', 'lring', 'rring',
}

local function copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, item in pairs(value) do out[copy(key, seen)] = copy(item, seen) end
    return out
end

local base = {
    visible = true,
    position = {x=320, y=90},
    oneline = false,
    min_value_cells = 9,
    job = 'WAR/NIN',
    indicators = {
        SpellReceived = 'ON',
        TreasureMode = 'Tag',
        Hoxne = 'OFF',
    },
    modes = {
        {name='OffenseMode', label='STN', value='DT'},
        {name='WeaponMode', label='DPS', value='Naegling'},
        {name='WeaponLock', label='LCK', value='ON'},
        {name='JobMode', label='MDE', value='Normal'},
    },
    hold = {label='LCK', value='main'},
    cells = {},
}

for i, slot in ipairs(SLOT_ORDER) do
    base.cells[i] = {
        slot=slot,
        holder=(slot == 'main' and 'weapon') or (slot == 'ammo' and 'hoxne') or 'free',
    }
end

function M.state(style)
    local value = copy(base)
    value.style = style
    return value
end

function M.hidden(style)
    local value = M.state(style or 'classic')
    value.visible = false
    return value
end

return M
