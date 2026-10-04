local a = require('tests.lib.assertions')

return function()
    package.loaded['compat.texts'] = nil
    local texts_compat = require('compat.texts')
    a.equal(type(texts_compat.new), 'function',
        'Ashita renderer compatibility must expose texts.new(fonts)')

    local created = {}
    local function fake_font(settings)
        local events = {}
        local font = {
            visible=settings.visible,
            locked=settings.locked,
            can_focus=settings.can_focus,
            font_family=settings.font_family,
            font_height=settings.font_height,
            bold=settings.bold,
            italic=settings.italic,
            right_justified=settings.right_justified,
            color=settings.color,
            color_outline=settings.color_outline,
            padding=settings.padding,
            position_x=settings.position_x,
            position_y=settings.position_y,
            text=settings.text,
            background={
                visible=settings.background and settings.background.visible or false,
                color=settings.background and settings.background.color or 0,
                locked=settings.background and settings.background.locked or false,
            },
            destroy_count=0,
        }

        function font:get_text_size()
            return 123, 45
        end
        function font:register(name, alias, callback)
            events[name] = events[name] or {}
            events[name][alias] = callback
            return true
        end
        function font:unregister(name, alias)
            if events[name] then events[name][alias] = nil end
            return true
        end
        function font:destroy()
            self.destroy_count = self.destroy_count + 1
            return true
        end
        function font:emit(name, ...)
            local list = events[name] or {}
            for _, callback in pairs(list) do callback(...) end
        end
        function font:event_count(name)
            local n = 0
            for _ in pairs(events[name] or {}) do n = n + 1 end
            return n
        end

        created[#created + 1] = font
        return font
    end

    local fonts = {
        new=function(settings)
            return fake_font(settings)
        end,
    }

    local texts = texts_compat.new(fonts)
    a.equal(type(texts.new), 'function')

    local cfg = {
        text={
            font='Consolas', size=11,
            red=10, green=20, blue=30, alpha=255,
            stroke={width=2, red=1, green=2, blue=3, alpha=200},
        },
        pos={x=100, y=200},
        bg={visible=true, red=4, green=5, blue=6, alpha=190},
        flags={bold=true},
        padding=3,
    }

    local box = texts.new('Rahvin', cfg)
    a.equal(#created, 1, 'texts.new must own one Ashita font object')
    local font = created[1]

    -- Rahvin core relies on the Windower texts library filling these omitted defaults.
    a.equal(type(cfg.text.fonts), 'table')
    a.equal(cfg.flags.italic, false)
    a.equal(cfg.flags.right, false)
    a.equal(cfg.flags.bottom, false)

    a.equal(font.font_family, 'Consolas')
    a.equal(font.font_height, 11)
    a.equal(font.position_x, 100)
    a.equal(font.position_y, 200)
    a.equal(font.text, 'Rahvin')
    a.equal(font.bold, true)

    for _, name in ipairs({
        'pos','pos_x','pos_y','font','size','color','alpha','stroke_width','stroke_color',
        'stroke_alpha','bg_color','bg_alpha','bg_visible','bold','italic','right_justified',
        'bottom_justified','pad','draggable','show','hide','text','extents','register_event',
        'unregister_event','destroy',
    }) do
        a.equal(type(box[name]), 'function', 'texts compatibility missing method: ' .. name)
    end

    box:pos(320, 90)
    local x, y = box:pos()
    a.equal(x, 320); a.equal(y, 90)
    a.equal(font.position_x, 320); a.equal(font.position_y, 90)
    a.equal(cfg.pos.x, 320); a.equal(cfg.pos.y, 90)

    box:pos_x(640); box:pos_y(480)
    a.equal(box:pos_x(), 640); a.equal(box:pos_y(), 480)
    a.equal(cfg.pos.x, 640); a.equal(cfg.pos.y, 480)

    box:text('Classic')
    a.equal(box:text(), 'Classic')
    a.equal(font.text, 'Classic')

    local colored = '\\cs(150,150,150)STN\\cr \\cs(80,220,110)DT\\cr'
    box:text(colored)
    a.equal(box:text(), colored,
        'Windower texts getter must preserve the Rahvin-facing source string')
    a.equal(font.text, '|cFF969696|STN|r |cFF50DC6E|DT|r',
        'Windower inline RGB tags must be translated to Ashita font inline colors')
    local ew, eh = box:extents()
    a.equal(ew, 123); a.equal(eh, 45)

    box:font('Arial', 'Segoe UI')
    box:size(14)
    box:bold(false)
    box:italic(true)
    box:right_justified(true)
    box:bottom_justified(true)
    box:pad(5)
    a.equal(font.font_family, 'Arial')
    a.equal(font.font_height, 14)
    a.equal(font.bold, false)
    a.equal(font.italic, true)
    a.equal(font.right_justified, true)
    a.equal(font.padding, 5)
    a.equal(cfg.text.font, 'Arial')
    a.equal(cfg.text.size, 14)
    a.equal(cfg.flags.bold, false)
    a.equal(cfg.flags.italic, true)
    a.equal(cfg.flags.right, true)
    a.equal(cfg.flags.bottom, true)
    a.equal(cfg.padding, 5)

    box:color(10, 20, 30)
    box:alpha(128)
    a.equal(box:alpha(), 128)
    a.equal(cfg.text.alpha, 128)

    box:stroke_color(1, 2, 3)
    box:stroke_alpha(200)
    box:stroke_width(2)
    a.equal(box:stroke_width(), 2)
    a.equal(cfg.text.stroke.width, 2)
    a.equal(cfg.text.stroke.alpha, 200)

    box:bg_color(4, 5, 6)
    box:bg_alpha(190)
    box:bg_visible(true)
    a.equal(box:bg_visible(), true)
    a.equal(cfg.bg.visible, true)

    -- Visibility must control both the glyph plane and its configured background. A hidden
    -- box may change its background preference without accidentally showing a stale panel.
    box:show()
    a.equal(font.visible, true)
    a.equal(font.background.visible, true)
    box:hide()
    a.equal(font.visible, false)
    a.equal(font.background.visible, false)
    box:bg_visible(false)
    box:show()
    a.equal(font.visible, true)
    a.equal(font.background.visible, false)

    -- Ashita font objects are movable while unlocked. Windower's draggable flag maps to the
    -- font and background lock state; the adapter emits Rahvin's drag callback after the
    -- native font has moved.
    box:draggable(true)
    a.equal(font.locked, false)
    a.equal(font.background.locked, false)
    local drags = 0
    local on_drag = function() drags = drags + 1 end
    box:register_event('drag', on_drag)
    a.equal(font:event_count('left_click_up'), 1)
    font.position_x, font.position_y = 700, 500
    font:emit('left_click_up', {})
    a.equal(drags, 1)
    a.equal(cfg.pos.x, 700)
    a.equal(cfg.pos.y, 500)
    box:unregister_event('drag', on_drag)
    a.equal(font:event_count('left_click_up'), 0)
    box:draggable(false)
    a.equal(font.locked, true)
    a.equal(font.background.locked, true)

    a.raises(function()
        box:register_event('click', function() end)
    end, 'RahvinCompatError:texts.event:click',
        'unsupported text events must fail loudly')

    box:destroy()
    a.equal(font.destroy_count, 1)
    box:destroy()
    a.equal(font.destroy_count, 1, 'texts destroy must be idempotent')
end
