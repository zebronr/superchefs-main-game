local Cache = {}

local CACHES = {}

function Cache.RegisterCache(id)
    CACHES[id] = {}
    return CACHES[id]
end

function Cache.ClearCache()
    for _, cache in pairs(CACHES) do
        cache = {}
    end
end

function Cache.Retrieve(id)
    return CACHES[id]
end

return Cache