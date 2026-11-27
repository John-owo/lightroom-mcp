local LrApplication = import 'LrApplication'

local PhotoLookup = require 'PhotoLookup'
local PhotoIdentity = require 'PhotoIdentity'
local Log = require 'Log'
local JSON = require 'JSON'

local MetadataHandler = {}

-- Return the group only when it carries at least one value, so empty IPTC
-- sections are omitted from the response (consistent with the gps group)
-- instead of surfacing a table full of empty strings.
local function nonEmptyGroup(fields)
    for _, v in pairs(fields) do
        if v ~= nil and v ~= "" then return fields end
    end
    return nil
end

local function hslDevelopSettings(developSettings)
    return nonEmptyGroup({
        SaturationAdjustmentRed = developSettings.SaturationAdjustmentRed,
        SaturationAdjustmentOrange = developSettings.SaturationAdjustmentOrange,
        SaturationAdjustmentYellow = developSettings.SaturationAdjustmentYellow,
        SaturationAdjustmentGreen = developSettings.SaturationAdjustmentGreen,
        SaturationAdjustmentAqua = developSettings.SaturationAdjustmentAqua,
        SaturationAdjustmentBlue = developSettings.SaturationAdjustmentBlue,
        SaturationAdjustmentPurple = developSettings.SaturationAdjustmentPurple,
        SaturationAdjustmentMagenta = developSettings.SaturationAdjustmentMagenta,
        HueAdjustmentRed = developSettings.HueAdjustmentRed,
        HueAdjustmentOrange = developSettings.HueAdjustmentOrange,
        HueAdjustmentYellow = developSettings.HueAdjustmentYellow,
        HueAdjustmentGreen = developSettings.HueAdjustmentGreen,
        HueAdjustmentAqua = developSettings.HueAdjustmentAqua,
        HueAdjustmentBlue = developSettings.HueAdjustmentBlue,
        HueAdjustmentPurple = developSettings.HueAdjustmentPurple,
        HueAdjustmentMagenta = developSettings.HueAdjustmentMagenta,
        LuminanceAdjustmentRed = developSettings.LuminanceAdjustmentRed,
        LuminanceAdjustmentOrange = developSettings.LuminanceAdjustmentOrange,
        LuminanceAdjustmentYellow = developSettings.LuminanceAdjustmentYellow,
        LuminanceAdjustmentGreen = developSettings.LuminanceAdjustmentGreen,
        LuminanceAdjustmentAqua = developSettings.LuminanceAdjustmentAqua,
        LuminanceAdjustmentBlue = developSettings.LuminanceAdjustmentBlue,
        LuminanceAdjustmentPurple = developSettings.LuminanceAdjustmentPurple,
        LuminanceAdjustmentMagenta = developSettings.LuminanceAdjustmentMagenta,
    })
end

-- Bounds for the MaskGroupBasedCorrections readback clone.
local MASK_CLONE_MAX_DEPTH = 8
local MASK_CLONE_MAX_NODES = 20000

-- Keys whose values are Lightroom arrays even when empty, so they encode as
-- `[]` instead of `{}`.
local MASK_ARRAY_KEYS = { CorrectionMasks = true }

local function isFiniteNumber(value)
    return value == value and value ~= math.huge and value ~= -math.huge
end

-- Bounded deep clone of a mask table into JSON-safe values. Returns
-- (clone, true) or (nil, false) when the table holds anything that cannot be
-- represented faithfully as JSON: functions/userdata, non-finite numbers,
-- cycles, sparse or mixed-key arrays, or tables over the depth/node caps.
local function cloneMaskValue(value, depth, state, arrayWhenEmpty)
    state.nodes = state.nodes + 1
    if state.nodes > MASK_CLONE_MAX_NODES then
        return nil, false
    end

    local valueType = type(value)
    if valueType == "string" or valueType == "boolean" then
        return value, true
    end
    if valueType == "number" then
        if not isFiniteNumber(value) then return nil, false end
        return value, true
    end
    if valueType ~= "table" or depth >= MASK_CLONE_MAX_DEPTH or state.seen[value] then
        return nil, false
    end

    local count, maxIndex, hasStringKeys = 0, 0, false
    for key, _ in pairs(value) do
        local keyType = type(key)
        if keyType == "string" then
            hasStringKeys = true
        elseif keyType == "number" and key >= 1 and key == math.floor(key) and isFiniteNumber(key) then
            if key > maxIndex then maxIndex = key end
        else
            return nil, false
        end
        count = count + 1
    end

    local isArray = not hasStringKeys and (count > 0 or arrayWhenEmpty)
    if isArray and maxIndex ~= count then
        return nil, false -- sparse array
    end
    if hasStringKeys and maxIndex > 0 then
        return nil, false -- mixed array/object keys would lose entries in JSON
    end

    state.seen[value] = true
    local out
    if isArray then
        out = JSON.array({})
        for index = 1, count do
            local cloned, ok = cloneMaskValue(value[index], depth + 1, state, false)
            if not ok then
                state.seen[value] = nil
                return nil, false
            end
            out[index] = cloned
        end
    else
        out = {}
        for key, item in pairs(value) do
            local cloned, ok = cloneMaskValue(item, depth + 1, state, MASK_ARRAY_KEYS[key] == true)
            if not ok then
                state.seen[value] = nil
                return nil, false
            end
            out[key] = cloned
        end
    end
    state.seen[value] = nil
    return out, true
end

-- Read back the photo's local-mask table. Never raises: an unreadable table
-- is reported through `maskReadback` instead of failing get_photo_metadata.
--   "ok"                 - MaskGroupBasedCorrections holds a cloned array
--   "absent"             - Lightroom returned no mask table; `[]` returned
--   "unsupported_values" - table could not be serialized; field omitted
local function readMaskGroupBasedCorrections(developSettings)
    local raw = type(developSettings) == "table" and developSettings.MaskGroupBasedCorrections or nil
    if raw == nil then
        return JSON.array({}), "absent"
    end
    if type(raw) ~= "table" then
        return nil, "unsupported_values"
    end

    local okCall, cloned, supported = pcall(cloneMaskValue, raw, 0, { nodes = 0, seen = {} }, true)
    if not okCall or not supported or not JSON.isArray(cloned) then
        return nil, "unsupported_values"
    end
    return cloned, "ok"
end

function MetadataHandler.getPhotoMetadata(args)
    if not args.photo_id then
        error("photo_id is required")
    end

    local catalog = LrApplication.activeCatalog()
    local photoData = nil

    catalog:withReadAccessDo(function()
        local photo = PhotoLookup.resolveOne(catalog, args.photo_id)

        if not photo then
            error("Photo not found: " .. args.photo_id)
        end

        -- Get keywords
        local keywords = {}
        local photoKeywords = photo:getRawMetadata('keywords')
        if photoKeywords then
            for _, kw in ipairs(photoKeywords) do
                table.insert(keywords, kw:getName())
            end
        end

        -- Get develop settings
        local developSettings = photo:getDevelopSettings()
        local maskCorrections, maskReadback = readMaskGroupBasedCorrections(developSettings)

        -- GPS is a raw {latitude, longitude} table; omit the group when absent
        -- or when present but carrying no coordinates.
        local gps = photo:getRawMetadata('gps')
        local gpsData = nil
        if gps then
            gpsData = nonEmptyGroup({
                latitude = gps.latitude,
                longitude = gps.longitude,
                altitude = photo:getRawMetadata('gpsAltitude'),
            })
        end

        photoData = {
            id = photo.localIdentifier,
            path = photo:getRawMetadata('path'),
            filename = photo:getFormattedMetadata('fileName'),
            rating = photo:getRawMetadata('rating'),
            colorLabel = photo:getRawMetadata('colorNameForLabel'),
            pickStatus = photo:getRawMetadata('pickStatus'),
            keywords = keywords,
            -- Title / caption / headline (IPTC content description).
            title = photo:getFormattedMetadata('title'),
            caption = photo:getFormattedMetadata('caption'),
            headline = photo:getFormattedMetadata('headline'),
            -- EXIF capture data.
            dateTimeOriginal = photo:getFormattedMetadata('dateTimeOriginal'),
            dateTimeDigitized = photo:getFormattedMetadata('dateTimeDigitized'),
            cameraMake = photo:getFormattedMetadata('cameraMake'),
            cameraModel = photo:getFormattedMetadata('cameraModel'),
            cameraSerialNumber = photo:getFormattedMetadata('cameraSerialNumber'),
            lens = photo:getFormattedMetadata('lens'),
            isoSpeedRating = photo:getFormattedMetadata('isoSpeedRating'),
            focalLength = photo:getFormattedMetadata('focalLength'),
            focalLength35mm = photo:getFormattedMetadata('focalLength35mm'),
            aperture = photo:getFormattedMetadata('aperture'),
            shutterSpeed = photo:getFormattedMetadata('shutterSpeed'),
            exposureBias = photo:getFormattedMetadata('exposureBias'),
            exposureProgram = photo:getFormattedMetadata('exposureProgram'),
            meteringMode = photo:getFormattedMetadata('meteringMode'),
            flash = photo:getFormattedMetadata('flash'),
            dimensions = photo:getFormattedMetadata('dimensions'),
            fileSize = photo:getFormattedMetadata('fileSize'),
            fileFormat = photo:getRawMetadata('fileFormat'),
            artist = photo:getFormattedMetadata('artist'),
            software = photo:getFormattedMetadata('software'),
            gps = gpsData,
            -- IPTC location ("Sublocation" is the SDK `location` field).
            location = nonEmptyGroup({
                sublocation = photo:getFormattedMetadata('location'),
                city = photo:getFormattedMetadata('city'),
                stateProvince = photo:getFormattedMetadata('stateProvince'),
                country = photo:getFormattedMetadata('country'),
                isoCountryCode = photo:getFormattedMetadata('isoCountryCode'),
            }),
            copyright = nonEmptyGroup({
                creator = photo:getFormattedMetadata('creator'),
                notice = photo:getFormattedMetadata('copyright'),
                status = photo:getFormattedMetadata('copyrightState'),
                rightsUsageTerms = photo:getFormattedMetadata('rightsUsageTerms'),
            }),
            developSettings = {
                whiteBalance = developSettings.WhiteBalance,
                temperature = developSettings.Temperature,
                tint = developSettings.Tint,
                exposure = developSettings.Exposure2012,
                contrast = developSettings.Contrast2012,
                highlights = developSettings.Highlights2012,
                shadows = developSettings.Shadows2012,
                whites = developSettings.Whites2012,
                blacks = developSettings.Blacks2012,
                texture = developSettings.Texture,
                clarity = developSettings.Clarity2012,
                dehaze = developSettings.Dehaze,
                vibrance = developSettings.Vibrance,
                saturation = developSettings.Saturation,
                hsl = hslDevelopSettings(developSettings),
                -- Raw Lightroom local-mask table (read side of
                -- set_develop_settings MaskGroupBasedCorrections, which
                -- replaces the whole set: merge before writing).
                MaskGroupBasedCorrections = maskCorrections,
                maskReadback = maskReadback,
            }
        }
        PhotoIdentity.enrich(photoData, photo)
    end)

    Log.info("Retrieved metadata for photo: " .. args.photo_id)

    return photoData
end

return MetadataHandler
