local helper = require 'spec_helper'
local MaskAdapter = require 'MaskAdapter'

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

local function baseDevelopSettings()
    return {
        ProcessVersion = "11.0",
        EnableMaskGroupBasedCorrections = true,
        Exposure2012 = 0.25,
        Contrast2012 = -4,
        MaskGroupBasedCorrections = {
            {
                CorrectionActive = true,
                CorrectionName = "Existing mask",
                CorrectionSyncID = "existing-correction",
                CorrectionMasks = {
                    {
                        What = "Mask/Paint",
                        MaskActive = true,
                        MaskName = "Existing mask",
                        MaskSyncID = "existing-mask",
                        Dabs = { "d 0.1 0.2" },
                        Radius = 0.08,
                        Flow = 1,
                        CenterWeight = 0.5,
                    },
                },
                LocalExposure2012 = 0,
            },
        },
    }
end

local function masterMeta(overrides)
    local meta = {
        id = "100",
        uuid = "uuid-master",
        path = "/相片/夕陽.jpg",
        fileName = "夕陽.jpg",
        copyName = "",
        isVirtualCopy = false,
    }
    for key, value in pairs(overrides or {}) do meta[key] = value end
    return meta
end

local function copyMeta(master, overrides)
    local meta = {
        id = "101",
        uuid = "uuid-copy",
        path = "/相片/夕陽.jpg",
        fileName = "夕陽.jpg",
        copyName = "Workflow Copy",
        isVirtualCopy = true,
        masterPhoto = master,
        developSettings = baseDevelopSettings(),
    }
    for key, value in pairs(overrides or {}) do meta[key] = value end
    return meta
end

local function fakePreset(name, settings, uuid)
    return {
        getName = function() return name end,
        getUuid = function() return uuid or ("checkpoint-" .. name) end,
        getSetting = function() return settings end,
    }
end

local function setup(opts)
    opts = opts or {}
    local master = helper.fakePhoto(masterMeta())
    local copy = helper.fakePhoto(copyMeta(master, opts.copy))
    local other = helper.fakePhoto({
        id = "200", uuid = "uuid-other", path = "/其他.jpg",
        fileName = "其他.jpg", isVirtualCopy = false,
        developSettings = { ProcessVersion = "11.0" },
    })
    local catalog = helper.fakeCatalog({
        photos = { master, copy, other },
        targetPhotos = { other },
        targetPhoto = other,
        activeSources = { "old-folder" },
        rejectMetadataOutsideReadAccess = true,
    })
    local pluginPresets = opts.pluginPresets or {}
    local addedPresetCalls = 0
    local application = {
        activeCatalog = function() return catalog end,
        versionString = function() return opts.lightroomVersion or "13.0" end,
        getDevelopPresetsForPlugin = function() return pluginPresets end,
        addDevelopPresetForPlugin = function(_, name, settings)
            addedPresetCalls = addedPresetCalls + 1
            local preset = fakePreset(
                name,
                clone(opts.checkpointSettings or settings),
                "checkpoint-" .. tostring(addedPresetCalls)
            )
            table.insert(pluginPresets, preset)
            return preset
        end,
    }
    local originalApply = copy.applyDevelopSettings
    copy.applyDevelopSettings = function(photo, settings)
        local result = originalApply(photo, settings)
        copy.__meta.developSettings = clone(settings)
        if opts.failAfterApply then error("SDK timeout after mask write", 0) end
        return result
    end
    local originalModule = opts.currentModule or "library"
    local currentModule = originalModule
    local moduleSwitches = {}
    local subjectCreateCalls = 0
    local function defaultSubjectCorrection()
        return {
            What = "Correction",
            CorrectionActive = true,
            CorrectionAmount = 1,
            CorrectionName = "Subject 1",
            CorrectionSyncID = "lightroom-subject-correction",
            CorrectionMasks = {
                {
                    What = "Mask/Image",
                    MaskActive = true,
                    MaskName = "Subject 1",
                    MaskBlendMode = 0,
                    MaskInverted = false,
                    MaskSyncID = "lightroom-subject-mask",
                    MaskValue = 1,
                    MaskVersion = 1,
                    MaskSubType = 1,
                    ReferencePoint = "0.500000 0.500000",
                    ErrorReason = 0,
                    OpaqueImagePayload = "generated-by-lightroom",
                },
            },
        }
    end
    local applicationView = {
        getCurrentModuleName = function() return currentModule end,
        switchToModule = function(name)
            table.insert(moduleSwitches, name)
            if opts.failModuleSwitch then error("module switch failed", 0) end
            if opts.failModuleRestore and name == originalModule then
                error("module restore failed", 0)
            end
            currentModule = name
            if opts.onSwitchModule then
                opts.onSwitchModule(name, catalog, copy, other)
            end
        end,
    }
    local developController = {}
    if opts.subjectControllerAvailable ~= false then
        developController.createNewMask = function(category, kind)
            subjectCreateCalls = subjectCreateCalls + 1
            assert.are.equal("aiSelection", category)
            assert.are.equal("subject", kind)
            if opts.subjectControllerFailure == "before" then
                error("subject controller failed before creation", 0)
            end
            local additions = opts.subjectAdditions or { defaultSubjectCorrection() }
            for _, correction in ipairs(additions) do
                table.insert(copy.__meta.developSettings.MaskGroupBasedCorrections, clone(correction))
            end
            if opts.subjectControllerFailure == "after" then
                error("subject controller timeout after creation", 0)
            end
        end
    end
    helper.installImport({
        LrApplication = application,
        LrApplicationView = applicationView,
        LrDevelopController = developController,
        LrTasks = { pcall = pcall, sleep = function() end },
        LrLogger = helper.defaultLrLogger(),
    })
    package.loaded.HandlerMask = nil
    package.loaded.Log = nil
    return catalog, master, copy, other, require 'HandlerMask', {
        pluginPresets = pluginPresets,
        getAddedPresetCalls = function() return addedPresetCalls end,
        getSubjectCreateCalls = function() return subjectCreateCalls end,
        getCurrentModule = function() return currentModule end,
        getModuleSwitches = function() return moduleSwitches end,
        defaultSubjectCorrection = defaultSubjectCorrection,
    }
end

local function brushArgs(overrides)
    local args = {
        photo_id = "101",
        expected_photo_uuid = "uuid-copy",
        expected_master_uuid = "uuid-master",
        operation_id = "mask-op-001",
        mask_kind = "brush",
        name = "Face lift",
        kind_parameters = {
            coordinate_system = "normalized_image",
            coordinate_units = "unit_interval",
            path = { { x = 0.2, y = 0.3 }, { x = 0.4, y = 0.5 } },
            size = 0.12,
            feather = 0.35,
            flow = 0.7,
            density = 0.8,
        },
        local_settings = { exposure = 0.5, clarity = 12 },
    }
    for key, value in pairs(overrides or {}) do args[key] = value end
    return args
end

local function subjectArgs(overrides)
    local args = brushArgs({
        operation_id = "subject-op-001",
        mask_kind = "subject",
        name = "Squirrel subject lift",
        kind_parameters = {},
        local_settings = { exposure = 0.75 },
    })
    for key, value in pairs(overrides or {}) do args[key] = value end
    return args
end

local function subjectCheckpointName(args)
    return "Lightroom MCP Mask Checkpoint [" .. args.operation_id
        .. "] [request:" .. MaskAdapter.requestFingerprint(args) .. "]"
end

describe("HandlerMask.createMask", function()
    it("creates one verified Brush on a Workflow Copy, checkpoints, preserves global settings, and restores selection", function()
        local catalog, master, copy, other, Handler, state = setup()
        local before = clone(copy.__meta.developSettings)

        local result = Handler.createMask(brushArgs())

        assert.are.equal("created", result.result)
        assert.are.equal("mask-op-001", result.operation_id)
        assert.are.equal("uuid-copy", result.photo.uuid)
        assert.is_true(result.photo.is_virtual_copy)
        assert.are.equal("uuid-master", result.master.uuid)
        assert.is_false(result.master.is_virtual_copy)
        assert.are.equal("brush", result.mask_kind)
        assert.are.equal("Face lift", result.name)
        assert.are.equal(2, result.geometry.point_count)
        assert.are.equal(0.4, result.geometry.bounds.x_max)
        assert.are.equal("unit_interval", result.geometry.coordinate_units)
        assert.is_true(result.checkpoint.recovery_evidence)
        assert.is_false(result.checkpoint.true_undo)
        assert.is_true(result.preservation.exactly_one_mask_added)
        assert.is_true(result.preservation.existing_mask_tree_unchanged)
        assert.is_true(result.preservation.global_develop_unchanged)
        assert.is_true(result.preservation.source_untouched)
        assert.is_true(result.preservation.sidecar_untouched)
        assert.are.equal("restored", result.selection_restoration.status)
        assert.is_true(result.selection_restoration.verified)
        assert.are.equal(other, catalog:getTargetPhoto())
        assert.are.same({ other }, catalog:getTargetPhotos())
        assert.are.same({ "old-folder" }, catalog:getActiveSources())
        assert.are.equal(1, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
        assert.are.equal(before.Exposure2012, copy.__meta.developSettings.Exposure2012)
        assert.are.equal(before.Contrast2012, copy.__meta.developSettings.Contrast2012)
        assert.are.equal(2, #copy.__meta.developSettings.MaskGroupBasedCorrections)
        assert.are.equal("existing-correction", copy.__meta.developSettings.MaskGroupBasedCorrections[1].CorrectionSyncID)
    end)

    it("creates the first Brush when Lightroom has not materialized the empty mask schema", function()
        local catalog, _, copy, _, Handler, state = setup({
            lightroomVersion = "15.5.1",
            copy = {
                developSettings = {
                    ProcessVersion = "15.4",
                    EnableMaskGroupBasedCorrections = true,
                    Exposure2012 = 0.5,
                    Contrast2012 = 15,
                },
            },
        })

        local result = Handler.createMask(brushArgs({
            operation_id = "first-mask-001",
            local_settings = { exposure = 0.5 },
        }))

        assert.are.equal("created", result.result)
        assert.is_true(result.capability.kinds.brush.supported)
        assert.are.equal("MaskGroupBasedCorrections.v1", result.mask_schema)
        assert.are.equal(1, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
        assert.is_true(copy.__meta.developSettings.EnableMaskGroupBasedCorrections)
        assert.are.equal(1, #copy.__meta.developSettings.MaskGroupBasedCorrections)
        assert.are.equal(result.correction_id, copy.__meta.developSettings.MaskGroupBasedCorrections[1].CorrectionSyncID)
        assert.are.equal(0.5, copy.__meta.developSettings.Exposure2012)
        assert.are.equal(15, copy.__meta.developSettings.Contrast2012)
        assert.is_true(result.preservation.existing_mask_tree_unchanged)
        assert.is_true(result.preservation.global_develop_unchanged)
    end)

    it("keeps an unmaterialized or partial mask schema fail-closed outside the live-verified version pair", function()
        local cases = {
            {
                lightroomVersion = "15.6",
                developSettings = {
                    ProcessVersion = "15.4",
                    EnableMaskGroupBasedCorrections = true,
                },
            },
            {
                lightroomVersion = "15.5.1",
                developSettings = {
                    ProcessVersion = "15.5",
                    EnableMaskGroupBasedCorrections = true,
                },
            },
            {
                lightroomVersion = "15.5.1",
                developSettings = { ProcessVersion = "15.4" },
            },
            {
                lightroomVersion = "15.5.1",
                developSettings = {
                    ProcessVersion = "15.4",
                    MaskGroupBasedCorrections = {},
                },
            },
            {
                lightroomVersion = "15.5.1",
                developSettings = {
                    ProcessVersion = "15.4",
                    EnableMaskGroupBasedCorrections = false,
                    MaskGroupBasedCorrections = {},
                },
            },
        }

        for index, item in ipairs(cases) do
            local catalog, _, _, _, Handler, state = setup({
                lightroomVersion = item.lightroomVersion,
                copy = { developSettings = item.developSettings },
            })
            local result = Handler.createMask(brushArgs({
                operation_id = "unverified-empty-schema-" .. tostring(index),
            }))

            assert.are.equal("unsupported", result.result)
            assert.is_false(result.capability.kinds.brush.supported)
            assert.are.equal(0, catalog:getWriteAccessCount())
            assert.are.equal(0, state.getAddedPresetCalls())
        end
    end)

    it("refuses local settings that did not persist across the live-verified restart", function()
        local catalog, _, _, _, Handler, state = setup({
            lightroomVersion = "15.5.1",
            copy = {
                developSettings = {
                    ProcessVersion = "15.4",
                    EnableMaskGroupBasedCorrections = true,
                },
            },
        })

        local result = Handler.createMask(brushArgs())

        assert.are.equal("unsupported", result.result)
        assert.is_true(result.reason:find("clarity", 1, true) ~= nil)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
    end)

    it("reconciles the first-mask operation without adding a second mask or checkpoint", function()
        local catalog, _, copy, _, Handler, state = setup({
            lightroomVersion = "15.5.1",
            copy = {
                developSettings = {
                    ProcessVersion = "15.4",
                    EnableMaskGroupBasedCorrections = true,
                },
            },
        })

        local request = brushArgs({
            operation_id = "first-mask-retry",
            local_settings = { exposure = 0.5 },
        })
        local first = Handler.createMask(request)
        local writes = catalog:getWriteAccessCount()
        local second = Handler.createMask(request)

        assert.are.equal("created", first.result)
        assert.are.equal("reconciled", second.result)
        assert.are.equal(first.mask_id, second.mask_id)
        assert.are.equal(writes, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
        assert.are.equal(1, #copy.__meta.developSettings.MaskGroupBasedCorrections)
    end)

    it("reconciles a first-mask write that reports a timeout after Lightroom applied it", function()
        local _, _, copy, _, Handler = setup({
            lightroomVersion = "15.5.1",
            copy = {
                developSettings = {
                    ProcessVersion = "15.4",
                    EnableMaskGroupBasedCorrections = true,
                },
            },
            failAfterApply = true,
        })

        local result = Handler.createMask(brushArgs({
            operation_id = "first-mask-timeout",
            local_settings = { exposure = 0.5 },
        }))

        assert.are.equal("reconciled", result.result)
        assert.are.equal(1, #copy.__meta.developSettings.MaskGroupBasedCorrections)
    end)

    it("reconciles the same operation without adding a second mask or checkpoint", function()
        local catalog, _, copy, _, Handler, state = setup()
        local first = Handler.createMask(brushArgs())
        local writes = catalog:getWriteAccessCount()

        local second = Handler.createMask(brushArgs())

        assert.are.equal("created", first.result)
        assert.are.equal("reconciled", second.result)
        assert.are.equal(first.mask_id, second.mask_id)
        assert.are.equal(first.correction_id, second.correction_id)
        assert.are.equal(writes, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
        assert.are.equal(2, #copy.__meta.developSettings.MaskGroupBasedCorrections)
    end)

    it("reconciles a unique Lightroom SyncID rewrite from the exact checkpoint delta", function()
        local operationId = "identity-diagnostic"
        local before = baseDevelopSettings()
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, {
            What = "Correction",
            CorrectionActive = true,
            CorrectionAmount = 1,
            CorrectionName = "Face lift",
            CorrectionSyncID = "lightroom-rewritten-correction",
            CorrectionMasks = {
                {
                    What = "Mask/Paint",
                    MaskActive = true,
                    MaskInverted = false,
                    MaskBlendMode = 0,
                    MaskName = "Face lift",
                    MaskSyncID = "lightroom-rewritten-mask",
                    Dabs = { "f 0.7000", "d 0.200000 0.300000", "d 0.400000 0.500000" },
                    Radius = 0.12,
                    Feather = 0.35,
                    Flow = 0.7,
                    MaskValue = 0.8,
                    CenterWeight = 0.65,
                },
            },
            LocalExposure2012 = 0.5,
        })
        local catalog, _, copy, _, Handler, state = setup({
            copy = { developSettings = current },
            pluginPresets = {
                fakePreset(
                    "Lightroom MCP Mask Checkpoint [" .. operationId .. "]",
                    before,
                    "checkpoint-identity-diagnostic"
                ),
            },
        })

        local result = Handler.createMask(brushArgs({
            operation_id = operationId,
            local_settings = { exposure = 0.5 },
        }))

        assert.are.equal("reconciled", result.result)
        assert.are.equal("lightroom-rewritten-correction", result.correction_id)
        assert.are.equal("lightroom-rewritten-mask", result.mask_id)
        assert.is_true(result.selection_restoration.verified)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
        assert.are.equal(2, #copy.__meta.developSettings.MaskGroupBasedCorrections)
    end)

    it("reconstructs feather from CenterWeight after Lightroom omits Feather on reopen", function()
        local operationId = "identity-rewrite-without-feather"
        local before = baseDevelopSettings()
        before.ProcessVersion = "15.4"
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, {
            What = "Correction",
            CorrectionActive = true,
            CorrectionAmount = 1,
            CorrectionName = "Face lift",
            CorrectionSyncID = "lightroom-rewritten-correction",
            CorrectionMasks = {
                {
                    What = "Mask/Paint",
                    MaskActive = true,
                    MaskInverted = false,
                    MaskBlendMode = 0,
                    MaskName = "Face lift",
                    MaskSyncID = "lightroom-rewritten-mask",
                    Dabs = { "f 0.7000", "d 0.200000 0.300000", "d 0.400000 0.500000" },
                    Radius = 0.12,
                    Flow = 0.7,
                    MaskValue = 0.8,
                    CenterWeight = 0.65,
                },
            },
            LocalExposure2012 = 0.5,
        })
        local _, _, _, _, Handler = setup({
            lightroomVersion = "15.5.1",
            copy = { developSettings = current },
            pluginPresets = {
                fakePreset(
                    "Lightroom MCP Mask Checkpoint [" .. operationId .. "]",
                    before,
                    "checkpoint-identity-rewrite-without-feather"
                ),
            },
        })

        local result = Handler.createMask(brushArgs({
            operation_id = operationId,
            local_settings = { exposure = 0.5 },
        }))

        assert.are.equal("reconciled", result.result)
        assert.are.equal(0.35, result.kind_parameters.feather)
        assert.are.equal("lightroom-rewritten-correction", result.correction_id)
        assert.are.equal("lightroom-rewritten-mask", result.mask_id)
    end)

    it("does not use CenterWeight for malformed Feather or an unverified runtime", function()
        local cases = {
            { label = "malformed", lightroomVersion = "15.5.1", feather = "bad" },
            { label = "unverified-runtime", lightroomVersion = "15.5.0", feather = nil },
        }
        for index, case in ipairs(cases) do
            local operationId = "feather-fallback-" .. case.label
            local before = baseDevelopSettings()
            before.ProcessVersion = "15.4"
            local current = clone(before)
            local mask = {
                What = "Mask/Paint",
                MaskActive = true,
                MaskInverted = false,
                MaskBlendMode = 0,
                MaskName = "Face lift",
                MaskSyncID = "rewritten-mask-" .. tostring(index),
                Dabs = { "f 0.7000", "d 0.200000 0.300000", "d 0.400000 0.500000" },
                Radius = 0.12,
                Flow = 0.7,
                MaskValue = 0.8,
                CenterWeight = 0.65,
            }
            mask.Feather = case.feather
            table.insert(current.MaskGroupBasedCorrections, {
                What = "Correction",
                CorrectionActive = true,
                CorrectionAmount = 1,
                CorrectionName = "Face lift",
                CorrectionSyncID = "rewritten-correction-" .. tostring(index),
                CorrectionMasks = { mask },
                LocalExposure2012 = 0.5,
            })
            local catalog, _, _, _, Handler = setup({
                lightroomVersion = case.lightroomVersion,
                copy = { developSettings = current },
                pluginPresets = {
                    fakePreset(
                        "Lightroom MCP Mask Checkpoint [" .. operationId .. "]",
                        before,
                        "checkpoint-" .. operationId
                    ),
                },
            })

            local result = Handler.createMask(brushArgs({
                operation_id = operationId,
                local_settings = { exposure = 0.5 },
            }))

            assert.are.equal("REVIEW_REQUIRED", result.result)
            assert.is_true(result.reason:find("Feather expected=0.35", 1, true) ~= nil)
            assert.are.equal(0, catalog:getWriteAccessCount())
        end
    end)

    it("keeps disabled or semantically changed rewritten payloads fail-closed", function()
        local cases = {
            { label = "correction-inactive", mutate = function(correction)
                correction.CorrectionActive = false
            end },
            { label = "correction-amount", mutate = function(correction)
                correction.CorrectionAmount = 0
            end },
            { label = "mask-inactive", mutate = function(correction)
                correction.CorrectionMasks[1].MaskActive = false
            end },
            { label = "mask-inverted", mutate = function(correction)
                correction.CorrectionMasks[1].MaskInverted = true
            end },
            { label = "mask-blend", mutate = function(correction)
                correction.CorrectionMasks[1].MaskBlendMode = 1
            end },
            { label = "extra-local", mutate = function(correction)
                correction.LocalShadows2012 = 25
            end },
            { label = "unknown-local", mutate = function(correction)
                correction.LocalUnverifiedAdjustment = 1
            end },
        }
        for index, case in ipairs(cases) do
            local operationId = "semantic-payload-" .. case.label
            local before = baseDevelopSettings()
            local current = clone(before)
            local correction = {
                What = "Correction",
                CorrectionActive = true,
                CorrectionAmount = 1,
                CorrectionName = "Face lift",
                CorrectionSyncID = "semantic-correction-" .. tostring(index),
                CorrectionMasks = {
                    {
                        What = "Mask/Paint",
                        MaskActive = true,
                        MaskInverted = false,
                        MaskBlendMode = 0,
                        MaskName = "Face lift",
                        MaskSyncID = "semantic-mask-" .. tostring(index),
                        Dabs = { "d 0.200000 0.300000", "d 0.400000 0.500000" },
                        Radius = 0.12,
                        Feather = 0.35,
                        Flow = 0.7,
                        MaskValue = 0.8,
                        CenterWeight = 0.65,
                    },
                },
                LocalExposure2012 = 0.5,
                LocalClarity2012 = 12,
            }
            case.mutate(correction)
            table.insert(current.MaskGroupBasedCorrections, correction)
            local catalog, _, _, _, Handler = setup({
                copy = { developSettings = current },
                pluginPresets = {
                    fakePreset(
                        "Lightroom MCP Mask Checkpoint [" .. operationId .. "]",
                        before,
                        "checkpoint-" .. operationId
                    ),
                },
            })

            local result = Handler.createMask(brushArgs({ operation_id = operationId }))

            assert.are.equal("REVIEW_REQUIRED", result.result)
            assert.are.equal(0, catalog:getWriteAccessCount())
        end
    end)

    it("keeps a non-unique Lightroom SyncID rewrite fail-closed with bounded identities", function()
        local operationId = "ambiguous-identity-rewrite"
        local before = baseDevelopSettings()
        local duplicateCandidate = {
            What = "Correction",
            CorrectionActive = true,
            CorrectionAmount = 1,
            CorrectionName = "Face lift",
            CorrectionSyncID = "rewritten-correction-duplicate",
            CorrectionMasks = {
                {
                    What = "Mask/Paint",
                    MaskActive = true,
                    MaskInverted = false,
                    MaskBlendMode = 0,
                    MaskName = "Face lift",
                    MaskSyncID = "rewritten-mask-duplicate",
                    Dabs = { "d 0.200000 0.300000", "d 0.400000 0.500000" },
                    Radius = 0.12,
                    Feather = 0.35,
                    Flow = 0.7,
                    MaskValue = 0.8,
                    CenterWeight = 0.65,
                },
            },
            LocalExposure2012 = 0.5,
            LocalClarity2012 = 12,
        }
        before.MaskGroupBasedCorrections = { clone(duplicateCandidate) }
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, clone(duplicateCandidate))
        local catalog, _, _, _, Handler = setup({
            copy = { developSettings = current },
            pluginPresets = {
                fakePreset(
                    "Lightroom MCP Mask Checkpoint [" .. operationId .. "]",
                    before,
                    "checkpoint-ambiguous-identity-rewrite"
                ),
            },
        })

        local result = Handler.createMask(brushArgs({ operation_id = operationId }))

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:match("expected correction_id=") ~= nil)
        assert.is_true(result.reason:find(
            "found correction_ids=[rewritten-correction-duplicate,rewritten-correction-duplicate]",
            1,
            true
        ) ~= nil)
        assert.is_true(result.reason:find("index=1", 1, true) ~= nil)
        assert.is_true(result.reason:find("index=2", 1, true) ~= nil)
        assert.are.equal(0, catalog:getWriteAccessCount())
    end)

    it("reports the first bounded payload mismatch for a rewritten identity", function()
        local operationId = "rewritten-payload-mismatch"
        local before = baseDevelopSettings()
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, {
            What = "Correction",
            CorrectionActive = true,
            CorrectionAmount = 1,
            CorrectionName = "Face lift",
            CorrectionSyncID = "rewritten-correction",
            CorrectionMasks = {
                {
                    What = "Mask/Paint",
                    MaskActive = true,
                    MaskName = "Face lift",
                    MaskSyncID = "rewritten-mask",
                    Dabs = { "d 0.200001 0.300000", "d 0.400000 0.500000" },
                    Radius = 0.12,
                    Feather = 0.35,
                    Flow = 0.7,
                    MaskValue = 0.8,
                    CenterWeight = 0.65,
                },
            },
            LocalExposure2012 = 0.5,
            LocalClarity2012 = 12,
        })
        local catalog, _, _, _, Handler = setup({
            copy = { developSettings = current },
            pluginPresets = {
                fakePreset(
                    "Lightroom MCP Mask Checkpoint [" .. operationId .. "]",
                    before,
                    "checkpoint-rewritten-payload-mismatch"
                ),
            },
        })

        local result = Handler.createMask(brushArgs({ operation_id = operationId }))

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:find(
            "payload=Dabs expected=[d 0.200000 0.300000|d 0.400000 0.500000] actual=[d 0.200001 0.300000|d 0.400000 0.500000]",
            1,
            true
        ) ~= nil)
        assert.is_true(result.reason:find(
            "local_keys=[LocalClarity2012=12,LocalExposure2012=0.5]",
            1,
            true
        ) ~= nil)
        assert.is_true(result.reason:find("correction_keys=[", 1, true) ~= nil)
        assert.is_true(result.reason:find("CorrectionSyncID=rewritten-correction", 1, true) ~= nil)
        assert.is_true(result.reason:find("delta=true", 1, true) ~= nil)
        assert.are.equal(0, catalog:getWriteAccessCount())
    end)

    it("reconciles a write that reports a timeout after Lightroom applied it", function()
        local _, _, copy, _, Handler = setup({ copy = { developSettings = baseDevelopSettings() }, failAfterApply = true })

        local result = Handler.createMask(brushArgs({ operation_id = "mask-timeout-001" }))

        assert.are.equal("reconciled", result.result)
        assert.are.equal("mask-timeout-001", result.operation_id)
        assert.is_true(result.preservation.exactly_one_mask_added)
    end)

    it("stops before the write when Develop settings drift after the checkpoint", function()
        local catalog, _, copy, _, Handler, state = setup()
        local originalSetSelected = catalog.setSelectedPhotos
        catalog.setSelectedPhotos = function(fakeCatalog, activePhoto, otherSelectedPhotos)
            originalSetSelected(fakeCatalog, activePhoto, otherSelectedPhotos)
            if activePhoto == copy then
                copy.__meta.developSettings.Exposure2012 = 1.25
            end
        end

        local result = Handler.createMask(brushArgs({ operation_id = "drift-before-write" }))

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:match("changed before") ~= nil)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
        assert.are.equal(1.25, copy.__meta.developSettings.Exposure2012)
    end)

    it("refuses a checkpoint whose SDK readback does not match the pre-write state", function()
        local catalog, _, _, _, Handler, state = setup({
            checkpointSettings = { ProcessVersion = "11.0" },
        })

        local result = Handler.createMask(brushArgs({ operation_id = "bad-checkpoint" }))

        assert.are.equal("unsupported", result.result)
        assert.is_true(result.reason:match("checkpoint readback") ~= nil)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
    end)

    it("refuses Subject before checkpoint or mutation when the controller API is missing", function()
        local catalog, _, _, _, Handler, state = setup({ subjectControllerAvailable = false })

        local result = Handler.createMask(subjectArgs({ operation_id = "subject-api-missing" }))

        assert.are.equal("unsupported", result.result)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
        assert.are.equal(0, state.getSubjectCreateCalls())
        assert.is_false(result.capability.kinds.subject.supported)
    end)

    it("creates a real Subject through LrDevelopController, patches only its name/local settings, and restores module/selection", function()
        local catalog, _, copy, other, Handler, state = setup()
        local before = clone(copy.__meta.developSettings)

        local result = Handler.createMask(subjectArgs())

        assert.are.equal("created", result.result)
        assert.are.equal("subject", result.mask_kind)
        assert.are.equal("Squirrel subject lift", result.name)
        assert.are.same({}, result.kind_parameters)
        assert.are.equal("lightroom_ai", result.geometry.coordinate_system)
        assert.are.equal("opaque", result.geometry.coordinate_units)
        assert.is_true(result.geometry.ai_payload_present)
        assert.is_true(result.geometry.ai_payload_field_count >= 1)
        assert.are.equal("Mask/Image", result.geometry.ai_mask_type)
        assert.are.equal(1, result.geometry.ai_mask_subtype)
        assert.are.equal(0, result.geometry.error_reason)
        assert.are.equal(0.75, result.initial_local_settings.exposure)
        assert.is_true(result.preservation.exactly_one_mask_added)
        assert.is_true(result.preservation.existing_mask_tree_unchanged)
        assert.is_true(result.preservation.global_develop_unchanged)
        assert.are.equal(1, state.getSubjectCreateCalls())
        assert.are.equal(1, catalog:getWriteAccessCount())
        assert.are.equal(1, state.getAddedPresetCalls())
        assert.are.equal("library", state.getCurrentModule())
        assert.are.same({ "develop", "library" }, state.getModuleSwitches())
        assert.are.equal(other, catalog:getTargetPhoto())
        assert.are.same({ other }, catalog:getTargetPhotos())
        assert.are.same({ "old-folder" }, catalog:getActiveSources())
        assert.are.equal(before.Exposure2012, copy.__meta.developSettings.Exposure2012)
        assert.are.equal(before.Contrast2012, copy.__meta.developSettings.Contrast2012)
        assert.are.equal("generated-by-lightroom", copy.__meta.developSettings
            .MaskGroupBasedCorrections[2].CorrectionMasks[1].OpaqueImagePayload)
    end)

    it("accepts the live normalization where a successful Subject omits ErrorReason", function()
        local correction = {
            What = "Correction", CorrectionActive = true, CorrectionAmount = 1,
            CorrectionName = "Subject 1", CorrectionSyncID = "subject-no-error-field",
            LocalToningSaturation = 0,
            CorrectionMasks = { {
                What = "Mask/Image", MaskActive = true, MaskName = "Subject 1",
                MaskBlendMode = 0, MaskInverted = false,
                MaskSyncID = "subject-mask-no-error-field", MaskValue = 1,
                MaskVersion = 1, MaskSubType = 1,
                ReferencePoint = "0.500000 0.500000",
                OpaqueImagePayload = "generated-with-omitted-error",
            } },
        }
        local _, _, _, _, Handler = setup({ subjectAdditions = { correction } })

        local result = Handler.createMask(subjectArgs({ operation_id = "subject-no-error" }))

        assert.are.equal("created", result.result)
        assert.are.equal("absent", result.geometry.ai_error_state)
        assert.is_nil(result.geometry.error_reason)
    end)

    it("rejects a nonzero unknown Subject local setting", function()
        local correction = {
            What = "Correction", CorrectionActive = true, CorrectionAmount = 1,
            CorrectionName = "Subject 1", CorrectionSyncID = "subject-unknown-local",
            LocalToningSaturation = 1,
            CorrectionMasks = { {
                What = "Mask/Image", MaskActive = true, MaskName = "Subject 1",
                MaskBlendMode = 0, MaskInverted = false,
                MaskSyncID = "subject-mask-unknown-local", MaskValue = 1,
                MaskVersion = 1, MaskSubType = 1,
                ReferencePoint = "0.500000 0.500000",
                OpaqueImagePayload = "generated-with-nonzero-unknown-local",
            } },
        }
        local _, _, _, _, Handler = setup({ subjectAdditions = { correction } })

        local result = Handler.createMask(subjectArgs({ operation_id = "subject-bad-local" }))

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:find("LocalToningSaturation", 1, true) ~= nil)
    end)

    it("fails closed for a wrong AI kind or ambiguous Subject delta", function()
        local subjectCorrection = {
            What = "Correction", CorrectionActive = true, CorrectionAmount = 1,
            CorrectionName = "Subject 1", CorrectionSyncID = "subject-correction",
            CorrectionMasks = { {
                What = "Mask/Image", MaskActive = true, MaskName = "Subject 1",
                MaskSyncID = "subject-mask", MaskValue = 1, MaskVersion = 1,
                MaskSubType = 1, ReferencePoint = "0.5 0.5", ErrorReason = 0,
                OpaqueImagePayload = "ambiguous-ai-payload",
            } },
        }
        local wrongKind = clone(subjectCorrection)
        wrongKind.CorrectionMasks[1].MaskSubType = 2
        local catalog, _, _, _, Handler, state = setup({ subjectAdditions = { wrongKind } })
        local result = Handler.createMask(subjectArgs({ operation_id = "subject-wrong-kind" }))
        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.are.equal(1, state.getSubjectCreateCalls())
        assert.are.equal(0, catalog:getWriteAccessCount())

        local before = baseDevelopSettings()
        table.insert(before.MaskGroupBasedCorrections, clone(subjectCorrection))
        local catalog2, _, _, _, Handler2, state2 = setup({
            copy = { developSettings = before },
            subjectAdditions = { clone(subjectCorrection) },
        })
        local result2 = Handler2.createMask(subjectArgs({ operation_id = "subject-ambiguous-delta" }))
        assert.are.equal("REVIEW_REQUIRED", result2.result)
        assert.is_true(result2.reason:find("candidate_count=2", 1, true) ~= nil)
        assert.are.equal(1, state2.getSubjectCreateCalls())
        assert.are.equal(0, catalog2:getWriteAccessCount())
        assert.are.equal("library", state2.getCurrentModule())
    end)

    it("returns review when module restoration cannot be verified after Subject creation", function()
        local _, _, _, _, Handler, state = setup({ failModuleRestore = true })
        local result = Handler.createMask(subjectArgs({ operation_id = "subject-module-restore" }))
        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:find("restoration failed", 1, true) ~= nil)
        assert.are.equal(1, state.getSubjectCreateCalls())
        assert.are.equal("develop", state.getCurrentModule())
    end)

    it("does not retry the controller after a failure and reconciles only an exact created delta", function()
        local catalog, _, _, _, Handler, state = setup({ subjectControllerFailure = "before" })
        local result = Handler.createMask(subjectArgs({ operation_id = "subject-controller-failure" }))
        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.are.equal(1, state.getSubjectCreateCalls())
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal("library", state.getCurrentModule())

        local catalog2, _, _, _, Handler2, state2 = setup({ subjectControllerFailure = "after" })
        local result2 = Handler2.createMask(subjectArgs({ operation_id = "subject-controller-timeout" }))
        assert.are.equal("reconciled", result2.result)
        assert.are.equal(1, state2.getSubjectCreateCalls())
        assert.are.equal(1, catalog2:getWriteAccessCount())
        assert.are.equal("library", state2.getCurrentModule())
    end)

    it("reconciles Subject from the exact checkpoint delta without creating a duplicate", function()
        local before = baseDevelopSettings()
        local correction = {
            What = "Correction", CorrectionActive = true, CorrectionAmount = 1,
            CorrectionName = "Squirrel subject lift",
            CorrectionSyncID = "persisted-subject-correction",
            CorrectionMasks = { {
                What = "Mask/Image", MaskActive = true,
                MaskName = "Squirrel subject lift", MaskBlendMode = 0,
                MaskInverted = false, MaskSyncID = "persisted-subject-mask",
                MaskValue = 1, MaskVersion = 1, MaskSubType = 1,
                ReferencePoint = "0.500000 0.500000", ErrorReason = 0,
                OpaqueImagePayload = "persisted-ai-payload",
            } },
            LocalExposure2012 = 0.75,
        }
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, correction)
        local args = subjectArgs({ operation_id = "subject-retry" })
        local checkpointName = subjectCheckpointName(args)
        local catalog, _, copy, _, Handler, state = setup({
            copy = { developSettings = current },
            pluginPresets = { fakePreset(checkpointName, before, "subject-checkpoint") },
        })

        local result = Handler.createMask(args)

        assert.are.equal("reconciled", result.result)
        assert.are.equal(0, state.getSubjectCreateCalls())
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(2, #copy.__meta.developSettings.MaskGroupBasedCorrections)
        assert.are.equal("persisted-ai-payload", result.geometry.ai_payload_present
            and copy.__meta.developSettings.MaskGroupBasedCorrections[2]
                .CorrectionMasks[1].OpaqueImagePayload)
    end)

    it("completes one exact unpatched Subject delta on retry without calling the controller", function()
        local before = baseDevelopSettings()
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, {
            What = "Correction", CorrectionActive = true, CorrectionAmount = 1,
            CorrectionName = "Subject 1", CorrectionSyncID = "partial-subject-correction",
            CorrectionMasks = { {
                What = "Mask/Image", MaskActive = true, MaskName = "Subject 1",
                MaskBlendMode = 0, MaskInverted = false,
                MaskSyncID = "partial-subject-mask", MaskValue = 1,
                MaskVersion = 1, MaskSubType = 1,
                ReferencePoint = "0.500000 0.500000",
                OpaqueImagePayload = "partial-ai-payload",
            } },
        })
        local args = subjectArgs({ operation_id = "subject-partial-retry" })
        local checkpointName = subjectCheckpointName(args)
        local catalog, _, copy, _, Handler, state = setup({
            copy = { developSettings = current },
            pluginPresets = { fakePreset(checkpointName, before, "subject-partial-checkpoint") },
        })

        local result = Handler.createMask(args)

        assert.are.equal("reconciled", result.result)
        assert.are.equal(0, state.getSubjectCreateCalls())
        assert.are.equal(1, catalog:getWriteAccessCount())
        assert.are.equal("Squirrel subject lift",
            copy.__meta.developSettings.MaskGroupBasedCorrections[2].CorrectionName)
        assert.are.equal(0.75,
            copy.__meta.developSettings.MaskGroupBasedCorrections[2].LocalExposure2012)
        assert.are.equal("partial-ai-payload",
            copy.__meta.developSettings.MaskGroupBasedCorrections[2]
                .CorrectionMasks[1].OpaqueImagePayload)
    end)

    it("refuses reuse of a Subject operation id when the request fingerprint changed", function()
        local before = baseDevelopSettings()
        local originalArgs = subjectArgs({
            operation_id = "subject-request-reuse",
            name = "Original subject lift",
            local_settings = { exposure = 0.25 },
        })
        local current = clone(before)
        table.insert(current.MaskGroupBasedCorrections, {
            What = "Correction", CorrectionActive = true, CorrectionAmount = 1,
            CorrectionName = originalArgs.name,
            CorrectionSyncID = "original-subject-correction",
            LocalExposure2012 = 0.25,
            CorrectionMasks = { {
                What = "Mask/Image", MaskActive = true, MaskName = originalArgs.name,
                MaskBlendMode = 0, MaskInverted = false,
                MaskSyncID = "original-subject-mask", MaskValue = 1,
                MaskVersion = 1, MaskSubType = 1,
                ReferencePoint = "0.500000 0.500000",
                OpaqueImagePayload = "original-ai-payload",
            } },
        })
        local catalog, _, copy, _, Handler, state = setup({
            copy = { developSettings = current },
            pluginPresets = { fakePreset(
                subjectCheckpointName(originalArgs),
                before,
                "subject-request-reuse-checkpoint"
            ) },
        })
        local changedArgs = subjectArgs({
            operation_id = originalArgs.operation_id,
            name = "Changed subject lift",
            local_settings = { exposure = 0.75 },
        })

        local result = Handler.createMask(changedArgs)

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:find("changed-request reuse", 1, true) ~= nil)
        assert.are.equal(0, state.getSubjectCreateCalls())
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal("Original subject lift",
            copy.__meta.developSettings.MaskGroupBasedCorrections[2].CorrectionName)
        assert.are.equal(0.25,
            copy.__meta.developSettings.MaskGroupBasedCorrections[2].LocalExposure2012)
    end)

    it("refuses Brush reuse of an operation id bound to a Subject checkpoint", function()
        local before = baseDevelopSettings()
        local operationId = "cross-kind-operation-reuse"
        local subjectRequest = subjectArgs({ operation_id = operationId })
        local catalog, _, copy, _, Handler, state = setup({
            copy = { developSettings = clone(before) },
            pluginPresets = { fakePreset(
                subjectCheckpointName(subjectRequest),
                before,
                "cross-kind-subject-checkpoint"
            ) },
        })

        local result = Handler.createMask(brushArgs({ operation_id = operationId }))

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.are.equal(0, state.getAddedPresetCalls())
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.same(before, copy.__meta.developSettings)
    end)

    it("never invokes the Subject controller when a reused checkpoint has no delta", function()
        local before = baseDevelopSettings()
        local args = subjectArgs({ operation_id = "subject-empty-retry" })
        local catalog, _, copy, _, Handler, state = setup({
            copy = { developSettings = clone(before) },
            pluginPresets = { fakePreset(
                subjectCheckpointName(args),
                before,
                "subject-empty-retry-checkpoint"
            ) },
        })

        local result = Handler.createMask(args)

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.reason:find("controller will not be re-invoked", 1, true) ~= nil)
        assert.are.equal(0, state.getSubjectCreateCalls())
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(1, #copy.__meta.developSettings.MaskGroupBasedCorrections)
    end)

    it("restores selection and active sources after returning to the original module", function()
        local catalog, _, copy, other, Handler, state = setup({
            onSwitchModule = function(name, switchedCatalog, workflowCopy)
                if name == "library" then
                    switchedCatalog:setSelectedPhotos(workflowCopy, {})
                    switchedCatalog:setActiveSources({ "module-side-effect" })
                end
            end,
        })

        local result = Handler.createMask(subjectArgs({
            operation_id = "subject-final-restoration",
        }))

        assert.are.equal("created", result.result)
        assert.are.equal("restored", result.selection_restoration.status)
        assert.is_true(result.selection_restoration.verified)
        assert.are.equal("library", state.getCurrentModule())
        assert.are.equal(other, catalog:getTargetPhoto())
        assert.are.same({ other }, catalog:getTargetPhotos())
        assert.are.same({ "old-folder" }, catalog:getActiveSources())
        assert.are.equal(1, state.getSubjectCreateCalls())
        assert.are.equal(2, #copy.__meta.developSettings.MaskGroupBasedCorrections)
    end)

    it("keeps Sky explicitly unsupported without checkpoint or mutation", function()
        local catalog, _, _, _, Handler, state = setup()
        local result = Handler.createMask(brushArgs({
            mask_kind = "sky", kind_parameters = {}, operation_id = "ai-sky",
        }))
        assert.are.equal("unsupported", result.result)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
        assert.are.equal(0, state.getSubjectCreateCalls())
        assert.is_false(result.capability.kinds.sky.supported)
    end)

    it("returns explicit unsupported for an unknown runtime mask schema", function()
        local catalog, _, _, _, Handler, state = setup({
            copy = {
                developSettings = {
                    ProcessVersion = "11.0",
                    EnableMaskGroupBasedCorrections = true,
                    MaskGroupBasedCorrections = { { Unknown = true } },
                },
            },
        })

        local result = Handler.createMask(brushArgs({ operation_id = "unknown-schema" }))

        assert.are.equal("unsupported", result.result)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
        assert.is_true(result.reason:match("schema") ~= nil)
    end)

    it("returns explicit unsupported for a Lightroom/process version below the mask adapter floor", function()
        local catalog, _, _, _, Handler, state = setup({
            lightroomVersion = "10.4",
            copy = {
                developSettings = {
                    ProcessVersion = "10.0",
                    EnableMaskGroupBasedCorrections = true,
                    MaskGroupBasedCorrections = {},
                },
            },
        })

        local result = Handler.createMask(brushArgs({ operation_id = "old-runtime" }))

        assert.are.equal("unsupported", result.result)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
        assert.is_false(result.capability.kinds.brush.supported)
    end)

    it("rejects a Master, path-only identity, and UUID mismatch before checkpoint or write", function()
        local catalog, master, _, _, Handler, state = setup()
        assert.has_error(function()
            Handler.createMask(brushArgs({ photo_id = "100" }))
        end)
        assert.has_error(function()
            Handler.createMask(brushArgs({ photo_id = "/相片/夕陽.jpg" }))
        end)
        assert.has_error(function()
            Handler.createMask(brushArgs({ expected_photo_uuid = "wrong" }))
        end)
        assert.are.equal("uuid-master", master.__meta.uuid)
        assert.are.equal(0, catalog:getWriteAccessCount())
        assert.are.equal(0, state.getAddedPresetCalls())
    end)

    it("rejects empty, control-character, nested, nonfinite, and out-of-range inputs", function()
        local invalid = {
            { name = "   " },
            { name = "bad\nname" },
            { local_settings = { exposure = { nested = true } } },
            { local_settings = { exposure = 0 / 0 } },
            { local_settings = { exposure = 6 } },
            { kind_parameters = { coordinate_system = "pixels" } },
            { kind_parameters = { coordinate_system = "normalized_image", coordinate_units = "unit_interval", path = { { x = 2, y = 0.1 } }, size = 0.1, feather = 0, flow = 1, density = 1 } },
        }
        for index, overrides in ipairs(invalid) do
            local catalog, _, _, _, Handler, state = setup()
            local args = brushArgs({ operation_id = "invalid-" .. tostring(index) })
            for key, value in pairs(overrides) do args[key] = value end
            assert.has_error(function()
                Handler.createMask(args)
            end)
            assert.are.equal(0, catalog:getWriteAccessCount())
            assert.are.equal(0, state.getAddedPresetCalls())
        end
    end)
end)
