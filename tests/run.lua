local suites = {
    baseline = {'tests.baseline.test_baselines'},
    compat_sets = {'tests.compat.test_slots', 'tests.compat.test_sets'},
    modes = {'tests.compat.test_modes'},
    include = {'tests.compat.test_include'},
    phase1_primitives = {'tests.compat.test_phase1_primitives'},
    snapshot = {'tests.ashita.test_snapshot'},
    lac_data = {'tests.ashita.test_lac_data'},
    equip_backend = {'tests.ashita.test_equip_backend'},
    action_runtime = {'tests.ashita.test_action_runtime'},
    bootstrap = {'tests.ashita.test_bootstrap'},
    state_runtime = {'tests.ashita.test_state_runtime'},
    phase2_audit = {'tests.ashita.test_phase2_audit_contracts'},
    events = {'tests.ashita.test_events'},
    scheduler = {'tests.ashita.test_scheduler'},
    parity_core = {'tests.parity.test_core_sets','tests.parity.test_merge_precedence'},
    upstream_load = {'tests.contract.test_upstream_load'},
    audit_contracts = {'tests.contract.test_gearswap_slots', 'tests.contract.test_windower_surface'},
}
suites.all = {'baseline', 'compat_sets', 'modes', 'include', 'phase1_primitives', 'snapshot', 'lac_data', 'equip_backend', 'action_runtime', 'bootstrap', 'state_runtime', 'phase2_audit', 'events', 'scheduler', 'upstream_load', 'audit_contracts', 'parity_core'}
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
