local suites = {
    baseline = {'tests.baseline.test_baselines'},
    compat_sets = {'tests.compat.test_slots', 'tests.compat.test_sets'},
    modes = {'tests.compat.test_modes'},
    include = {'tests.compat.test_include'},
    phase1_primitives = {'tests.compat.test_phase1_primitives'},
    windower_unpack = {'tests.compat.test_windower_unpack'},
    snapshot = {'tests.ashita.test_snapshot'},
    lac_data = {'tests.ashita.test_lac_data'},
    equip_backend = {'tests.ashita.test_equip_backend'},
    action_runtime = {'tests.ashita.test_action_runtime'},
    pet_runtime = {'tests.ashita.test_pet_runtime'},
    command_runtime = {'tests.ashita.test_command_runtime'},
    bootstrap = {'tests.ashita.test_bootstrap'},
    state_runtime = {'tests.ashita.test_state_runtime'},
    phase2_audit = {'tests.ashita.test_phase2_audit_contracts'},
    events = {'tests.ashita.test_events'},
    scheduler = {'tests.ashita.test_scheduler'},
    scheduler_lifecycle = {'tests.ashita.test_scheduler_lifecycle'},
    packets = {'tests.ashita.test_packets'},
    packet_decoder = {'tests.ashita.test_packet_decoder'},
    th_parity = {'tests.parity.test_th'},
    ipc = {'tests.ashita.test_ipc'},
    ipc_clock = {'tests.ashita.test_ipc_clock'},
    platform = {'tests.ashita.test_platform'},
    native = {'tests.ashita.test_native'},
    resources = {'tests.ashita.test_resources'},
    extdata = {'tests.ashita.test_extdata'},
    platform_windower = {'tests.ashita.test_platform_windower_surface'},
    runtime_events = {'tests.ashita.test_runtime_events', 'tests.ashita.test_platform_event_isolation'},
    lifecycle_runtime_events = {'tests.ashita.test_lifecycle_runtime_events'},
    spellreceived_parity = {'tests.parity.test_spellreceived'},
    inventory = {'tests.ashita.test_inventory'},
    enchant_hoxne = {'tests.parity.test_enchant_hoxne'},
    settings = {'tests.ashita.test_settings'},
    settings_refusal = {'tests.parity.test_settings_refusal'},
    commands = {'tests.parity.test_commands'},
    keybinds = {'tests.ashita.test_keybinds'},
    display = {'tests.ashita.test_display'},
    texts_renderer = {'tests.ashita.test_texts_renderer'},
    lifecycle = {'tests.ashita.test_lifecycle'},
    runtime_integration = {'tests.ashita.test_lifecycle_binding', 'tests.ashita.test_bootstrap_lifecycle'},
    production_composition = {'tests.ashita.test_production_composition'},
    profile_production = {'tests.ashita.test_profile_production'},
    parity_core = {'tests.parity.test_core_sets','tests.parity.test_merge_precedence'},
    upstream_load = {'tests.contract.test_upstream_load'},
    audit_contracts = {'tests.contract.test_gearswap_slots', 'tests.contract.test_windower_surface'},
    wave2 = {'windower_unpack', 'lac_data', 'bootstrap', 'production_composition'},
    wave3 = {'upstream_load', 'production_composition'},
    wave4 = {'state_runtime', 'production_composition'},
    wave5 = {'lac_data', 'pet_runtime', 'bootstrap', 'production_composition'},
    wave6 = {'native', 'command_runtime', 'production_composition', 'commands'},
    wave7 = {'settings', 'settings_refusal'},
}
suites.all = {'baseline', 'compat_sets', 'modes', 'include', 'phase1_primitives', 'windower_unpack', 'snapshot', 'lac_data', 'equip_backend', 'action_runtime', 'pet_runtime', 'command_runtime', 'bootstrap', 'state_runtime', 'phase2_audit', 'events', 'scheduler', 'scheduler_lifecycle', 'packets', 'packet_decoder', 'th_parity', 'ipc', 'ipc_clock', 'platform', 'native', 'resources', 'extdata', 'platform_windower', 'runtime_events', 'lifecycle_runtime_events', 'spellreceived_parity', 'inventory', 'enchant_hoxne', 'settings', 'settings_refusal', 'commands', 'keybinds', 'display', 'texts_renderer', 'lifecycle', 'runtime_integration', 'production_composition', 'profile_production', 'upstream_load', 'audit_contracts', 'parity_core'}
local requested = arg[1] or 'all'
local failures, passes = 0, 0
local function run(name)
    local entries = suites[name]
    if not entries then error('unknown suite: ' .. tostring(name)) end
    for _, entry in ipairs(entries) do
        if suites[entry] then run(entry) else
            package.loaded[entry] = nil
            local loaded, test = pcall(require, entry)
            local ok, err
            if loaded then ok, err = pcall(test) else ok, err = false, test end
            if ok then passes = passes + 1; io.write('PASS ', entry, '\n')
            else failures = failures + 1; io.stderr:write('FAIL ', entry, ': ', tostring(err), '\n') end
        end
    end
end
run(requested)
io.write(('RESULT %d passed, %d failed\n'):format(passes, failures))
os.exit(failures == 0 and 0 or 1)