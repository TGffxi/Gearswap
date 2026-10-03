local a = require('tests.lib.assertions')
local fixtures = require('tests.fixtures.display_states')

return function()
    package.loaded['ashita.display'] = nil
    local loaded, display = pcall(require, 'ashita.display')
    a.equal(loaded, true, 'Phase 4 Task 4 requires ashita.display')
    a.equal(type(display.new), 'function', 'display.new must expose an injectable display service')
    a.deep_equal(display.STYLES, fixtures.styles, 'Ashita display must expose Rahvin\'s four styles in cycle order')

    local calls = {}
    local renderer = {}
    local function push(kind, ...)
        calls[#calls + 1] = {kind=kind, args={...}}
        return true
    end

    for _, style in ipairs(fixtures.styles) do
        renderer['render_' .. style] = function(_, model)
            return push('render_' .. style, model)
        end
    end
    renderer.move = function(_, x, y) return push('move', x, y) end
    renderer.hide = function(_) return push('hide') end
    renderer.destroy = function(_) return push('destroy') end

    local service = display.new(renderer)
    a.equal(type(service.show), 'function')
    a.equal(type(service.hide), 'function')
    a.equal(type(service.move), 'function')
    a.equal(type(service.destroy), 'function')

    -- First visible paint places the display, then dispatches to the style-specific renderer.
    local classic = fixtures.state('classic')
    a.equal(service.show(classic), true)
    a.equal(calls[1].kind, 'move')
    a.deep_equal(calls[1].args, {320, 90})
    a.equal(calls[2].kind, 'render_classic')
    a.equal(calls[2].args[1].job, 'WAR/NIN')
    a.equal(calls[2].args[1].modes[1].value, 'DT')

    -- Every Rahvin renderer has its own backend entry point. Same coordinates must not cause
    -- redundant movement calls while cycling styles.
    for _, style in ipairs({'harness', 'lattice', 'halo'}) do
        local before = #calls
        a.equal(service.show(fixtures.state(style)), true)
        a.equal(#calls, before + 1)
        a.equal(calls[#calls].kind, 'render_' .. style)
    end

    -- LATTICE receives the complete 16-slot ownership map and display cell-width setting.
    local lattice = fixtures.state('lattice')
    a.equal(service.show(lattice), true)
    local lattice_call = calls[#calls]
    a.equal(lattice_call.kind, 'render_lattice')
    a.equal(#lattice_call.args[1].cells, 16)
    a.equal(lattice_call.args[1].cells[1].slot, 'main')
    a.equal(lattice_call.args[1].cells[1].holder, 'weapon')
    a.equal(lattice_call.args[1].cells[4].slot, 'ammo')
    a.equal(lattice_call.args[1].cells[4].holder, 'hoxne')
    a.equal(lattice_call.args[1].min_value_cells, 9)
    a.equal(lattice_call.args[1].oneline, false)

    -- State changes must reach the renderer without stale cached mode/status values.
    local changed = fixtures.state('halo')
    changed.modes[1].value = 'Normal'
    changed.indicators.TreasureMode = 'Full Time'
    a.equal(service.show(changed), true)
    local changed_call = calls[#calls]
    a.equal(changed_call.kind, 'render_halo')
    a.equal(changed_call.args[1].modes[1].value, 'Normal')
    a.equal(changed_call.args[1].indicators.TreasureMode, 'Full Time')

    -- A model that says hidden tears the visible display down instead of repainting it.
    local before_hidden = #calls
    a.equal(service.show(fixtures.hidden('classic')), true)
    a.equal(#calls, before_hidden + 1)
    a.equal(calls[#calls].kind, 'hide')
    local after_hidden = #calls
    a.equal(service.hide(), true)
    a.equal(#calls, after_hidden, 'repeated hide must be idempotent')

    -- Explicit positioning is independent of visibility and avoids duplicate backend moves.
    a.equal(service.move(640, 480), true)
    a.equal(calls[#calls].kind, 'move')
    a.deep_equal(calls[#calls].args, {640, 480})
    local after_move = #calls
    a.equal(service.move(640, 480), true)
    a.equal(#calls, after_move, 'repeated move to same coordinates must be idempotent')

    -- Invalid styles fail closed and never select an arbitrary renderer.
    local bad = fixtures.state('neon')
    local before_bad = #calls
    local ok, reason = service.show(bad)
    a.equal(ok, false)
    a.equal(reason, 'unsupported_style')
    a.equal(#calls, before_bad)

    -- Destroy is safe under reload/unload repetition, and no later call may resurrect objects.
    a.equal(service.destroy(), true)
    a.equal(calls[#calls].kind, 'destroy')
    local after_destroy = #calls
    a.equal(service.destroy(), true)
    a.equal(#calls, after_destroy, 'destroy must be idempotent')
    local dead_show, dead_reason = service.show(fixtures.state('classic'))
    a.equal(dead_show, false)
    a.equal(dead_reason, 'destroyed')
    a.equal(service.hide(), true)
    a.equal(service.move(1, 2), false)
    a.equal(#calls, after_destroy, 'destroyed display must never recreate backend objects')
end
