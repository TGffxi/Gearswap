local bootstrap = require('ashita.bootstrap')
local profile = {Sets={}}
local delegate

function profile.Configure(deps)
    delegate = bootstrap.create(deps)
    profile.Sets = delegate.Sets
    return profile
end

local callbacks = {'OnLoad','OnUnload','HandleCommand','HandleDefault','HandleAbility','HandleItem',
    'HandlePrecast','HandleMidcast','HandlePreshot','HandleMidshot','HandleWeaponskill'}
for _, name in ipairs(callbacks) do
    profile[name] = function(...)
        if not delegate then error('RahvinCompatError:profile_not_configured', 2) end
        return delegate[name](...)
    end
end

local LAC_SLOTS = {
    'Main','Sub','Range','Ammo','Head','Body','Hands','Legs','Feet',
    'Neck','Waist','Back','Ear1','Ear2','Ring1','Ring2',
}

local function need(value, label)
    if value == nil then error('RahvinCompatError:profile.' .. label, 3) end
    return value
end

local function method(owner, name, label)
    local fn = owner and owner[name]
    if type(fn) ~= 'function' then
        error('RahvinCompatError:profile.' .. (label or name), 3)
    end
    return fn
end

local function active_sender(core, gData)
    local player = type(gData.GetPlayer) == 'function' and gData.GetPlayer() or nil
    local name = type(player) == 'table' and (player.Name or player.name) or nil
    if type(name) == 'string' and name ~= '' then return name end

    if type(core.GetMemoryManager) == 'function' then
        local memory = core:GetMemoryManager()
        local party = memory and type(memory.GetParty) == 'function' and memory:GetParty() or nil
        if party and type(party.GetMemberName) == 'function' then
            name = party:GetMemberName(0)
            if type(name) == 'string' and name ~= '' then return name end
        end
    end
    error('RahvinCompatError:profile.identity', 3)
end

function profile.production(job_path)
    if type(job_path) ~= 'string' or job_path:match('^%s*$') then
        error('RahvinCompatError:profile.job_path', 2)
    end

    local core = need(rawget(_G, 'AshitaCore'), 'AshitaCore')
    local gData = need(rawget(_G, 'gData'), 'gData')
    local gFunc = need(rawget(_G, 'gFunc'), 'gFunc')
    local ashita_root = need(rawget(_G, 'ashita'), 'ashita')
    local raw_events = need(ashita_root.events, 'ashita.events')

    local scheduler = require('ashita.scheduler')
    local events = require('ashita.events')
    local inventory = require('ashita.inventory')
    local recasts = require('ashita.recasts')
    local resources_module = require('ashita.resources')
    local snapshot_module = require('ashita.snapshot')
    local native_module = require('ashita.native')
    local ipc_module = require('ashita.ipc')
    local commands_module = require('ashita.commands')
    local keybinds_module = require('ashita.keybinds')
    local packet_decoder = require('ashita.packet_decoder')
    local composition = require('ashita.composition')

    local resources = method(resources_module, 'production', 'resources.production')(core)
    local snapshot = method(snapshot_module, 'production', 'snapshot.production')({
        core=core,
        gData=gData,
        inventory=inventory,
        resources=resources,
    })
    local native = method(native_module, 'production', 'native.production')({
        core=core,
        gData=gData,
        scheduler=scheduler,
        resources=resources,
    })
    local decoder = method(packet_decoder, 'new', 'packet_decoder.new')()

    local graph

    -- The unchanged Rahvin job owns its eight keybinds and creates them during the job-file
    -- include. Lifecycle must therefore never apply a second set. It only owns the emergency
    -- logout cleanup for translated bindings that would otherwise survive character select.
    local lifecycle_keybinds = {
        apply=function(_) return true end,
        clear=function()
            return method(keybinds_module, 'clear_bridged', 'keybinds.clear_bridged')()
        end,
    }

    -- Rahvin's own display objects are created by compat.texts and are hidden/destroyed by
    -- Rahvin's logout/file_unload paths. These lifecycle hooks are ownership fences: the
    -- outer Ashita lifecycle must not create or destroy a second renderer.
    local lifecycle_display = {
        hide=function() return true end,
        destroy=function() return true end,
    }

    local commands = method(commands_module, 'new', 'commands.new')(
        function(command)
            if not graph or not graph.engine then
                error('RahvinCompatError:profile.command_before_composition', 2)
            end
            return graph.engine.command(command)
        end,
        raw_events)

    local function ipc_factory()
        local transport = method(ipc_module, 'localhost_transport', 'ipc.localhost_transport')()
        return method(ipc_module, 'new', 'ipc.new')(transport, {
            sender=active_sender(core, gData),
        })
    end

    local function release_slots(_)
        local enable = method(gFunc, 'Enable', 'gFunc.Enable')
        for _, slot in ipairs(LAC_SLOTS) do enable(slot) end
        return true
    end

    -- Action-runtime reset, Rahvin logout events, bridge cleanup and full slot release are
    -- already separate ordered lifecycle steps. Keep this hook as an explicit ownership
    -- fence until a special subsystem gains state that is not covered by those owners.
    local function reset_special(_)
        return true
    end

    graph = method(composition, 'new', 'composition.new')({
        scheduler=scheduler,
        events=events,
        inventory=inventory,
        recasts=recasts,
        gData=gData,
        gFunc=gFunc,
        native=native,
        snapshot=snapshot,
        decoder=decoder,
        ipc_factory=ipc_factory,
        ipc_to_rahvin=method(ipc_module, 'to_rahvin', 'ipc.to_rahvin'),
        commands=commands,
        keybinds=lifecycle_keybinds,
        display=lifecycle_display,
        release_slots=release_slots,
        reset_special=reset_special,
        job_path=job_path,
    })

    local installed = need(graph.profile, 'composition.profile')
    installed._rahvings_graph = graph
    return installed
end

return profile
