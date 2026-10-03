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

return profile
