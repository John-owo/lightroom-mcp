local PhotoLookup = {}

-- Resolve a list of stable Lightroom catalog identifiers to photo objects.
-- Paths are deliberately not accepted: a Master and each Virtual Copy share
-- their source path, so path lookup cannot identify one catalog photo safely.
-- Returns a parallel array:
--   results[i] = { id = inputId, photo = photoOrNil }
local function isPathIdentifier(id)
    if type(id) ~= "string" then return false end
    return id:find("/", 1, true) ~= nil
        or id:find("\\", 1, true) ~= nil
        or id:match("^[A-Za-z]:") ~= nil
end

local function validateIdentifier(id)
    if id == nil or tostring(id) == "" then
        error("Photo identity requires a stable catalog ID", 0)
    end
    if isPathIdentifier(id) then
        error("Path-only photo identity is unsupported; use catalog_id", 0)
    end
end

function PhotoLookup.resolveMany(catalog, photoIds)
    photoIds = photoIds or {}
    local results = {}
    for i, id in ipairs(photoIds) do
        validateIdentifier(id)
        results[i] = { id = id, photo = nil }
    end

    -- LrCatalog has no findPhotoByLocalIdentifier; one getAllPhotos pass
    -- builds the local-id index. localIdentifier is numeric in production but
    -- tests pass strings — normalize via tostring. Duplicate IDs are not
    -- expected in a healthy catalog; fail closed rather than choosing one.
    local byLocalId = {}
    local duplicateLocalIds = {}
    for _, p in ipairs(catalog:getAllPhotos()) do
        local lid = p.localIdentifier
        if lid ~= nil then
            local key = tostring(lid)
            if byLocalId[key] and byLocalId[key] ~= p then
                duplicateLocalIds[key] = true
                byLocalId[key] = nil
            elseif not duplicateLocalIds[key] then
                byLocalId[key] = p
            end
        end
    end

    for i, id in ipairs(photoIds) do
        local key = tostring(id)
        if duplicateLocalIds[key] then
            error("Ambiguous catalog photo ID: " .. tostring(id), 0)
        end
        results[i].photo = byLocalId[key]
    end

    return results
end

function PhotoLookup.resolveOne(catalog, photoId)
    return PhotoLookup.resolveMany(catalog, { photoId })[1].photo
end

return PhotoLookup
