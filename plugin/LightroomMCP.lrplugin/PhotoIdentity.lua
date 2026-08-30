local PhotoIdentity = {}

-- Lightroom's localIdentifier is the catalog-local stable ID exposed by the
-- Classic SDK. Keep the existing `id` field for compatibility, while
-- exposing a string `catalog_id` for callers that persist JSON identities.
local function catalogId(photo)
    if not photo or photo.localIdentifier == nil then return nil end
    return tostring(photo.localIdentifier)
end

local function identityFields(photo)
    if not photo then return nil end

    local isVirtualCopy = photo:getRawMetadata('isVirtualCopy')
    if type(isVirtualCopy) ~= "boolean" then
        error("Photo identity is uncertain: isVirtualCopy must be boolean", 0)
    end

    return {
        catalog_id = catalogId(photo),
        uuid = photo:getRawMetadata('uuid'),
        copy_name = photo:getFormattedMetadata('copyName'),
        is_virtual_copy = isVirtualCopy,
    }
end

local function photoReference(photo)
    if not photo then return nil end

    local reference = {
        id = photo.localIdentifier,
        path = photo:getRawMetadata('path'),
        filename = photo:getFormattedMetadata('fileName'),
    }
    for key, value in pairs(identityFields(photo)) do
        reference[key] = value
    end
    return reference
end

function PhotoIdentity.describe(photo)
    local reference = identityFields(photo)
    if not reference then return nil end

    local master = photo:getRawMetadata('masterPhoto')
    local masterReference = photoReference(master)
    local virtualCopies = {}
    local copyCount = photo:getRawMetadata('countVirtualCopies')

    -- Lightroom returns virtualCopies for a Master and no copies for a
    -- Virtual Copy. The explicit status check also keeps malformed SDK data
    -- from making a copy appear to own another copy list.
    if not reference.is_virtual_copy then
        for _, copy in ipairs(photo:getRawMetadata('virtualCopies') or {}) do
            table.insert(virtualCopies, photoReference(copy))
        end
        if #virtualCopies > 0 then
            reference.virtual_copies = virtualCopies
        end
    end

    reference.master = masterReference
    reference.master_id = masterReference and masterReference.catalog_id or nil
    reference.master_uuid = masterReference and masterReference.uuid or nil
    reference.virtual_copy_count = copyCount or #virtualCopies
    return reference
end

function PhotoIdentity.enrich(result, photo)
    local identity = PhotoIdentity.describe(photo)
    if not identity then return result end
    for key, value in pairs(identity) do
        result[key] = value
    end
    return result
end

return PhotoIdentity
