local a = require('tests.lib.assertions')
local fixture = require('tests.lib.wave8_fixture')

local JOBS = {
    'BLM','BLU','BRD','BST','COR','DNC','DRG','DRK','GEO','MNK','NIN',
    'PLD','PUP','RDM','RNG','RUN','SAM','SCH','SMN','THF','WAR','WHM',
}

local function assert_shared_clean(shared, label)
    a.equal(#shared.tasks, 0, label .. ': scheduler queue must be empty after unload')
    a.equal(fixture.count(shared.native_handlers), 0,
        label .. ': native event registry must be empty after unload')
    a.equal(shared.command_owner, nil,
        label .. ': command alias ownership must be released after unload')
    a.equal(fixture.count(shared.bindings), 0,
        label .. ': Rahvin keybind ownership must be released after unload')
    a.equal(shared.active_fonts, 0,
        label .. ': every font/text primitive must be destroyed after unload')
    a.equal(shared.active_ipc, 0,
        label .. ': IPC generation must be closed after unload')
    a.equal(shared.ipc_subscriptions, 0,
        label .. ': IPC listener must be detached after unload')
    a.equal(fixture.count(shared.disabled_slots), 0,
        label .. ': no disabled LAC slot may leak into the next generation')
    a.equal(fixture.count(shared.primitive_objects), 0,
        label .. ': no native primitive may leak into the next generation')
end

return function()
    local shared = fixture.new_shared()

    -- Explicit same-process A -> activity -> unload -> B proof using two unchanged sample
    -- jobs and the exact same scheduler/event/keybind/command/IPC/font ownership surfaces.
    local a_gen = fixture.build(shared, 'WAR')
    a.equal(a_gen.graph.env.Rahvin_GS, '2.1')
    a.equal(a_gen.graph.profile.Sets, a_gen.graph.env.sets)
    a.equal(shared.active_fonts > 0, true)
    a.equal(fixture.count(shared.bindings) > 0, true,
        'file-scope WAR jobsetup must create Rahvin-owned keybinds')

    local marker_hits = 0
    a_gen.graph.env.windower.register_event('wave8 marker', function()
        marker_hits = marker_hits + 1
    end)
    a.equal(a_gen.graph.platform:emit('wave8 marker'), 1)
    a.equal(marker_hits, 1)

    a_gen.graph.profile.OnLoad()
    a.equal(shared.command_owner, a_gen.generation)
    a.equal(shared.active_ipc, 1)
    a.equal(shared.ipc_subscriptions, 1)
    a.equal(fixture.count(shared.native_handlers) > 0, true)
    a.equal(#shared.tasks > 0, true,
        'generation A must own scheduled jobsetup/startup work before unload')

    -- Leave a real player action active across the unload boundary. Bootstrap/lifecycle must
    -- finish/reset it inside generation A; generation B must not inherit that runtime state.
    a_gen.set_action({
        ActionType='Ability', Name='Provoke', Id=5, Type='Job Ability', Resend=false,
        Resource={Type=1, RecastTimerId=1, Skill=0, Element=0},
    })
    a_gen.graph.profile.HandleAbility()
    a.equal(a_gen.graph.action_runtime:is_active(), true,
        'generation A must have an active player action before unload')

    a_gen.graph.profile.OnUnload()
    a.equal(a_gen.graph.action_runtime:is_active(), false,
        'generation A action runtime must be reset during unload')
    a.equal(a_gen.graph.pet_runtime:is_active(), false)
    a.equal(a_gen.graph.platform:emit('wave8 marker'), 0,
        'generation A logical handlers must be removed after unload')
    a.equal(marker_hits, 1)
    assert_shared_clean(shared, 'generation A')

    local b_gen = fixture.build(shared, 'WHM')
    a.equal(b_gen.graph.env ~= a_gen.graph.env, true,
        'generation B must receive a fresh GearSwap execution environment')
    a.equal(b_gen.graph.env.sets ~= a_gen.graph.env.sets, true,
        'generation B must receive a fresh sets root')
    a.equal(b_gen.graph.action_runtime ~= a_gen.graph.action_runtime, true,
        'generation B must receive a fresh player action runtime')
    a.equal(b_gen.graph.pet_runtime ~= a_gen.graph.pet_runtime, true,
        'generation B must receive a fresh pet runtime')
    a.equal(b_gen.graph.command_runtime ~= a_gen.graph.command_runtime, true,
        'generation B must receive a fresh command runtime')
    a.equal(b_gen.graph.action_runtime:is_active(), false,
        'generation B must not inherit generation A action state')
    a.equal(b_gen.graph.env.pet_midaction(), false,
        'generation B must not inherit generation A pet state')

    b_gen.graph.profile.OnLoad()
    a.equal(shared.command_owner, b_gen.generation,
        'generation B must be able to reacquire the command alias after A unload')
    a.equal(shared.active_ipc, 1)
    a.equal(shared.ipc_subscriptions, 1)
    b_gen.graph.profile.OnUnload()
    assert_shared_clean(shared, 'generation B')

    -- Full unchanged sample sweep. Every job must construct, run get_sets through OnLoad,
    -- bind/register its generation, then unload cleanly before the next job enters the same
    -- shared process.
    for _, job in ipairs(JOBS) do
        local generation = fixture.build(shared, job)
        a.equal(generation.graph.env.Rahvin_GS, '2.1',
            job .. ': unchanged Rahvin engine must load')
        a.equal(type(generation.graph.env.get_sets), 'function',
            job .. ': unchanged sample must expose get_sets')
        a.equal(generation.graph.profile.Sets, generation.graph.env.sets,
            job .. ': LAC and GearSwap must share one sets root')

        generation.graph.profile.OnLoad()
        a.equal(next(generation.graph.env.sets) ~= nil, true,
            job .. ': get_sets must populate the unchanged sample gear sets')
        a.equal(shared.command_owner, generation.generation,
            job .. ': lifecycle must own exactly this generation command alias')
        a.equal(shared.active_ipc, 1,
            job .. ': lifecycle must own exactly one IPC generation')
        a.equal(shared.ipc_subscriptions, 1,
            job .. ': lifecycle must attach exactly one IPC listener')

        generation.graph.profile.OnUnload()
        assert_shared_clean(shared, job)
    end
end
