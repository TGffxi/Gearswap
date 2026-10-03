local a = require('tests.lib.assertions')
local runtime = require('ashita.action_runtime')

local function action(kind, id, target)
    return {action_type=kind, id=id, name=kind .. id, english=kind .. id,
        target={id=target or 10, index=target or 10}}
end

return function()
    local calls = {}
    local engine = {}
    for _, name in ipairs({'pretarget','precast','midcast','preshot','midshot','aftercast'}) do
        engine[name] = function(value) calls[#calls+1]={name=name, action=value} end
    end
    local r = runtime.new(engine, function() return 10 end)
    local spell = action('Magic', 1)
    r:begin(spell); a.equal(calls[1].name, 'pretarget'); a.equal(calls[2].name, 'precast')
    r:midcast(spell); a.equal(calls[3].name, 'midcast')
    r:tick(spell); r:tick(nil); a.equal(calls[4].name, 'aftercast'); a.equal(calls[4].action.interrupted, false)
    r:tick(nil); r:tick(nil); a.equal(#calls, 4)

    calls = {}; local ranged=action('Ranged Attack', 2)
    r:begin(ranged); a.equal(calls[2].name, 'preshot')
    r:midcast(ranged); a.equal(calls[3].name, 'midshot')
    r:tick(nil); a.equal(calls[4].name, 'aftercast')

    for _, kind in ipairs({'WeaponSkill','JobAbility','Item'}) do
        calls={}; local current=action(kind, 3)
        r:begin(current); r:tick(nil)
        a.equal(calls[1].name, 'pretarget'); a.equal(calls[2].name, 'precast')
        a.equal(calls[3].name, 'aftercast'); a.equal(calls[3].action.interrupted, false)
    end

    calls={}; r:begin(action('Magic', 4)); r:cancelled(); r:cancelled(); r:tick(nil)
    a.equal(#calls, 3); a.equal(calls[3].action.interrupted, true)
    calls={}; r:begin(action('Magic', 5)); r:begin(action('Magic', 6))
    a.equal(calls[3].name, 'aftercast'); a.equal(calls[3].action.interrupted, true)
    r:tick(nil); a.equal(calls[6].name, 'aftercast'); a.equal(#calls, 6)
    calls={}; r:begin(action('Magic', 7)); r:tick(action('Item', 8))
    a.equal(calls[3].name, 'aftercast'); a.equal(calls[3].action.interrupted, true)
    a.equal(calls[4].name, 'pretarget'); r:tick(nil); a.equal(#calls, 6)
    calls={}; local same=action('Magic',11); local generation=r:begin(same)
    local resend=action('Magic',11); resend.resend=true
    a.equal(r:begin(resend),generation); a.equal(#calls,2); r:tick(nil); a.equal(#calls,3)
    calls={}; r:begin(action('Magic', 10)); r:interrupted(); r:tick(nil)
    a.equal(#calls, 3); a.equal(calls[3].action.interrupted, true)
    calls={}; r:begin(action('Magic', 9)); r:reset(); r:reset(); r:tick(nil)
    a.equal(#calls, 3); a.equal(calls[3].action.interrupted, true)
end
