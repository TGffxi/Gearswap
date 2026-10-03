local a = require('tests.lib.assertions')
local sets = require('compat.sets')
local cases = require('tests.fixtures.core_cases')

return function()
    local covered={}
    for _, case in ipairs(cases) do
        local logical={}
        for _, layer in ipairs(case.layers) do logical=sets.combine(logical, layer) end
        a.deep_equal(logical, case.expected, case.name)
        for slot in pairs(logical) do
            a.equal(type(slot),'string',case.name .. ' slot shape')
            a.equal(slot:match('^[A-Z]'),nil,case.name .. ' must remain GearSwap-shaped')
        end
        covered[case.contract]=true
    end
    for _, contract in ipairs({'Idle','Engaged','TP','ACC','DT','PDL','SB','CRIT','MEVA',
        'Savage Blade','ranged WS','Aftermath','Weapon Lock','Locked+R','Dual Wield','Two-Hand',
        'Movement','Buff overlays','Day bonus','Weather bonus','Cure / Light Bonus',
        'BRD instrument','GEO handbell'}) do
        a.equal(covered[contract],true,'missing merge contract '..contract)
    end
end
