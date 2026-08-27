local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'

local PhotoLookup = require 'PhotoLookup'
local Log = require 'Log'

local VirtualCopyHandler = {}

-- The marker is the only durable operation key written into the new Copy's
-- name. operation_id is validated below with the same ASCII grammar exposed
-- by the MCP input schema; paths and request IDs never participate in
-- reconciliation.
local MARKER_PREFIX = "Lightroom MCP VC ["
local MARKER_SUFFIX = "]"
local MAX_OPERATION_ID_LENGTH = 64

local function copyArray(values)
    if values == nil then return {} end
    if type(values) ~= "table" then
        error("Lightroom selection must be an array", 0)
    end
    local result = {}
    for i, value in ipairs(values) do
        result[i] = value
    end
    return result
end

local function copySelectionValue(value)
    if type(value) == "table" then
        return copyArray(value)
    end
    return value
end

local function isValidOperationId(operationId)
    return type(operationId) == "string"
        and #operationId >= 1
        and #operationId <= MAX_OPERATION_ID_LENGTH
        and operationId:match("^[A-Za-z0-9][A-Za-z0-9%._%-]*$") ~= nil
end

local function markerFor(operationId)
    return MARKER_PREFIX .. operationId .. MARKER_SUFFIX
end

-- Keep the public identity deliberately slim. PhotoIdentity.describe is
-- useful for metadata tools, but it also expands relationship fields. This
-- mutation tool returns only the typed identity reference promised by its MCP
-- output schema, while all relationship checks below use official SDK keys.
local function publicIdentity(photo)
    if not photo then return nil end
    local virtualCopyStatus = photo:getRawMetadata('isVirtualCopy')
    return {
        catalog_id = photo.localIdentifier and tostring(photo.localIdentifier) or nil,
        uuid = photo:getRawMetadata('uuid'),
        path = photo:getRawMetadata('path'),
        filename = photo:getFormattedMetadata('fileName'),
        copy_name = photo:getFormattedMetadata('copyName'),
        is_virtual_copy = virtualCopyStatus,
    }
end

local function usableIdentity(identity)
    return identity ~= nil
        and type(identity.catalog_id) == "string"
        and identity.catalog_id ~= ""
        and type(identity.uuid) == "string"
        and identity.uuid ~= ""
        and type(identity.is_virtual_copy) == "boolean"
end

local function samePhoto(left, right)
    if not left or not right then return false end
    if left.localIdentifier == nil or right.localIdentifier == nil then return false end
    if tostring(left.localIdentifier) ~= tostring(right.localIdentifier) then return false end
    local leftUuid = left:getRawMetadata('uuid')
    local rightUuid = right:getRawMetadata('uuid')
    return type(leftUuid) == "string" and leftUuid ~= ""
        and leftUuid == rightUuid
end

local function sameOptionalPhoto(left, right)
    if left == nil or right == nil then return left == right end
    return samePhoto(left, right)
end

local function samePhotoSet(left, right)
    if type(left) ~= "table" or type(right) ~= "table" or #left ~= #right then
        return false
    end
    local matched = {}
    for i = 1, #left do
        local found = false
        for j = 1, #right do
            if not matched[j] and samePhoto(left[i], right[j]) then
                matched[j] = true
                found = true
                break
            end
        end
        if not found then return false end
    end
    return true
end

local function sameSources(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    if #left ~= #right then return false end
    for i = 1, #left do
        if left[i] ~= right[i] then return false end
    end
    return true
end

local function readSelection(catalog)
    local targetPhotos = copyArray(catalog:getTargetPhotos() or {})
    local targetPhoto = nil
    if catalog.getTargetPhoto then
        targetPhoto = catalog:getTargetPhoto()
    elseif #targetPhotos > 0 then
        targetPhoto = targetPhotos[1]
    end
    local activeSources = nil
    local hasActiveSources = catalog.getActiveSources ~= nil
    if hasActiveSources then
        activeSources = copySelectionValue(catalog:getActiveSources())
    end
    return {
        targetPhoto = targetPhoto,
        targetPhotos = targetPhotos,
        activeSources = activeSources,
        hasActiveSources = hasActiveSources,
    }
end

local function selectionMatches(catalog, expected)
    -- getTargetPhotos/getTargetPhoto are UI-facing calls and must stay outside
    -- the catalog read gate on Windows. Only the identity comparisons below
    -- enter the gate.
    local current = readSelection(catalog)
    local matches = false
    catalog:withReadAccessDo(function()
        matches = sameOptionalPhoto(current.targetPhoto, expected.targetPhoto)
            and samePhotoSet(current.targetPhotos, expected.targetPhotos)
            and (not expected.hasActiveSources
                or sameSources(current.activeSources, expected.activeSources))
    end)
    return matches
end

local function setExpectedMaster(catalog, master)
    -- LrCatalog:setSelectedPhotos takes the active photo first and the other
    -- selected photos second. The empty second array is intentional: the
    -- createVirtualCopies operation must run for exactly this Master.
    catalog:setSelectedPhotos(master, {})
end

local function restoreSelection(catalog, snapshot)
    local ok, err = LrTasks.pcall(function()
        if snapshot.hasActiveSources then
            catalog:setActiveSources(snapshot.activeSources)
        end

        local otherSelected = {}
        -- samePhoto reads persistent UUID metadata. Keep that per-photo read
        -- inside the catalog gate; only the UI mutation itself runs outside
        -- it, matching the Lightroom SDK deadlock boundary.
        catalog:withReadAccessDo(function()
            if snapshot.targetPhoto then
                for _, photo in ipairs(snapshot.targetPhotos) do
                    if not samePhoto(photo, snapshot.targetPhoto) then
                        table.insert(otherSelected, photo)
                    end
                end
            end
        end)
        catalog:setSelectedPhotos(snapshot.targetPhoto, otherSelected)

        if not selectionMatches(catalog, snapshot) then
            error("Selection restoration readback mismatch", 0)
        end
    end)
    return ok, err
end

local function markerCandidates(allPhotos, master, marker)
    local candidates = {}
    for _, copy in ipairs(allPhotos) do
        local copyName = copy:getFormattedMetadata('copyName')
        -- Exact marker names are evidence even when the status field is
        -- malformed or unexpectedly says Master. That ambiguity must block a
        -- second creation rather than disappear from the reconciliation scan.
        if copyName == marker then
            local identity = publicIdentity(copy)
            local relation = copy:getRawMetadata('masterPhoto')
            local relationMatches = relation ~= nil and samePhoto(relation, master)
            local verified = usableIdentity(identity)
                and identity.is_virtual_copy
                and relationMatches
            table.insert(candidates, {
                photo = copy,
                identity = identity,
                verified = verified,
            })
        end
    end
    return candidates
end

local function identityList(candidates)
    local result = {}
    for _, candidate in ipairs(candidates or {}) do
        if usableIdentity(candidate.identity) then
            table.insert(result, candidate.identity)
        end
    end
    return result
end

local function selectionStatus(status, verified, reason)
    local result = { status = status }
    if verified ~= nil then result.verified = verified end
    if reason ~= nil then result.reason = tostring(reason) end
    return result
end

local function reviewResult(operationId, marker, sourceIdentity, candidates, reason, restoration, copyIdentity, partial)
    local result = {
        operation_id = operationId,
        marker = marker,
        result = "REVIEW_REQUIRED",
        partial = partial ~= false,
        source = sourceIdentity,
        master = sourceIdentity,
        candidates = identityList(candidates),
        candidate_count = #(candidates or {}),
        selection_restoration = restoration,
        reason = tostring(reason),
    }
    if copyIdentity and usableIdentity(copyIdentity) then
        result.copy = copyIdentity
        result.is_virtual_copy = copyIdentity.is_virtual_copy
    end
    return result
end

local function scanAfterPossibleCreate(catalog, master, marker, returnedCopies)
    local candidates = {}
    local scanOk, scanResult = LrTasks.pcall(function()
        local allPhotos = copyArray(catalog:getAllPhotos() or {})
        local found
        catalog:withReadAccessDo(function()
            found = markerCandidates(allPhotos, master, marker)
        end)
        return found
    end)
    if scanOk then candidates = scanResult end

    for _, returnedCopy in ipairs(returnedCopies or {}) do
        local identityOk, identity = LrTasks.pcall(function()
            local value
            catalog:withReadAccessDo(function()
                value = publicIdentity(returnedCopy)
            end)
            return value
        end)
        if identityOk and usableIdentity(identity) then
            local alreadyIncluded = false
            for _, candidate in ipairs(candidates) do
                if candidate.identity
                    and candidate.identity.catalog_id == identity.catalog_id
                    and candidate.identity.uuid == identity.uuid then
                    alreadyIncluded = true
                    break
                end
            end
            if not alreadyIncluded then
                table.insert(candidates, {
                    photo = returnedCopy,
                    identity = identity,
                    verified = false,
                })
            end
        end
    end
    return candidates
end

local function validateArgs(args)
    if type(args) ~= "table" then error("Arguments are required", 0) end
    if args.source_photo_id == nil then error("source_photo_id is required", 0) end
    if type(args.expected_source_uuid) ~= "string" or args.expected_source_uuid == "" then
        error("expected_source_uuid must be a non-empty string", 0)
    end
    if not isValidOperationId(args.operation_id) then
        error("operation_id must be a 1-64 character ASCII token", 0)
    end
end

function VirtualCopyHandler.createVirtualCopy(args)
    validateArgs(args)

    local catalog = LrApplication.activeCatalog()
    local operationId = args.operation_id
    local marker = markerFor(operationId)

    -- Resolve the source by the stable local catalog ID before any selection
    -- or write operation. PhotoLookup also rejects path-only/ambiguous IDs.
    local source = PhotoLookup.resolveOne(catalog, args.source_photo_id)
    if not source then
        error("Source photo not found: " .. tostring(args.source_photo_id), 0)
    end

    local sourceIdentity
    local candidates
    -- Reconciliation is catalog-wide: a marker left on another Master is
    -- still evidence that this operation already ran and must not be replaced
    -- by a blind second creation for a different source argument.
    local allPhotos = copyArray(catalog:getAllPhotos() or {})
    catalog:withReadAccessDo(function()
        sourceIdentity = publicIdentity(source)
        if not usableIdentity(sourceIdentity) then
            error("Source photo has incomplete persistent identity", 0)
        end
        if sourceIdentity.uuid ~= args.expected_source_uuid then
            error("Source UUID mismatch", 0)
        end
        if sourceIdentity.is_virtual_copy then
            error("Source photo must be a Master, not a Virtual Copy", 0)
        end
        candidates = markerCandidates(allPhotos, source, marker)
    end)

    -- Reconcile before touching the UI selection. Any marker-bearing entry
    -- must be unambiguous and relation-verified; otherwise fail closed rather
    -- than creating a second Copy after an uncertain prior request.
    if #candidates > 0 then
        if #candidates == 1 and candidates[1].verified
            and usableIdentity(candidates[1].identity) then
            local copyIdentity = candidates[1].identity
            return {
                operation_id = operationId,
                marker = marker,
                result = "reconciled",
                partial = false,
                source = sourceIdentity,
                master = sourceIdentity,
                copy = copyIdentity,
                is_virtual_copy = true,
                selection_restoration = selectionStatus("not_needed", true),
            }
        end
        return reviewResult(
            operationId,
            marker,
            sourceIdentity,
            candidates,
            "Operation marker is ambiguous or its Copy/Master identity could not be verified",
            selectionStatus("not_attempted", false)
        )
    end

    -- Snapshot all UI state before changing selection. The snapshot is held
    -- through every path below so even SDK errors after createVirtualCopies
    -- get a best-effort restoration and explicit readback result.
    local snapshot = readSelection(catalog)
    if snapshot.targetPhoto == nil then
        error("Cannot create a Virtual Copy without a restorable active photo", 0)
    end
    local returnedCopies = {}
    local mutationStarted = false
    local copyIdentity = nil

    local operationOk, operationResult = LrTasks.pcall(function()
        setExpectedMaster(catalog, source)

        local selected = readSelection(catalog)
        local selectionOk = false
        catalog:withReadAccessDo(function()
            selectionOk = selected.targetPhoto ~= nil
                and samePhoto(selected.targetPhoto, source)
                and #selected.targetPhotos == 1
                and samePhoto(selected.targetPhotos[1], source)
        end)
        if not selectionOk then
            error("Selection changed before Virtual Copy creation", 0)
        end

        -- From this point onward Lightroom may have applied the mutation even
        -- if the SDK raises or returns malformed data. All failures therefore
        -- retain/report any discoverable Copy instead of pretending rollback.
        mutationStarted = true
        local created
        -- The SDK documents createVirtualCopies as an asynchronous-task API;
        -- it does not require a withWriteAccessDo transaction. Calling it
        -- directly also avoids a nested UI mutation gate whose rollback/error
        -- timing could hide returned Copy evidence.
        created = catalog:createVirtualCopies(marker)
        if type(created) == "table" then
            returnedCopies = created
        end
        if type(created) ~= "table" or #created ~= 1 or created[1] == nil then
            error("createVirtualCopies did not return exactly one Copy", 0)
        end
        local createdCopy = created[1]

        catalog:withReadAccessDo(function()
            copyIdentity = publicIdentity(createdCopy)
            if not usableIdentity(copyIdentity) then
                error("Created Virtual Copy has incomplete persistent identity", 0)
            end
            if not copyIdentity.is_virtual_copy then
                error("Created photo is not a Virtual Copy", 0)
            end
            if type(copyIdentity.copy_name) ~= "string"
                or copyIdentity.copy_name ~= marker then
                error("Created Virtual Copy marker readback mismatch", 0)
            end
            local relation = createdCopy:getRawMetadata('masterPhoto')
            if relation == nil or not samePhoto(relation, source) then
                error("Created Virtual Copy Master relation mismatch", 0)
            end
            local relationIdentity = publicIdentity(relation)
            if not usableIdentity(relationIdentity)
                or relationIdentity.uuid ~= args.expected_source_uuid
                or relationIdentity.is_virtual_copy then
                error("Created Virtual Copy Master UUID/status mismatch", 0)
            end
        end)

        return copyIdentity
    end)

    local restoreOk, restoreErr = restoreSelection(catalog, snapshot)
    local restoration = restoreOk
        and selectionStatus("restored", true)
        or selectionStatus("failed", false, restoreErr)

    if not operationOk then
        if not mutationStarted then
            local reason = "Virtual Copy creation was not started: " .. tostring(operationResult)
            if not restoreOk then
                -- The catalog is untouched, but the UI selection is not
                -- trustworthy. Preserve that boundary as structured review
                -- evidence instead of losing it in a transport exception.
                return reviewResult(
                    operationId,
                    marker,
                    sourceIdentity,
                    {},
                    reason .. "; selection restoration failed: " .. tostring(restoreErr),
                    restoration,
                    nil,
                    false
                )
            end
            -- Selection ownership began, but readback found drift before the
            -- catalog mutation. This is an uncertain workflow boundary: keep
            -- the caller on the structured REVIEW_REQUIRED path even though
            -- no Copy was created, so generic retry logic cannot run.
            return reviewResult(
                operationId,
                marker,
                sourceIdentity,
                {},
                reason,
                restoration,
                nil,
                false
            )
        end

        local possibleCopies = scanAfterPossibleCreate(catalog, source, marker, returnedCopies)
        Log.warn("Virtual Copy creation requires review: " .. tostring(operationResult))
        return reviewResult(
            operationId,
            marker,
            sourceIdentity,
            possibleCopies,
            operationResult,
            restoration,
            copyIdentity,
            true
        )
    end

    if not restoreOk then
        Log.warn("Virtual Copy created but selection restoration requires review: " .. tostring(restoreErr))
        return reviewResult(
            operationId,
            marker,
            sourceIdentity,
            scanAfterPossibleCreate(catalog, source, marker, returnedCopies),
            "Virtual Copy created but prior selection could not be verified: " .. tostring(restoreErr),
            restoration,
            copyIdentity,
            true
        )
    end

    return {
        operation_id = operationId,
        marker = marker,
        result = "created",
        partial = false,
        source = sourceIdentity,
        master = sourceIdentity,
        copy = copyIdentity,
        is_virtual_copy = true,
        selection_restoration = restoration,
    }
end

return VirtualCopyHandler
