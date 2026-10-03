local copy = require('compat.sets').copy
local M = {}
function M.new(platform)
    platform = platform or {}
    return {
        load=function(path, defaults)
            if platform.load_config then return platform:load_config(path, copy(defaults)) end
            return copy(defaults)
        end,
        save=function(value) if not platform.save_config then error('RahvinCompatError:config.save', 2) end; return platform:save_config(value) end,
    }
end
return M
