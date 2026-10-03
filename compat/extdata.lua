local M = {}
function M.new(platform)
    return {decode=function(item)
        if not platform or not platform.decode_item then error('RahvinCompatError:extdata.decode', 2) end
        local raw = item
        if type(item) == 'table' and item.raw ~= nil then raw = item.raw end
        return platform:decode_item(raw)
    end}
end
return M
