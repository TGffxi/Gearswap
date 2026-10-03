local M = {}
function M.new(platform)
    return {decode=function(item)
        if not platform or not platform.decode_item then error('RahvinCompatError:extdata.decode', 2) end
        return platform:decode_item(item)
    end}
end
return M
