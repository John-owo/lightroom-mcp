local helper = require 'spec_helper'

local function setup(opts)
    local catalog = helper.fakeCatalog(opts)
    helper.installImport({
        LrApplication = { activeCatalog = function() return catalog end },
        LrTasks = { pcall = pcall },
        LrLogger = helper.defaultLrLogger(),
    })
    package.loaded.HandlerVirtualCopy = nil
    package.loaded.Log = nil
    return catalog, require 'HandlerVirtualCopy'
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

local function makeCopy(master, overrides)
    local meta = {
        id = "101",
        uuid = "uuid-copy",
        path = "/相片/夕陽.jpg",
        fileName = "夕陽.jpg",
        copyName = "Lightroom MCP VC [op-001]",
        isVirtualCopy = true,
        masterPhoto = master,
    }
    for key, value in pairs(overrides or {}) do meta[key] = value end
    return helper.fakePhoto(meta)
end

describe("HandlerVirtualCopy.createVirtualCopy", function()
    it("creates one verified Copy and restores active/selected state", function()
        local source = helper.fakePhoto(masterMeta())
        local other = helper.fakePhoto({
            id = "200", uuid = "uuid-other", path = "/相片/其他.jpg",
            fileName = "其他.jpg", isVirtualCopy = false,
        })
        local catalog, Handler = setup({
            photos = { source, other },
            targetPhotos = { other },
            targetPhoto = other,
            activeSources = { "old-folder" },
        })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-001",
        })

        assert.are.equal("created", result.result)
        assert.are.equal("op-001", result.operation_id)
        assert.are.equal("Lightroom MCP VC [op-001]", result.marker)
        assert.are.equal("100", result.source.catalog_id)
        assert.are.equal("uuid-master", result.master.uuid)
        assert.is_true(result.copy.is_virtual_copy)
        assert.are.equal("3", result.copy.catalog_id)
        assert.are.equal("restored", result.selection_restoration.status)
        assert.is_true(result.selection_restoration.verified)
        assert.are.equal(1, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal(2, #catalog.getSelectedPhotoCalls())
        assert.are.equal(other, catalog:getTargetPhoto())
        assert.are.same({ other }, catalog:getTargetPhotos())
        assert.are.same({ "old-folder" }, catalog:getActiveSources())
    end)

    it("reconciles one verified marker match without creating another Copy", function()
        local source = helper.fakePhoto(masterMeta({ countVirtualCopies = 1 }))
        local copy = makeCopy(source)
        source.__meta.virtualCopies = { copy }
        local catalog, Handler = setup({ photos = { source, copy } })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-001",
        })

        assert.are.equal("reconciled", result.result)
        assert.are.equal("101", result.copy.catalog_id)
        assert.are.equal("uuid-copy", result.copy.uuid)
        assert.is_true(result.is_virtual_copy)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal("not_needed", result.selection_restoration.status)
    end)

    it("rejects a Virtual Copy source before selection or mutation", function()
        local source = helper.fakePhoto(masterMeta())
        local copy = makeCopy(source, { id = "101", uuid = "uuid-copy-source" })
        local catalog, Handler = setup({ photos = { source, copy } })

        assert.has_error(function()
            Handler.createVirtualCopy({
                source_photo_id = "101",
                expected_source_uuid = "uuid-copy-source",
                operation_id = "op-002",
            })
        end)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal(0, #catalog.getSelectedPhotoCalls())
    end)

    it("rejects an expected UUID mismatch before selection or mutation", function()
        local source = helper.fakePhoto(masterMeta())
        local catalog, Handler = setup({ photos = { source } })

        assert.has_error(function()
            Handler.createVirtualCopy({
                source_photo_id = "100",
                expected_source_uuid = "uuid-not-master",
                operation_id = "op-003",
            })
        end)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal(0, #catalog.getSelectedPhotoCalls())
    end)

    it("rejects malformed Virtual Copy status before selection or mutation", function()
        local source = helper.fakePhoto(masterMeta({ isVirtualCopy = "false" }))
        local catalog, Handler = setup({ photos = { source } })

        assert.has_error(function()
            Handler.createVirtualCopy({
                source_photo_id = "100",
                expected_source_uuid = "uuid-master",
                operation_id = "op-malformed-status",
            })
        end)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal(0, #catalog.getSelectedPhotoCalls())
    end)

    it("does not create when an exact marker has an untrusted status field", function()
        local source = helper.fakePhoto(masterMeta())
        local suspicious = makeCopy(source, {
            id = "101", uuid = "uuid-suspicious", isVirtualCopy = "true",
        })
        source.__meta.virtualCopies = { suspicious }
        local catalog, Handler = setup({ photos = { source, suspicious } })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-001",
        })

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.are.equal(1, result.candidate_count)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
    end)

    it("fails closed when no active photo can be restored", function()
        local source = helper.fakePhoto(masterMeta())
        local catalog, Handler = setup({
            photos = { source },
            targetPhotos = {},
            targetPhoto = nil,
        })

        assert.has_error(function()
            Handler.createVirtualCopy({
                source_photo_id = "100",
                expected_source_uuid = "uuid-master",
                operation_id = "op-no-active-photo",
            })
        end)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal(0, #catalog.getSelectedPhotoCalls())
    end)

    it("fails closed when selection drifts before create and restores the snapshot", function()
        local source = helper.fakePhoto(masterMeta())
        local other = helper.fakePhoto({
            id = "200", uuid = "uuid-other", path = "/其他.jpg", fileName = "其他.jpg",
            isVirtualCopy = false,
        })
        local drifted = false
        local catalog, Handler = setup({
            photos = { source, other },
            targetPhotos = { other },
            targetPhoto = other,
            onSetSelectedPhotos = function(active, _, fakeCatalog)
                if active == source and not drifted then
                    drifted = true
                    fakeCatalog:setTargetPhotosForTest({ other }, other)
                end
            end,
        })

        assert.has_error(function()
            Handler.createVirtualCopy({
                source_photo_id = "100",
                expected_source_uuid = "uuid-master",
                operation_id = "op-004",
            })
        end)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
        assert.are.equal(other, catalog:getTargetPhoto())
        assert.are.same({ other }, catalog:getTargetPhotos())
    end)

    it("retains a possible Copy and restores selection when the SDK errors after mutation", function()
        local source = helper.fakePhoto(masterMeta())
        local other = helper.fakePhoto({
            id = "200", uuid = "uuid-other", path = "/其他.jpg", fileName = "其他.jpg",
            isVirtualCopy = false,
        })
        local catalog, Handler = setup({
            photos = { source, other },
            targetPhotos = { other },
            targetPhoto = other,
            createVirtualCopies = function(copyName, master, fakeCatalog)
                local copy = makeCopy(master, {
                    id = "201", uuid = "uuid-retained", copyName = copyName,
                })
                master.__meta.virtualCopies = { copy }
                master.__meta.countVirtualCopies = 1
                fakeCatalog:addPhotoForTest(copy)
                fakeCatalog:setTargetPhotosForTest({ copy }, copy)
                error("SDK timeout after create", 0)
            end,
        })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-005",
        })

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.partial)
        assert.are.equal("uuid-retained", result.candidates[1].uuid)
        assert.are.equal("restored", result.selection_restoration.status)
        assert.is_true(result.selection_restoration.verified)
        assert.are.equal(other, catalog:getTargetPhoto())
        assert.are.same({ other }, catalog:getTargetPhotos())
    end)

    it("returns a retained Copy when selection restoration readback fails", function()
        local source = helper.fakePhoto(masterMeta())
        local other = helper.fakePhoto({
            id = "200", uuid = "uuid-other", path = "/其他.jpg", fileName = "其他.jpg",
            isVirtualCopy = false,
        })
        local catalog, Handler = setup({
            photos = { source, other },
            targetPhotos = { other },
            targetPhoto = other,
            onSetSelectedPhotos = function(active, _, fakeCatalog)
                if active == other then
                    fakeCatalog:setTargetPhotosForTest({ source }, source)
                end
            end,
        })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-006",
        })

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.partial)
        assert.are.equal("failed", result.selection_restoration.status)
        assert.is_false(result.selection_restoration.verified)
        assert.are.equal("uuid-copy-3", result.copy.uuid)
        assert.is_true(result.copy.is_virtual_copy)
    end)

    it("fails closed on duplicate marker matches", function()
        local source = helper.fakePhoto(masterMeta({ countVirtualCopies = 2 }))
        local copyOne = makeCopy(source, { id = "101", uuid = "uuid-copy-one" })
        local copyTwo = makeCopy(source, { id = "102", uuid = "uuid-copy-two" })
        source.__meta.virtualCopies = { copyOne, copyTwo }
        local catalog, Handler = setup({ photos = { source, copyOne, copyTwo } })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-001",
        })

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.is_true(result.partial)
        assert.are.equal(2, #result.candidates)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
    end)

    it("reconciles markers catalog-wide and blocks a different source", function()
        local source = helper.fakePhoto(masterMeta())
        local otherMaster = helper.fakePhoto({
            id = "400", uuid = "uuid-other-master", path = "/other.jpg",
            fileName = "other.jpg", isVirtualCopy = false,
        })
        local foreignCopy = makeCopy(otherMaster, {
            id = "401", uuid = "uuid-foreign-copy",
        })
        otherMaster.__meta.virtualCopies = { foreignCopy }
        local catalog, Handler = setup({ photos = { source, otherMaster, foreignCopy } })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-001",
        })

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.are.equal(1, result.candidate_count)
        assert.are.equal("uuid-foreign-copy", result.candidates[1].uuid)
        assert.are.equal(0, catalog.getCreateVirtualCopiesCalls())
    end)

    it("retains every returned photo when create returns an unexpected count", function()
        local source = helper.fakePhoto(masterMeta())
        local catalog, Handler = setup({
            photos = { source },
            createVirtualCopies = function(copyName, master)
                local one = makeCopy(master, { id = "501", uuid = "uuid-returned-one", copyName = copyName })
                local two = makeCopy(master, { id = "502", uuid = "uuid-returned-two", copyName = copyName })
                return { one, two }
            end,
        })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "op-returned-many",
        })

        assert.are.equal("REVIEW_REQUIRED", result.result)
        assert.are.equal(2, result.candidate_count)
        assert.are.equal(2, #result.candidates)
        assert.are.equal("uuid-returned-one", result.candidates[1].uuid)
        assert.are.equal("uuid-returned-two", result.candidates[2].uuid)
    end)

    it("preserves non-ASCII metadata while carrying the ASCII marker", function()
        local source = helper.fakePhoto(masterMeta())
        local catalog, Handler = setup({
            photos = { source },
            createVirtualCopies = function(copyName, master)
                local copy = makeCopy(master, {
                    id = "301", uuid = "uuid-中文-copy",
                    copyName = copyName,
                })
                master.__meta.virtualCopies = { copy }
                master.__meta.countVirtualCopies = 1
                return { copy }
            end,
        })

        local result = Handler.createVirtualCopy({
            source_photo_id = "100",
            expected_source_uuid = "uuid-master",
            operation_id = "safe-op-007",
        })

        assert.are.equal("created", result.result)
        assert.are.equal("/相片/夕陽.jpg", result.source.path)
        assert.are.equal("夕陽.jpg", result.source.filename)
        assert.are.equal("uuid-中文-copy", result.copy.uuid)
        assert.are.equal("Lightroom MCP VC [safe-op-007]", result.marker)
        assert.are.equal("restored", result.selection_restoration.status)
        assert.are.equal(1, catalog.getCreateVirtualCopiesCalls())
    end)
end)
