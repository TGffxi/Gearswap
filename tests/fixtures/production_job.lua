-- Minimal Rahvin job fixture for the production-composition contract.
-- It deliberately loads the unchanged upstream engine through the same include path a real
-- job file uses, but avoids job-specific gear data so the contract stays about composition.
include('RahvinGS/Rahvin-Engine')

function get_sets()
    production_fixture_loads = (production_fixture_loads or 0) + 1
    sets.Idle = {head='Composition Helm'}
end

function user_file_unload()
    production_fixture_unloads = (production_fixture_unloads or 0) + 1
end
