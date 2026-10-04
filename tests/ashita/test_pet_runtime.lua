local a = require('tests.lib.assertions')
local pet_runtime = require('ashita.pet_runtime')

local function action(id, name)
    return {
        id=id, name=name, english=name, action_type='Ability', type='BloodPactRage',
        prefix='/pet',
    }
end

return function()
    local calls = {}
    local engine = {
        pet_midcast=function(spell) calls[#calls+1]={'mid',spell} end,
        pet_aftercast=function(spell) calls[#calls+1]={'after',spell} end,
    }
    local r = pet_runtime.new(engine)

    a.equal(r:is_active(), false)
    a.equal(r:current(), nil)
    a.equal(r:update(nil), false)
    a.equal(#calls, 0)

    local first = action(1, 'Predator Claws')
    a.equal(r:update(first), true)
    a.equal(r:is_active(), true)
    a.equal(r:current().name, 'Predator Claws')
    a.equal(#calls, 1); a.equal(calls[1][1], 'mid')
    a.equal(calls[1][2].name, 'Predator Claws')

    -- HandleDefault polls continuously while LAC PetAction stays non-nil. The same action
    -- must not retrigger pet_midcast on every default tick.
    a.equal(r:update(action(1, 'Predator Claws')), false)
    a.equal(r:update(action(1, 'Predator Claws')), false)
    a.equal(#calls, 1)

    -- LAC clears PetAction on completion/interruption/timeout. That transition owns exactly
    -- one pet_aftercast and clears pet_midaction state.
    a.equal(r:update(nil), true)
    a.equal(r:is_active(), false)
    a.equal(#calls, 2); a.equal(calls[2][1], 'after')
    a.equal(calls[2][2].name, 'Predator Claws')
    a.equal(calls[2][2].interrupted, false)
    a.equal(r:update(nil), false)
    a.equal(#calls, 2)

    -- A genuinely new pet action may have the same id/name after the nil completion edge.
    a.equal(r:update(action(1, 'Predator Claws')), true)
    a.equal(#calls, 3); a.equal(calls[3][1], 'mid')

    -- If LAC replaces one active action with another without an observable nil tick, close
    -- the old action once as interrupted and start the new one once.
    a.equal(r:update(action(2, 'Flaming Crush')), true)
    a.equal(calls[4][1], 'after'); a.equal(calls[4][2].interrupted, true)
    a.equal(calls[5][1], 'mid'); a.equal(calls[5][2].name, 'Flaming Crush')
    a.equal(r:is_active(), true)
end
