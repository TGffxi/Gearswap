local a = require('tests.lib.assertions')
local bootstrap = require('ashita.bootstrap')

return function()
    local log = {}
    local function push(name, value)
        log[#log + 1] = {name, value}
        return true
    end

    local gData = {
        GetAction=function() return nil end,
        GetActionTarget=function() return nil end,
        GetPlayer=function() return {Name='Tester'} end,
    }
    local gFunc = {
        EquipSet=function() end,
        Enable=function() end,
        Disable=function() end,
        CancelAction=function() end,
    }
    local engine = {
        load=function() return push('engine.load') end,
        unload=function() return push('engine.unload') end,
        command=function() end,
        default=function() end,
        pretarget=function() end,
        precast=function() end,
        midcast=function() end,
        preshot=function() end,
        midshot=function() end,
        aftercast=function() end,
    }
    local settings = {Keybinds={offensemode='f12'}}
    local lifecycle = {
        load=function(value) return push('lifecycle.load', value) end,
        unload=function() return push('lifecycle.unload') end,
    }

    local profile = bootstrap.create({
        gData=gData,
        gFunc=gFunc,
        engine=engine,
        lifecycle=lifecycle,
        settings=settings,
    })

    profile.OnLoad()
    a.equal(log[1][1], 'engine.load', 'Rahvin engine load must remain first')
    a.equal(log[2][1], 'lifecycle.load', 'bootstrap must start Ashita lifecycle on LAC OnLoad')
    a.equal(log[2][2], settings, 'bootstrap must hand character settings to lifecycle')

    profile.OnUnload()
    a.equal(log[#log - 1][1], 'engine.unload', 'Rahvin unload must still run')
    a.equal(log[#log][1], 'lifecycle.unload', 'bootstrap must stop Ashita lifecycle on LAC OnUnload')
end
