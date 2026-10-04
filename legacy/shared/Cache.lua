local module = {}

local CACHES = {}

function module.RegisterCache(id)
    CACHES[id] = {}
    return CACHES[id]
end

function module.ClearCache()
    for _, cache in pairs(CACHES) do
        cache = {}
    end
end

function module.Retrieve(id)
    return CACHES[id]
end

return module