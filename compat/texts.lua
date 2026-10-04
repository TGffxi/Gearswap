local M = {}

local function clamp_byte(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 255 then return 255 end
    return math.floor(value)
end

local function argb(alpha, red, green, blue)
    return clamp_byte(alpha) * 0x1000000
        + clamp_byte(red) * 0x10000
        + clamp_byte(green) * 0x100
        + clamp_byte(blue)
end

local function render_text(value)
    value = tostring(value or '')
    value = value:gsub('\\cs%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)',
        function(red, green, blue)
            return ('|cFF%02X%02X%02X|'):format(
                clamp_byte(red), clamp_byte(green), clamp_byte(blue))
        end)
    return value:gsub('\\cr', '|r')
end

local function ensure_config(cfg)
    cfg = cfg or {}
    cfg.text = cfg.text or {}
    cfg.text.fonts = cfg.text.fonts or {}
    cfg.text.stroke = cfg.text.stroke or {}
    cfg.pos = cfg.pos or {}
    cfg.bg = cfg.bg or {}
    cfg.flags = cfg.flags or {}

    cfg.text.font = cfg.text.font or 'Arial'
    cfg.text.size = tonumber(cfg.text.size) or 10
    cfg.text.red = clamp_byte(cfg.text.red == nil and 255 or cfg.text.red)
    cfg.text.green = clamp_byte(cfg.text.green == nil and 255 or cfg.text.green)
    cfg.text.blue = clamp_byte(cfg.text.blue == nil and 255 or cfg.text.blue)
    cfg.text.alpha = clamp_byte(cfg.text.alpha == nil and 255 or cfg.text.alpha)

    cfg.text.stroke.width = tonumber(cfg.text.stroke.width) or 0
    cfg.text.stroke.red = clamp_byte(cfg.text.stroke.red or 0)
    cfg.text.stroke.green = clamp_byte(cfg.text.stroke.green or 0)
    cfg.text.stroke.blue = clamp_byte(cfg.text.stroke.blue or 0)
    cfg.text.stroke.alpha = clamp_byte(cfg.text.stroke.alpha or 0)

    cfg.pos.x = tonumber(cfg.pos.x) or 0
    cfg.pos.y = tonumber(cfg.pos.y) or 0

    cfg.bg.visible = cfg.bg.visible == true
    cfg.bg.red = clamp_byte(cfg.bg.red or 0)
    cfg.bg.green = clamp_byte(cfg.bg.green or 0)
    cfg.bg.blue = clamp_byte(cfg.bg.blue or 0)
    cfg.bg.alpha = clamp_byte(cfg.bg.alpha or 0)

    cfg.flags.bold = cfg.flags.bold == true
    cfg.flags.italic = cfg.flags.italic == true
    cfg.flags.right = cfg.flags.right == true
    cfg.flags.bottom = cfg.flags.bottom == true
    cfg.flags.draggable = cfg.flags.draggable == true
    cfg.padding = tonumber(cfg.padding) or 0

    return cfg
end

local function require_method(owner, name)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:texts.fonts.' .. tostring(name), 3)
    end
    return fn
end

function M.new(fonts)
    if type(fonts) ~= 'table' then
        error('RahvinCompatError:texts.fonts', 2)
    end
    local font_new = require_method(fonts, 'new')

    local service = {}

    function service.new(initial_text, raw_cfg)
        local cfg = ensure_config(raw_cfg)
        local shown = false
        local destroyed = false
        local drag_sequence = 0
        local drag_handlers = {}
        local source_text = tostring(initial_text or '')

        local font = font_new({
            visible=false,
            can_focus=cfg.flags.draggable,
            locked=not cfg.flags.draggable,
            font_family=cfg.text.font,
            font_height=cfg.text.size,
            bold=cfg.flags.bold,
            italic=cfg.flags.italic,
            right_justified=cfg.flags.right,
            color=argb(cfg.text.alpha, cfg.text.red, cfg.text.green, cfg.text.blue),
            color_outline=argb(
                cfg.text.stroke.alpha,
                cfg.text.stroke.red,
                cfg.text.stroke.green,
                cfg.text.stroke.blue),
            padding=cfg.padding,
            position_x=cfg.pos.x,
            position_y=cfg.pos.y,
            text=render_text(source_text),
            background={
                visible=false,
                color=argb(cfg.bg.alpha, cfg.bg.red, cfg.bg.green, cfg.bg.blue),
                locked=not cfg.flags.draggable,
                can_focus=cfg.flags.draggable,
            },
        })
        if type(font) ~= 'table' then
            error('RahvinCompatError:texts.font_create', 2)
        end
        if type(font.background) ~= 'table' then
            error('RahvinCompatError:texts.font_background', 2)
        end

        local box = {}

        local function alive()
            return not destroyed
        end

        local function sync_position_from_font()
            cfg.pos.x = tonumber(font.position_x) or cfg.pos.x
            cfg.pos.y = tonumber(font.position_y) or cfg.pos.y
        end

        local function refresh_color()
            font.color = argb(cfg.text.alpha, cfg.text.red, cfg.text.green, cfg.text.blue)
        end

        local function refresh_outline()
            font.color_outline = argb(
                cfg.text.stroke.alpha,
                cfg.text.stroke.red,
                cfg.text.stroke.green,
                cfg.text.stroke.blue)
        end

        local function refresh_background()
            font.background.color = argb(cfg.bg.alpha, cfg.bg.red, cfg.bg.green, cfg.bg.blue)
            font.background.visible = shown and cfg.bg.visible or false
        end

        function box:pos(x, y)
            if x == nil then
                sync_position_from_font()
                return cfg.pos.x, cfg.pos.y
            end
            if not alive() then return false end
            cfg.pos.x = tonumber(x) or cfg.pos.x
            cfg.pos.y = tonumber(y) or cfg.pos.y
            font.position_x = cfg.pos.x
            font.position_y = cfg.pos.y
            return true
        end

        function box:pos_x(x)
            if x == nil then
                sync_position_from_font()
                return cfg.pos.x
            end
            return self:pos(x, cfg.pos.y)
        end

        function box:pos_y(y)
            if y == nil then
                sync_position_from_font()
                return cfg.pos.y
            end
            return self:pos(cfg.pos.x, y)
        end

        function box:font(name, ...)
            if name == nil then
                return cfg.text.font, unpack(cfg.text.fonts)
            end
            if not alive() then return false end
            cfg.text.font = tostring(name)
            cfg.text.fonts = {...}
            font.font_family = cfg.text.font
            return true
        end

        function box:size(value)
            if value == nil then return cfg.text.size end
            if not alive() then return false end
            cfg.text.size = tonumber(value) or cfg.text.size
            font.font_height = cfg.text.size
            return true
        end

        function box:color(red, green, blue)
            if red == nil then return cfg.text.red, cfg.text.green, cfg.text.blue end
            if not alive() then return false end
            cfg.text.red = clamp_byte(red)
            cfg.text.green = clamp_byte(green)
            cfg.text.blue = clamp_byte(blue)
            refresh_color()
            return true
        end

        function box:alpha(value)
            if value == nil then return cfg.text.alpha end
            if not alive() then return false end
            cfg.text.alpha = clamp_byte(value)
            refresh_color()
            return true
        end

        function box:stroke_width(value)
            if value == nil then return cfg.text.stroke.width end
            if not alive() then return false end
            cfg.text.stroke.width = tonumber(value) or cfg.text.stroke.width
            return true
        end

        function box:stroke_color(red, green, blue)
            if red == nil then
                return cfg.text.stroke.red, cfg.text.stroke.green, cfg.text.stroke.blue
            end
            if not alive() then return false end
            cfg.text.stroke.red = clamp_byte(red)
            cfg.text.stroke.green = clamp_byte(green)
            cfg.text.stroke.blue = clamp_byte(blue)
            refresh_outline()
            return true
        end

        function box:stroke_alpha(value)
            if value == nil then return cfg.text.stroke.alpha end
            if not alive() then return false end
            cfg.text.stroke.alpha = clamp_byte(value)
            refresh_outline()
            return true
        end

        function box:bg_color(red, green, blue)
            if red == nil then return cfg.bg.red, cfg.bg.green, cfg.bg.blue end
            if not alive() then return false end
            cfg.bg.red = clamp_byte(red)
            cfg.bg.green = clamp_byte(green)
            cfg.bg.blue = clamp_byte(blue)
            refresh_background()
            return true
        end

        function box:bg_alpha(value)
            if value == nil then return cfg.bg.alpha end
            if not alive() then return false end
            cfg.bg.alpha = clamp_byte(value)
            refresh_background()
            return true
        end

        function box:bg_visible(value)
            if value == nil then return cfg.bg.visible end
            if not alive() then return false end
            cfg.bg.visible = value == true
            refresh_background()
            return true
        end

        function box:bold(value)
            if value == nil then return cfg.flags.bold end
            if not alive() then return false end
            cfg.flags.bold = value == true
            font.bold = cfg.flags.bold
            return true
        end

        function box:italic(value)
            if value == nil then return cfg.flags.italic end
            if not alive() then return false end
            cfg.flags.italic = value == true
            font.italic = cfg.flags.italic
            return true
        end

        function box:right_justified(value)
            if value == nil then return cfg.flags.right end
            if not alive() then return false end
            cfg.flags.right = value == true
            font.right_justified = cfg.flags.right
            return true
        end

        function box:bottom_justified(value)
            if value == nil then return cfg.flags.bottom end
            if not alive() then return false end
            cfg.flags.bottom = value == true
            return true
        end

        function box:pad(value)
            if value == nil then return cfg.padding end
            if not alive() then return false end
            cfg.padding = tonumber(value) or cfg.padding
            font.padding = cfg.padding
            return true
        end

        function box:draggable(value)
            if value == nil then return cfg.flags.draggable end
            if not alive() then return false end
            cfg.flags.draggable = value == true
            font.locked = not cfg.flags.draggable
            font.can_focus = cfg.flags.draggable
            font.background.locked = not cfg.flags.draggable
            font.background.can_focus = cfg.flags.draggable
            return true
        end

        function box:show()
            if not alive() then return false end
            shown = true
            font.visible = true
            font.background.visible = cfg.bg.visible
            return true
        end

        function box:hide()
            if not alive() then return true end
            shown = false
            font.visible = false
            font.background.visible = false
            return true
        end

        function box:text(value)
            if value == nil then return source_text end
            if not alive() then return false end
            source_text = tostring(value)
            font.text = render_text(source_text)
            return true
        end

        function box:extents()
            if not alive() then return 0, 0 end
            local get_text_size = require_method(font, 'get_text_size')
            return get_text_size(font)
        end

        function box:register_event(name, callback)
            if name ~= 'drag' then
                error('RahvinCompatError:texts.event:' .. tostring(name), 2)
            end
            if type(callback) ~= 'function' then
                error('RahvinCompatError:texts.event_handler', 2)
            end
            if not alive() then return false end
            if drag_handlers[callback] then return true end

            local register = require_method(font, 'register')
            drag_sequence = drag_sequence + 1
            local alias = 'rahvings_drag_' .. tostring(drag_sequence)
            local wrapper = function(...)
                sync_position_from_font()
                return callback(...)
            end
            drag_handlers[callback] = {alias=alias, wrapper=wrapper}
            register(font, 'left_click_up', alias, wrapper)
            return true
        end

        function box:unregister_event(name, callback)
            if name ~= 'drag' then
                error('RahvinCompatError:texts.event:' .. tostring(name), 2)
            end
            if not alive() then return true end
            local entry = drag_handlers[callback]
            if not entry then return true end
            local unregister = require_method(font, 'unregister')
            unregister(font, 'left_click_up', entry.alias)
            drag_handlers[callback] = nil
            return true
        end

        function box:destroy()
            if destroyed then return true end

            if type(font.unregister) == 'function' then
                for callback, entry in pairs(drag_handlers) do
                    font:unregister('left_click_up', entry.alias)
                    drag_handlers[callback] = nil
                end
            else
                drag_handlers = {}
            end

            shown = false
            font.visible = false
            font.background.visible = false

            local destroy = require_method(font, 'destroy')
            destroy(font)
            destroyed = true
            return true
        end

        return box
    end

    return service
end

return M
