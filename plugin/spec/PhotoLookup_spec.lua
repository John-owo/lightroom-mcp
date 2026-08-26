local function fakePhoto(id, path)
    return {
        localIdentifier = id,
        getRawMetadata = function(_, key)
            if key == 'path' then return path end
            return nil
        end,
    }
end

local function fakeCatalog(photos)
    local state = { getAllPhotosCalls = 0 }
    local catalog = {
        getAllPhotos = function()
            state.getAllPhotosCalls = state.getAllPhotosCalls + 1
            return photos
        end,
    }
    return catalog, state
end

local PhotoLookup
local function loadModule()
    package.loaded.PhotoLookup = nil
    PhotoLookup = require 'PhotoLookup'
end

describe("PhotoLookup.resolveMany", function()
    before_each(loadModule)

    it("resolves numeric localIdentifier ids in one catalog scan", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local p2 = fakePhoto(2, "/b.jpg")
        local catalog, state = fakeCatalog({ p1, p2 })

        local r = PhotoLookup.resolveMany(catalog, { "1", "2" })

        assert.are.equal(p1, r[1].photo)
        assert.are.equal(p2, r[2].photo)
        assert.are.equal(1, state.getAllPhotosCalls)
    end)

    it("canonicalizes digit strings and numeric catalog IDs", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local p2 = fakePhoto(2, "/b.jpg")
        local catalog, _ = fakeCatalog({ p1, p2 })

        local r = PhotoLookup.resolveMany(catalog, { "001", 2 })

        assert.are.equal(p1, r[1].photo)
        assert.are.equal(p2, r[2].photo)
    end)

    it("rejects non-numeric and non-scalar identifiers before catalog access", function()
        local catalog, state = fakeCatalog({ fakePhoto(1, "/a.jpg") })
        local invalidIds = { "abc", true, {}, 1.5 }

        for _, invalidId in ipairs(invalidIds) do
            assert.has_error(function()
                PhotoLookup.resolveMany(catalog, { invalidId })
            end)
        end
        assert.are.equal(0, state.getAllPhotosCalls)
    end)

    it("rejects path-only identifiers", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local p2 = fakePhoto(2, "/b.jpg")
        local catalog, state = fakeCatalog({ p1, p2 })

        assert.has_error(function()
            PhotoLookup.resolveMany(catalog, { "/a.jpg", "/b.jpg" })
        end, "Path-only photo identity is unsupported; use catalog_id")
        assert.are.equal(0, state.getAllPhotosCalls)
    end)

    it("rejects a mixed batch containing a path-only identifier", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local p2 = fakePhoto(2, "/b.jpg")
        local p3 = fakePhoto(3, "/c.jpg")
        local catalog, state = fakeCatalog({ p1, p2, p3 })

        assert.has_error(function()
            PhotoLookup.resolveMany(catalog, { "1", "/b.jpg", "3" })
        end, "Path-only photo identity is unsupported; use catalog_id")
        assert.are.equal(0, state.getAllPhotosCalls)
    end)

    it("returns nil for unknown ids without erroring", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local catalog, _ = fakeCatalog({ p1 })

        local r = PhotoLookup.resolveMany(catalog, { "1", "999" })

        assert.are.equal(p1, r[1].photo)
        assert.is_nil(r[2].photo)
    end)

    it("preserves input order in results", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local p2 = fakePhoto(2, "/b.jpg")
        local catalog, _ = fakeCatalog({ p1, p2 })

        local r = PhotoLookup.resolveMany(catalog, { "2", "1", "1", "2" })

        assert.are.equal(p2, r[1].photo)
        assert.are.equal(p1, r[2].photo)
        assert.are.equal(p1, r[3].photo)
        assert.are.equal(p2, r[4].photo)
    end)

    it("handles empty input", function()
        local catalog, _ = fakeCatalog({})
        local r = PhotoLookup.resolveMany(catalog, {})
        assert.are.equal(0, #r)
    end)

    it("fails closed when a catalog ID is duplicated", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local p2 = fakePhoto(1, "/b.jpg")
        local catalog, _ = fakeCatalog({ p1, p2 })

        assert.has_error(function()
            PhotoLookup.resolveMany(catalog, { "1" })
        end, "Ambiguous catalog photo ID: 1")
    end)
end)

describe("PhotoLookup.resolveOne", function()
    before_each(loadModule)

    it("returns the matching photo by local id", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local catalog, _ = fakeCatalog({ p1 })
        assert.are.equal(p1, PhotoLookup.resolveOne(catalog, "1"))
    end)

    it("rejects path-only identity", function()
        local p1 = fakePhoto(1, "/a.jpg")
        local catalog, _ = fakeCatalog({ p1 })
        assert.has_error(function()
            PhotoLookup.resolveOne(catalog, "/a.jpg")
        end, "Path-only photo identity is unsupported; use catalog_id")
    end)

    it("returns nil when nothing matches", function()
        local catalog, _ = fakeCatalog({})
        assert.is_nil(PhotoLookup.resolveOne(catalog, "999"))
    end)
end)
