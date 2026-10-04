local slots = require('compat.slots')

local M = {}

local BAG_ALIASES = {
    inventory='inventory',
    wardrobe='wardrobe', wardrobe1='wardrobe',
    wardrobe2='wardrobe2', wardrobe3='wardrobe3', wardrobe4='wardrobe4',
    wardrobe5='wardrobe5', wardrobe6='wardrobe6', wardrobe7='wardrobe7', wardrobe8='wardrobe8',
}

local EQUIPPABLE_BAGS = {
    'inventory','wardrobe','wardrobe2','wardrobe3','wardrobe4',
    'wardrobe5','wardrobe6','wardrobe7','wardrobe8',
}

local function trim(value)
    return (tostring(value or ''):gsub('^%s*(.-)%s*$', '%1'))
end

local function is_slot(key)
    local ok = pcall(slots.to_lac, key)
    return ok
end

local function normalized_bag(value)
    if type(value) ~= 'string' then return nil end
    local key = value:lower():gsub('[^%w]', '')
    return BAG_ALIASES[key]
end

local function filter_match(name, filters)
    if not filters or #filters == 0 then return true end
    local lowered = name:lower()
    local positive = false
    local positive_match = false
    for _, value in ipairs(filters) do
        value = tostring(value)
        if value:sub(1, 1) == '-' then
            local needle = value:sub(2):lower()
            if needle ~= '' and lowered:find(needle, 1, true) then return false end
        else
            positive = true
            if lowered:find(value:lower(), 1, true) then positive_match = true end
        end
    end
    return not positive or positive_match
end

local function add_item(found, value)
    if type(value) == 'string' then
        local name = trim(value)
        if name ~= '' and name:lower() ~= 'empty' and name:lower() ~= 'remove' then
            found[#found + 1] = {name=name}
        end
        return
    end
    if type(value) ~= 'table' then return end
    local name = value.name or value.Name
    if type(name) == 'string' and trim(name) ~= '' then
        found[#found + 1] = {
            name=trim(name),
            bag=normalized_bag(value.bag or value.Bag),
        }
    end
end

local function collect_sets(value, found, seen)
    if type(value) ~= 'table' then return end
    if seen[value] then return end
    seen[value] = true

    -- An item descriptor is terminal; its metadata (augments, bag, priority) is not a set.
    if type(value.name or value.Name) == 'string' then
        add_item(found, value)
        return
    end

    for key, child in pairs(value) do
        if type(key) == 'string' and is_slot(key) then
            add_item(found, child)
        elseif type(child) == 'table' then
            collect_sets(child, found, seen)
        end
    end
end

local function has_item(player, item)
    if type(player) ~= 'table' then return false end
    local wanted = item.name:lower()
    local bags = item.bag and {item.bag} or EQUIPPABLE_BAGS
    for _, field in ipairs(bags) do
        local bag = player[field]
        if type(bag) == 'table' then
            if bag[item.name] ~= nil then return true end
            for name in pairs(bag) do
                if type(name) == 'string' and name:lower() == wanted then return true end
            end
        end
    end
    return false
end

function M.validate(env, platform, args)
    args = args or {}
    local filters = {}
    local first = args[1] and tostring(args[1]):lower() or nil
    if first == 'sets' or first == 'set' or first == 's' then
        for i = 2, #args do filters[#filters + 1] = args[i] end
    elseif first == nil then
        -- default GearSwap validation mode
    elseif first == 'inv' or first == 'inventory' or first == 'i' then
        error('RahvinCompatError:validate_inventory_unsupported', 2)
    else
        for i = 1, #args do filters[#filters + 1] = args[i] end
    end

    local items = {}
    collect_sets(env and env.sets or {}, items, {})
    local missing, seen = {}, {}
    for _, item in ipairs(items) do
        local key = item.name:lower() .. '|' .. tostring(item.bag or '')
        if not seen[key] and filter_match(item.name, filters)
            and not has_item(env and env.player, item) then
            seen[key] = true
            missing[#missing + 1] = item.name
        end
    end
    table.sort(missing, function(a, b) return a:lower() < b:lower() end)

    if platform and type(platform.chat) == 'function' then
        platform:chat(123, 'Checking for items in gear sets that are not in your inventory.')
        for _, name in ipairs(missing) do platform:chat(120, name) end
        platform:chat(123, 'Final count = ' .. tostring(#missing))
    end
    return missing
end

return M
