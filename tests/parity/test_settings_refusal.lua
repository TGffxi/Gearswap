local a = require('tests.lib.assertions')
local harness = require('tests.lib.rahvin_harness')

return function()
    local refusal = {
        path='C:\\Ashita\\config\\addons\\luashitacast\\Tester_1\\rahvings\\settings.lua',
        reason='rahvings/settings.lua:1: unexpected symbol near <eof>',
    }

    local h = harness.new({
        load_config=function(_, defaults)
            -- Run on a copy of defaults while surfacing the unreadable new Ashita source.
            return defaults, {
                path=refusal.path,
                reason=refusal.reason,
            }
        end,
    })

    a.equal(#h.platform._saves, 0,
        'Rahvin load must not save before the refusal announcement')

    -- This is the unchanged Rahvin startup callback scheduled at 2.6s. The compatibility
    -- config layer must preserve load's second return value so core.lua sets settings_refused.
    h.env.settings_reset_announce()

    a.equal(#h.platform._saves, 0,
        'settings reset announce must not save defaults over a refused source')
    a.equal(#h.platform._chat, 1,
        'a refused startup load must produce exactly one recovery notice')
    local expected = 'Settings: ' .. refusal.path .. ' could not be read ('
        .. refusal.reason .. '). Running on defaults; nothing will be saved until the file '
        .. 'is fixed or deleted and GearSwap reloaded.'
    a.equal(h.platform._chat[1].message, expected,
        'Rahvin must receive the precise refusal path/reason and its existing recovery text')

    -- A later user-initiated save path must remain blocked for the whole refused session.
    h.env.display_zero_command()
    a.equal(#h.platform._saves, 0,
        'manual settings save must remain blocked after a refused load')
    a.equal(h.platform._chat[#h.platform._chat].message,
        'Settings not saved: ' .. refusal.path
            .. ' failed to load; fix or delete it and reload.',
        'manual save refusal must name the protected source precisely')
end
