local M = {}

M.STYLES = {'classic', 'harness', 'lattice', 'halo'}

local SUPPORTED = {}
for _, style in ipairs(M.STYLES) do
    SUPPORTED[style] = true
end

local function require_method(renderer, name)
    local fn = renderer and renderer[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:display.renderer.' .. tostring(name), 3)
    end
    return fn
end

local function valid_position(position)
    return type(position) == 'table'
        and type(position.x) == 'number'
        and type(position.y) == 'number'
end

function M.new(renderer)
    if type(renderer) ~= 'table' then
        error('RahvinCompatError:display.renderer', 2)
    end

    for _, style in ipairs(M.STYLES) do
        require_method(renderer, 'render_' .. style)
    end
    require_method(renderer, 'move')
    require_method(renderer, 'hide')
    require_method(renderer, 'destroy')

    local visible = false
    local destroyed = false
    local x, y
    local service = {}

    local function backend(name, ...)
        local fn = require_method(renderer, name)
        local result = fn(renderer, ...)
        if result == false then
            return false, 'renderer_' .. name
        end
        return true
    end

    function service.move(nx, ny)
        if destroyed then return false, 'destroyed' end
        if type(nx) ~= 'number' or type(ny) ~= 'number' then
            return false, 'invalid_position'
        end
        if x == nx and y == ny then return true end

        local ok, reason = backend('move', nx, ny)
        if not ok then return false, reason end
        x, y = nx, ny
        return true
    end

    function service.hide()
        if destroyed then return true end
        if not visible then return true end

        local ok, reason = backend('hide')
        if not ok then return false, reason end
        visible = false
        return true
    end

    function service.show(model)
        if destroyed then return false, 'destroyed' end
        if type(model) ~= 'table' then return false, 'invalid_model' end

        local style = model.style
        if not SUPPORTED[style] then return false, 'unsupported_style' end

        if model.visible == false then
            return service.hide()
        end

        if valid_position(model.position) then
            local ok, reason = service.move(model.position.x, model.position.y)
            if not ok then return false, reason end
        end

        local ok, reason = backend('render_' .. style, model)
        if not ok then return false, reason end
        visible = true
        return true
    end

    function service.destroy()
        if destroyed then return true end

        local ok, reason = backend('destroy')
        if not ok then return false, reason end
        destroyed = true
        visible = false
        return true
    end

    return service
end

return M
