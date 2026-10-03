local bootstrap = require('ashita.bootstrap')

-- The installation entry point supplies the live gData/gFunc objects and the selected
-- Rahvin engine environment. Keeping construction explicit also makes reload teardown
-- deterministic and permits the same profile contract to run in the LuaJIT harness.
return function(deps)
    return bootstrap.create(deps)
end
