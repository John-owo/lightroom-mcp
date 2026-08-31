local LrApplication = import 'LrApplication'
local LrTasks = import 'LrTasks'

local PhotoLookup = require 'PhotoLookup'
local MaskAdapter = require 'MaskAdapter'
local Log = require 'Log'

local MaskHandler = {}

local function protected(fn)
    if type(LrTasks.pcall) == "function" then
        return LrTasks.pcall(fn)
    end
    return pcall(fn)
end

local function copyArray(values)
    if values == nil then return {} end
    local result = {}
    for index, value in ipairs(values) do result[index] = value end
    return result
end

local function copySelectionValue(value)
    if type(value) == "table" then return copyArray(value) end
    return value
end

local function publicIdentity(photo)
    if not photo then return nil end
    local isVirtualCopy = photo:getRawMetadata('isVirtualCopy')
    return {
        catalog_id = photo.localIdentifier and tostring(photo.localIdentifier) or nil,
        uuid = photo:getRawMetadata('uuid'),
        path = photo:getRawMetadata('path'),
        filename = photo:getFormattedMetadata('fileName'),
        copy_name = photo:getFormattedMetadata('copyName'),
        is_virtual_copy = isVirtualCopy,
    }
end

local function validIdentity(identity)
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

local function samePhotoSet(left, right)
    if type(left) ~= "table" or type(right) ~= "table" or #left ~= #right then
        return false
    end
    local matched = {}
    for _, leftPhoto in ipairs(left) do
        local found = false
        for index, rightPhoto in ipairs(right) do
            if not matched[index] and samePhoto(leftPhoto, rightPhoto) then
                matched[index] = true
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
    for index = 1, #left do
        if left[index] ~= right[index] then return false end
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
    local hasActiveSources = catalog.getActiveSources ~= nil
    return {
        targetPhoto = targetPhoto,
        targetPhotos = targetPhotos,
        activeSources = hasActiveSources
            and copySelectionValue(catalog:getActiveSources())
            or nil,
        hasActiveSources = hasActiveSources,
    }
end

local function selectionMatches(catalog, expected)
    local current = readSelection(catalog)
    local matches = false
    catalog:withReadAccessDo(function()
        matches = samePhoto(current.targetPhoto, expected.targetPhoto)
            and samePhotoSet(current.targetPhotos, expected.targetPhotos)
            and (not expected.hasActiveSources
                or sameSources(current.activeSources, expected.activeSources))
    end)
    return matches
end

local function restoreSelection(catalog, snapshot)
    local ok, err = protected(function()
        if snapshot.hasActiveSources then
            catalog:setActiveSources(snapshot.activeSources)
        end

        local otherSelected = {}
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

local function expectedSelectionMatches(catalog, photo)
    local selected = readSelection(catalog)
    local matches = false
    catalog:withReadAccessDo(function()
        matches = selected.targetPhoto ~= nil
            and samePhoto(selected.targetPhoto, photo)
            and #selected.targetPhotos == 1
            and samePhoto(selected.targetPhotos[1], photo)
    end)
    return matches
end

local function selectionStatus(status, verified, reason)
    local result = { status = status }
    if verified ~= nil then result.verified = verified end
    if reason ~= nil then result.reason = tostring(reason) end
    return result
end

local function runtimeVersion()
    if type(LrApplication.versionString) == "function" then
        local ok, value = protected(function() return LrApplication.versionString() end)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    if type(LrApplication.versionTable) == "function" then
        local ok, value = protected(function() return LrApplication.versionTable() end)
        if ok and type(value) == "table" and value.major ~= nil then
            return tostring(value.major) .. "." .. tostring(value.minor or 0)
        end
    end
    return "unknown"
end

local function presetMethod(preset, methodName)
    local method = preset and preset[methodName]
    if type(method) ~= "function" then return nil end
    local ok, value = protected(function() return method(preset) end)
    if not ok then return nil end
    return value
end

local function checkpointName(operationId)
    return "Lightroom MCP Mask Checkpoint [" .. operationId .. "]"
end

local function namedPresets(presets, name)
    local matches = {}
    for _, preset in ipairs(presets) do
        if presetMethod(preset, "getName") == name then
            table.insert(matches, preset)
        end
    end
    return matches
end

local function pluginPresets()
    if type(LrApplication.getDevelopPresetsForPlugin) ~= "function" then
        return nil, "Plugin Develop preset checkpoint API is unavailable"
    end
    local ok, presets = protected(function()
        return LrApplication.getDevelopPresetsForPlugin(_PLUGIN) or {}
    end)
    if not ok or type(presets) ~= "table" then
        return nil, "Plugin Develop preset checkpoint list could not be read"
    end
    return presets
end

local function checkpointFor(beforeSettings, operationId, operationIdentityPresent)
    local name = checkpointName(operationId)
    local presets, listError = pluginPresets()
    if not presets then return nil, nil, listError end

    local matches = namedPresets(presets, name)
    if #matches > 1 then
        return nil, nil, "Checkpoint name is ambiguous; refusing to overwrite or create"
    end

    local preset = matches[1]
    local reused = preset ~= nil
    if operationIdentityPresent and not preset then
        return nil, nil, "Operation identity already exists without a safe pre-write checkpoint"
    end
    if not preset then
        if type(LrApplication.addDevelopPresetForPlugin) ~= "function" then
            return nil, nil, "Plugin Develop preset creation API is unavailable"
        end
        local snapshot, supported = MaskAdapter.clone(beforeSettings)
        if not supported then
            return nil, nil, "Develop settings cannot be serialized for a checkpoint"
        end
        local addOk, created = protected(function()
            return LrApplication.addDevelopPresetForPlugin(_PLUGIN, name, snapshot)
        end)
        if addOk and created ~= nil then
            if presetMethod(created, "getName") ~= name then
                return nil, nil, "New mask checkpoint name readback does not match the requested operation"
            end
            preset = created
        else
            -- The API may persist the preset and then report a transport error.
            -- Re-read by exact name before exposing a failure to the caller.
            local afterErrorPresets, afterError = pluginPresets()
            if type(afterErrorPresets) == "table" then
                local persistedMatches = namedPresets(afterErrorPresets, name)
                if #persistedMatches > 1 then
                    return nil, nil, "Checkpoint name became ambiguous after creation error; refusing to guess"
                elseif #persistedMatches == 1 then
                    preset = persistedMatches[1]
                    reused = true
                end
            end
            if not preset then
                return nil, nil, "Lightroom did not create the mask checkpoint: "
                    .. tostring(created or afterError)
            end
        end
    end

    local uuid = presetMethod(preset, "getUuid")
    if type(uuid) ~= "string" or uuid == "" then
        return nil, nil, "Mask checkpoint has no stable UUID"
    end
    local rawSettings = presetMethod(preset, "getSetting")
    if type(rawSettings) ~= "table" then
        return nil, nil, "Mask checkpoint settings are unavailable"
    end
    local settings, supported = MaskAdapter.clone(rawSettings)
    if not supported then
        return nil, nil, "Mask checkpoint settings contain unsupported nested values"
    end
    if not reused and not MaskAdapter.deepEqual(settings, beforeSettings) then
        return nil, nil, "New mask checkpoint readback does not match the pre-write Develop state"
    end

    local checkpoint = {
        name = name,
        uuid = uuid,
        scope = "plugin",
        recovery_evidence = true,
        true_undo = false,
        _reused = reused,
    }
    return checkpoint, settings
end

local function readPhotoState(catalog, photo)
    local state
    catalog:withReadAccessDo(function()
        local identity = publicIdentity(photo)
        if not validIdentity(identity) then
            error("Workflow Copy has incomplete persistent identity", 0)
        end
        if not identity.is_virtual_copy then
            error("photo_id must identify a Lightroom Workflow Copy, not a Master", 0)
        end

        local master = photo:getRawMetadata('masterPhoto')
        local masterIdentity = publicIdentity(master)
        if not validIdentity(masterIdentity) then
            error("Workflow Copy Master has incomplete persistent identity", 0)
        end
        if masterIdentity.is_virtual_copy then
            error("Workflow Copy Master identity is itself a Virtual Copy", 0)
        end

        local rawSettings = photo:getDevelopSettings()
        local settings, supported = MaskAdapter.clone(rawSettings)
        if not supported then
            error("Workflow Copy Develop settings contain unsupported nested values", 0)
        end
        state = {
            identity = identity,
            master = master,
            master_identity = masterIdentity,
            settings = settings,
        }
    end)
    return state
end

local function readDevelopSettings(catalog, photo)
    local settings
    catalog:withReadAccessDo(function()
        local rawSettings = photo:getDevelopSettings()
        local cloned, supported = MaskAdapter.clone(rawSettings)
        if not supported then
            error("Workflow Copy Develop settings contain unsupported nested values", 0)
        end
        settings = cloned
    end)
    return settings
end

local function checkpointOutput(checkpoint)
    return {
        name = checkpoint.name,
        uuid = checkpoint.uuid,
        scope = checkpoint.scope,
        recovery_evidence = checkpoint.recovery_evidence,
        true_undo = checkpoint.true_undo,
    }
end

local function unsupportedResult(operationId, capability, reason)
    return {
        operation_id = operationId,
        result = "unsupported",
        capability = capability,
        selection_restoration = selectionStatus("not_needed", true),
        reason = tostring(reason),
    }
end

local function reviewResult(operationId, context, capability, checkpoint, restoration, reason, readback)
    local result = {
        operation_id = operationId,
        result = "REVIEW_REQUIRED",
        capability = capability,
        selection_restoration = restoration,
        reason = tostring(reason),
    }
    if context then
        result.photo = context.identity
        result.master = context.master_identity
    end
    if checkpoint then result.checkpoint = checkpointOutput(checkpoint) end
    if readback then
        result.mask_id = readback.mask_id
        result.correction_id = readback.correction_id
        result.name = readback.name
        result.mask_kind = readback.mask_kind
        result.kind_parameters = readback.kind_parameters
        result.initial_local_settings = readback.initial_local_settings
        result.geometry = readback.geometry
        result.preservation = readback.preservation
    end
    return result
end

local function successResult(operationId, resultKind, context, capability, checkpoint, restoration, readback)
    return {
        operation_id = operationId,
        result = resultKind,
        capability = capability,
        selection_restoration = restoration,
        photo = context.identity,
        master = context.master_identity,
        mask_id = readback.mask_id,
        correction_id = readback.correction_id,
        name = readback.name,
        mask_kind = readback.mask_kind,
        kind_parameters = readback.kind_parameters,
        initial_local_settings = readback.initial_local_settings,
        lightroom_version = capability.lightroom_version,
        process_version = capability.process_version,
        mask_schema = capability.mask_schema,
        geometry = readback.geometry,
        checkpoint = checkpointOutput(checkpoint),
        preservation = readback.preservation,
    }
end

local function tryReconcile(catalog, photo, beforeSettings, args, ids)
    local ok, currentOrError = protected(function()
        return readDevelopSettings(catalog, photo)
    end)
    if not ok then return nil, currentOrError end
    local current = currentOrError
    local reconcileOk, readback = protected(function()
        local value, err = MaskAdapter.reconcile(beforeSettings, current, args, ids)
        if not value then error(err, 0) end
        return value
    end)
    if not reconcileOk then return nil, readback end
    return readback
end

function MaskHandler.createMask(args)
    MaskAdapter.validateArguments(args)

    local catalog = LrApplication.activeCatalog()
    local photo = PhotoLookup.resolveOne(catalog, args.photo_id)
    if not photo then error("Workflow Copy not found: " .. tostring(args.photo_id), 0) end

    -- All catalog enumeration happened in PhotoLookup before this gate. The
    -- identity and Develop reads below intentionally stay inside the single
    -- SDK read gate to avoid Windows Lightroom deadlocks.
    local context = readPhotoState(catalog, photo)
    if context.identity.uuid ~= args.expected_photo_uuid then
        error("Workflow Copy UUID mismatch", 0)
    end
    if context.master_identity.uuid ~= args.expected_master_uuid then
        error("Workflow Copy Master UUID mismatch", 0)
    end

    local checkpointApiAvailable = type(LrApplication.getDevelopPresetsForPlugin) == "function"
        and type(LrApplication.addDevelopPresetForPlugin) == "function"
    local capability = MaskAdapter.capability(
        context.settings,
        runtimeVersion(),
        checkpointApiAvailable,
        type(photo.applyDevelopSettings) == "function"
    )

    if args.mask_kind ~= "brush" then
        return unsupportedResult(
            args.operation_id,
            capability,
            capability.kinds[args.mask_kind].reason
                or "AI mask creation and readback adapter is not enabled"
        )
    end
    if not capability.kinds.brush.supported then
        return unsupportedResult(
            args.operation_id,
            capability,
            capability.kinds.brush.reason or "Brush mask adapter is unavailable"
        )
    end

    local ids = MaskAdapter.identities(args)
    local operationIdentityPresent = MaskAdapter.hasOperationIdentity(context.settings, ids)
    local checkpoint, checkpointSettings, checkpointError = checkpointFor(
        context.settings,
        args.operation_id,
        operationIdentityPresent
    )
    if not checkpoint then
        if operationIdentityPresent then
            return reviewResult(
                args.operation_id,
                context,
                capability,
                nil,
                selectionStatus("not_attempted", false),
                checkpointError
            )
        end
        return unsupportedResult(args.operation_id, capability, checkpointError)
    end

    local beforeSettings = context.settings
    if checkpoint._reused then
        beforeSettings = checkpointSettings
        if MaskAdapter.hasOperationIdentity(beforeSettings, ids) then
            return reviewResult(
                args.operation_id,
                context,
                capability,
                checkpoint,
                selectionStatus("not_attempted", false),
                "Checkpoint already contains this operation identity; refusing to guess its ownership"
            )
        end

        local priorReadback = MaskAdapter.reconcile(
            beforeSettings,
            context.settings,
            args,
            ids
        )
        if priorReadback then
            return successResult(
                args.operation_id,
                "reconciled",
                context,
                capability,
                checkpoint,
                selectionStatus("not_needed", true),
                priorReadback
            )
        end
        if not MaskAdapter.deepEqual(beforeSettings, context.settings) then
            return reviewResult(
                args.operation_id,
                context,
                capability,
                checkpoint,
                selectionStatus("not_attempted", false),
                "Existing checkpoint does not match the current Workflow Copy state"
            )
        end
    end

    local correction = MaskAdapter.buildCorrection(args, ids)
    local snapshot = readSelection(catalog)
    if snapshot.targetPhoto == nil then
        return reviewResult(
            args.operation_id,
            context,
            capability,
            checkpoint,
            selectionStatus("not_attempted", false),
            "Cannot create a mask without a restorable active Lightroom selection"
        )
    end

    local mutationStarted = false
    local operationOk, operationResult = protected(function()
        catalog:setSelectedPhotos(photo, {})
        if not expectedSelectionMatches(catalog, photo) then
            error("Selection changed before mask creation", 0)
        end

        local liveBeforeSettings = readDevelopSettings(catalog, photo)
        if not MaskAdapter.deepEqual(liveBeforeSettings, context.settings) then
            error("Develop settings changed before mask creation", 0)
        end
        local updatedSettings = MaskAdapter.appendCorrection(liveBeforeSettings, correction)
        mutationStarted = true
        catalog:withWriteAccessDo("Create Lightroom Mask", function()
            photo:applyDevelopSettings(updatedSettings)
        end)

        local readback, reconcileError = tryReconcile(
            catalog,
            photo,
            liveBeforeSettings,
            args,
            ids
        )
        if not readback then error(reconcileError, 0) end
        return readback
    end)

    local restoreOk, restoreError = restoreSelection(catalog, snapshot)
    local restoration = restoreOk
        and selectionStatus("restored", true)
        or selectionStatus("failed", false, restoreError)

    if not operationOk then
        if mutationStarted then
            -- Treat an SDK timeout/error after apply as an uncertain commit.
            -- A successful readback is a reconciliation, never a blind retry.
            local readback = tryReconcile(catalog, photo, context.settings, args, ids)
            if readback and restoreOk then
                Log.warn("Mask write reported an error but readback reconciled the operation")
                return successResult(
                    args.operation_id,
                    "reconciled",
                    context,
                    capability,
                    checkpoint,
                    restoration,
                    readback
                )
            end
            return reviewResult(
                args.operation_id,
                context,
                capability,
                checkpoint,
                restoration,
                "Mask write requires review: " .. tostring(operationResult),
                readback
            )
        end
        return reviewResult(
            args.operation_id,
            context,
            capability,
            checkpoint,
            restoration,
            "Mask creation was not started: " .. tostring(operationResult)
        )
    end

    if not restoreOk then
        return reviewResult(
            args.operation_id,
            context,
            capability,
            checkpoint,
            restoration,
            "Mask was read back but the prior Lightroom selection could not be verified",
            operationResult
        )
    end

    return successResult(
        args.operation_id,
        "created",
        context,
        capability,
        checkpoint,
        restoration,
        operationResult
    )
end

return MaskHandler
