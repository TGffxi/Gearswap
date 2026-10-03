local suites = {
    baseline = {'tests.baseline.test_baselines'},
    compat_sets = {'tests.compat.test_slots', 'tests.compat.test_sets'},
    modes = {'tests.compat.test_modes'},
    include = {'tests.compat.test_include'},
    snapshot = {'tests.ashita.test_snapshot'},
    upstream_load = {'tests.contract.test_upstream_load'},
}
suites.all = {'baseline', 'compat_sets', 'modes', 'include', 'snapshot', 'upstream_load'}
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
