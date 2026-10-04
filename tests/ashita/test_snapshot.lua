local a = require('tests.lib.assertions')
return function()
    local snapshot = require('ashita.snapshot')
    local generations = 0
    local provider = {}
    function provider:begin_snapshot() generations=generations+1; return generations end
    local function check(g) a.equal(g, generations, 'mixed provider generation') end
    function provider:player(g) check(g); return {name='Test', status_id=1, status='Engaged'} end
    function provider:world(g) check(g); return {day='Firesday', weather='Hot Spells', weather_id=5} end
    function provider:buffs(g) check(g); return {{id=33,name='Haste'}, {id=33,name='Haste'}, {id=40,name='Protect'}} end
    function provider:pet(g) check(g); return {name='Luopan'} end
    function provider:equipment(g) check(g); return {head='Nyame Helm'} end
    function provider:inventory(g) check(g); return {{id=1,name='Ring',slot=1},{id=1,name='Ring',slot=2}} end
    local service = snapshot.new(provider)
    local result = service:capture()
    a.equal(result.generation, 1); a.equal(result.player.status, 'Engaged')
    a.equal(result.world.day, 'Firesday'); a.equal(result.world.weather_id, 5)
    a.equal(result.buffactive.Haste, 2); a.equal(result.buffactive[33], 2); a.equal(result.buffactive.Protect, 1)
    a.equal(#result.inventory, 2); a.equal(result.inventory[1].slot, 1); a.equal(result.inventory[2].slot, 2)
    provider.player = function() error('provider changed after capture') end
    a.equal(result.player.name, 'Test')
    a.raises(function() snapshot.new({}):capture() end, 'RahvinCompatError:snapshot_provider:begin_snapshot')

    a.equal(type(snapshot.production), 'function',
        'snapshot.production must build the real LAC/Ashita snapshot source')

    local resources = {
        jobs={
            [1]={id=1,en='WAR',english='Warrior'},
            [12]={id=12,en='SAM',english='Samurai'},
            [20]={id=20,en='SCH',english='Scholar'},
        },
        items={
            [100]={id=100,en='Bronze Cap'},
            [200]={id=200,en='Shihei'},
            [300]={id=300,en='Test Ring'},
        },
        buffs={
            [33]={id=33,en='Haste'},
            [40]={id=40,en='Protect'},
        },
    }

    local party = {
        GetMemberServerId=function(_, slot) return slot == 0 and 123456 or 0 end,
        GetMemberTargetIndex=function(_, slot) return slot == 0 and 77 or 0 end,
    }
    local player_memory = {
        GetMainJob=function() return 1 end,
        GetSubJob=function() return 12 end,
        GetJobLevel=function(_, id)
            return ({[1]=99,[12]=49,[20]=99})[id] or 0
        end,
        GetJobPoints=function(_, id) return id == 20 and 42 or 0 end,
        GetJobPointsSpent=function(_, id) return id == 20 and 550 or 0 end,
        GetBuffs=function() return {33,33,40} end,
    }
    local entity = {
        GetRace=function(_, index)
            a.equal(index, 77)
            return 5
        end,
    }
    local memory = {
        GetParty=function() return party end,
        GetPlayer=function() return player_memory end,
        GetEntity=function() return entity end,
    }
    local core = {GetMemoryManager=function() return memory end}

    local gData = {
        GetPlayer=function()
            return {
                Name='Tester', MainJob='WAR', MainJobLevel=99, MainJobSync=99,
                SubJob='SAM', SubJobLevel=49, SubJobSync=49,
                Status='Engaged', HP=1000, MaxHP=1000, HPP=100,
                MP=100, MaxMP=100, MPP=100, TP=1234, IsMoving=true,
            }
        end,
        GetEnvironment=function()
            return {
                Area='Test Zone', Day='Firesday', DayElement='Fire',
                Weather='Fire', WeatherElement='Fire',
                RawWeather='Fire', RawWeatherElement='Fire',
                Time=12.34, Timestamp={day=1,hour=12,minute=34},
                MoonPhase='Full Moon', MoonPercent=100,
            }
        end,
        GetPet=function()
            return {Id=444,Index=88,Name='Carbuncle',Status='Engaged',HPP=100,TP=500}
        end,
        GetTarget=function()
            return {Id=999,Index=222,Name='TargetMob',Distance=4,Status='Engaged',Type='Monster',HPP=80}
        end,
        GetEquipment=function()
            return {
                Head={Name='Bronze Cap'},
                Ring1={Name='Test Ring'},
            }
        end,
    }

    local bag_rows = {
        [0]={
            {id=200,count=4,status=0,raw={Id=200,Count=4}},
            {id=200,count=6,status=0,raw={Id=200,Count=6}},
        },
        [8]={{id=300,count=1,status=5,raw={Id=300,Count=1}}},
        [10]={{id=100,count=1,status=0,raw={Id=100,Count=1}}},
    }
    local inventory = {
        iter_bag=function(bag) return bag_rows[bag] or {} end,
    }

    local capture = snapshot.production({
        core=core,
        gData=gData,
        inventory=inventory,
        resources=resources,
    })
    a.equal(type(capture), 'function')
    local live = capture()

    a.equal(live.player.name, 'Tester')
    a.equal(live.player.id, 123456)
    a.equal(live.player.index, 77)
    a.equal(live.player.main_job, 'WAR')
    a.equal(live.player.main_job_id, 1)
    a.equal(live.player.main_job_level, 99)
    a.equal(live.player.sub_job, 'SAM')
    a.equal(live.player.sub_job_level, 49)
    a.equal(live.player.race_id, 5)
    a.equal(live.player.jobs.WAR, 99)
    a.equal(live.player.jobs.SAM, 49)
    a.equal(live.player.jobs.SCH, 99)
    a.equal(live.player.job_points.sch.jp, 42)
    a.equal(live.player.job_points.sch.jp_spent, 550)
    a.equal(live.player.status, 'Engaged')
    a.equal(live.player.tp, 1234)
    a.equal(live.player.target.id, 999)
    a.equal(live.player.target.index, 222)
    a.equal(live.player.buffs[1], 33)
    a.equal(live.player.buffs[3], 40)

    a.equal(live.player.equipment.head, 'Bronze Cap')
    a.equal(live.player.equipment.left_ring, 'Test Ring')
    a.equal(live.player.equipment.ammo, 'empty',
        'unequipped GearSwap slots must be represented by the empty sentinel name')

    a.equal(live.player.inventory.Shihei.count, 10,
        'same-name stacks in one bag must aggregate for Rahvin ammo/tool counts')
    a.equal(live.player.wardrobe['Test Ring'].count, 1)
    a.equal(live.player.wardrobe2['Bronze Cap'].count, 1)
    a.equal(live.inventory, live.player.inventory,
        'top-level inventory snapshot must share the player inventory bag identity')
    a.equal(live.equipment, live.player.equipment,
        'top-level equipment snapshot must share the player equipment identity')

    a.equal(live.buffactive.Haste, 2)
    a.equal(live.buffactive[33], 2)
    a.equal(live.buffactive.Protect, 1)
    a.equal(live.world.area, 'Test Zone')
    a.equal(live.world.day_element, 'Fire')
    a.equal(live.world.weather_element, 'Fire')
    a.equal(live.world.weather_intensity, 1)
    a.equal(live.pet.isvalid, true)
    a.equal(live.pet.name, 'Carbuncle')
end
