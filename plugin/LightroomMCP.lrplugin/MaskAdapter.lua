-- Narrow adapter for the MaskGroupBasedCorrections SDK/XMP shape.
--
-- This module deliberately owns no Lightroom or catalog calls. It validates
-- the public, non-opaque Brush contract, builds a deterministic correction
-- group, and proves that a readback contains exactly that group in addition
-- to the caller's previous mask tree.
local MaskAdapter = {}

MaskAdapter.SCHEMA = "MaskGroupBasedCorrections.v1"
MaskAdapter.MAX_NAME_LENGTH = 128
MaskAdapter.MAX_PATH_POINTS = 4096

local OPERATION_ID_PATTERN = "^[A-Za-z0-9][A-Za-z0-9%._%-]*$"

local LOCAL_SETTINGS = {
    exposure = { key = "LocalExposure2012", minimum = -5, maximum = 5 },
    contrast = { key = "LocalContrast2012", minimum = -100, maximum = 100 },
    highlights = { key = "LocalHighlights2012", minimum = -100, maximum = 100 },
    shadows = { key = "LocalShadows2012", minimum = -100, maximum = 100 },
    whites = { key = "LocalWhites2012", minimum = -100, maximum = 100 },
    blacks = { key = "LocalBlacks2012", minimum = -100, maximum = 100 },
    temperature = { key = "LocalTemperature", minimum = -100, maximum = 100 },
    tint = { key = "LocalTint", minimum = -100, maximum = 100 },
    texture = { key = "LocalTexture", minimum = -100, maximum = 100 },
    clarity = { key = "LocalClarity2012", minimum = -100, maximum = 100 },
    dehaze = { key = "LocalDehaze", minimum = -100, maximum = 100 },
    saturation = { key = "LocalSaturation", minimum = -100, maximum = 100 },
    sharpness = { key = "LocalSharpness", minimum = -100, maximum = 100 },
    luminance_noise = { key = "LocalLuminanceNoise", minimum = -100, maximum = 100 },
    moire = { key = "LocalMoire", minimum = -100, maximum = 100 },
    defringe = { key = "LocalDefringe", minimum = -100, maximum = 100 },
    hue = { key = "LocalHue", minimum = -100, maximum = 100 },
}

local function fail(message)
    error(message, 0)
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and math.abs(value) ~= math.huge
end

local function isArray(value, minimum, maximum)
    if type(value) ~= "table" then return false end
    local count = 0
    for key, _ in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
        count = count + 1
    end
    if count ~= #value or count < minimum then return false end
    return maximum == nil or count <= maximum
end

local function requireString(value, name, maximum)
    if type(value) ~= "string" or value == "" then
        fail(name .. " is required")
    end
    if maximum and #value > maximum then
        fail(name .. " is too long")
    end
end

local function requireFiniteRange(value, name, minimum, maximum)
    if not isFiniteNumber(value) then
        fail(name .. " must be a finite number")
    end
    if value < minimum or value > maximum then
        fail(name .. " is outside the supported range")
    end
end

local function requireExactKeys(value, allowed, required, name)
    if type(value) ~= "table" then fail(name .. " must be an object") end
    local present = {}
    for key, _ in pairs(value) do
        if type(key) ~= "string" or not allowed[key] then
            fail(name .. " contains an unsupported field: " .. tostring(key))
        end
        present[key] = true
    end
    for _, key in ipairs(required or {}) do
        if not present[key] then
            fail(name .. " requires " .. key)
        end
    end
end

local function validateBrushParameters(parameters)
    local allowed = {
        coordinate_system = true,
        coordinate_units = true,
        path = true,
        size = true,
        feather = true,
        flow = true,
        density = true,
    }
    requireExactKeys(parameters, allowed, {
        "coordinate_system", "coordinate_units", "path", "size",
        "feather", "flow", "density",
    }, "kind_parameters")
    if parameters.coordinate_system ~= "normalized_image" then
        fail("kind_parameters.coordinate_system must be normalized_image")
    end
    if parameters.coordinate_units ~= "unit_interval" then
        fail("kind_parameters.coordinate_units must be unit_interval")
    end
    if not isArray(parameters.path, 1, MaskAdapter.MAX_PATH_POINTS) then
        fail("kind_parameters.path must be a non-empty array of points")
    end
    for index, point in ipairs(parameters.path) do
        requireExactKeys(point, { x = true, y = true }, { "x", "y" },
            "kind_parameters.path[" .. tostring(index) .. "]")
        requireFiniteRange(point.x, "kind_parameters.path[" .. tostring(index) .. "].x", 0, 1)
        requireFiniteRange(point.y, "kind_parameters.path[" .. tostring(index) .. "].y", 0, 1)
    end
    requireFiniteRange(parameters.size, "kind_parameters.size", 0, 1)
    if parameters.size <= 0 then fail("kind_parameters.size must be greater than zero") end
    requireFiniteRange(parameters.feather, "kind_parameters.feather", 0, 1)
    requireFiniteRange(parameters.flow, "kind_parameters.flow", 0, 1)
    requireFiniteRange(parameters.density, "kind_parameters.density", 0, 1)
end

local function validateLocalSettings(settings)
    if type(settings) ~= "table" then fail("local_settings must be an object") end
    local count = 0
    for key, value in pairs(settings) do
        if type(key) ~= "string" or not LOCAL_SETTINGS[key] then
            fail("local_settings contains an unsupported field: " .. tostring(key))
        end
        local descriptor = LOCAL_SETTINGS[key]
        requireFiniteRange(value, "local_settings." .. key, descriptor.minimum, descriptor.maximum)
        count = count + 1
    end
    if count == 0 then fail("local_settings requires at least one setting") end
end

function MaskAdapter.validateArguments(args)
    if type(args) ~= "table" then fail("Arguments are required") end
    requireExactKeys(args, {
        photo_id = true,
        expected_photo_uuid = true,
        expected_master_uuid = true,
        operation_id = true,
        mask_kind = true,
        name = true,
        kind_parameters = true,
        local_settings = true,
    }, {
        "photo_id", "expected_photo_uuid", "expected_master_uuid", "operation_id",
        "mask_kind", "name", "kind_parameters", "local_settings",
    }, "arguments")
    if type(args.photo_id) ~= "number" and type(args.photo_id) ~= "string" then
        fail("photo_id must be a catalog identifier")
    end
    requireString(args.expected_photo_uuid, "expected_photo_uuid")
    requireString(args.expected_master_uuid, "expected_master_uuid")
    requireString(args.operation_id, "operation_id", 64)
    if args.operation_id:match(OPERATION_ID_PATTERN) == nil then
        fail("operation_id must be a 1-64 character ASCII token")
    end
    if args.mask_kind ~= "brush" and args.mask_kind ~= "subject" and args.mask_kind ~= "sky" then
        fail("mask_kind must be brush, subject, or sky")
    end
    requireString(args.name, "name", MaskAdapter.MAX_NAME_LENGTH)
    if args.name:match("%S") == nil then fail("name must contain a non-whitespace character") end
    if args.name:find("%c") ~= nil then fail("name must not contain control characters") end
    if args.mask_kind == "brush" then
        validateBrushParameters(args.kind_parameters)
    else
        requireExactKeys(args.kind_parameters, {}, {}, "kind_parameters")
    end
    validateLocalSettings(args.local_settings)
end

local function cloneSerializable(value, depth, seen)
    local valueType = type(value)
    if valueType == "number" or valueType == "string" or valueType == "boolean" then
        if valueType == "number" and not isFiniteNumber(value) then return nil, false end
        return value, true
    end
    if valueType ~= "table" or depth >= 16 or seen[value] then
        return nil, false
    end

    seen[value] = true
    local result = {}
    local count = 0
    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then
            seen[value] = nil
            return nil, false
        end
        count = count + 1
        if count > 10000 then
            seen[value] = nil
            return nil, false
        end
        local cloned, supported = cloneSerializable(item, depth + 1, seen)
        if not supported then
            seen[value] = nil
            return nil, false
        end
        result[key] = cloned
    end
    seen[value] = nil
    return result, true
end

function MaskAdapter.clone(value)
    return cloneSerializable(value, 0, {})
end

local function numbersEqual(left, right)
    if left == right then return true end
    if not isFiniteNumber(left) or not isFiniteNumber(right) then return false end
    return math.abs(left - right) <= 0.000001
end

local function deepEqual(left, right)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then
        if type(left) == "number" then return numbersEqual(left, right) end
        return left == right
    end
    for key, value in pairs(left) do
        if not deepEqual(value, right[key]) then return false end
    end
    for key, _ in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

function MaskAdapter.deepEqual(left, right)
    return deepEqual(left, right)
end

local function hash32(value, seed)
    local hash = seed
    for index = 1, #value do
        hash = (hash * 16777619 + value:byte(index)) % 4294967291
    end
    return math.floor(hash)
end

local function deterministicId(operationId, kind)
    local value = operationId .. "|" .. kind
    local a = hash32(value, 2166136261)
    local b = hash32(value .. "|b", 2246822519)
    local c = hash32(value .. "|c", 3266489917)
    local d = hash32(value .. "|d", 668265263)
    return string.format("%08x-%04x-%04x-%04x-%08x%04x",
        a, math.floor(b / 65536), b % 65536, math.floor(c / 65536),
        c % 65536, d % 65536)
end

function MaskAdapter.identities(args)
    local identityScope = args.expected_photo_uuid .. "|"
        .. args.expected_master_uuid .. "|" .. args.operation_id
    return {
        correction_id = deterministicId(identityScope, "correction"),
        mask_id = deterministicId(identityScope, "mask"),
    }
end

local function canonicalDabs(path)
    local dabs = {}
    for index, point in ipairs(path) do
        dabs[index] = string.format("d %.6f %.6f", point.x, point.y)
    end
    return dabs
end

local function correctionLocalSettings(settings)
    local result = {}
    for name, value in pairs(settings) do
        result[LOCAL_SETTINGS[name].key] = value
    end
    return result
end

function MaskAdapter.buildCorrection(args, ids)
    if args.mask_kind ~= "brush" then
        fail("Only Brush has an enabled creation adapter")
    end
    local parameters = args.kind_parameters
    local mask = {
        What = "Mask/Paint",
        MaskActive = true,
        MaskName = args.name,
        MaskSyncID = ids.mask_id,
        MaskValue = parameters.density,
        Radius = parameters.size,
        Feather = parameters.feather,
        Flow = parameters.flow,
        CenterWeight = 1 - parameters.feather,
        Dabs = canonicalDabs(parameters.path),
    }
    local correction = {
        What = "Correction",
        CorrectionActive = true,
        CorrectionAmount = 1,
        CorrectionName = args.name,
        CorrectionSyncID = ids.correction_id,
        CorrectionMasks = { mask },
    }
    for key, value in pairs(correctionLocalSettings(args.local_settings)) do
        correction[key] = value
    end
    return correction
end

local function treeIsArray(tree)
    if type(tree) ~= "table" then return false end
    local count = 0
    for key, _ in pairs(tree) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then return false end
        count = count + 1
    end
    return count == #tree
end

local function correctionShapeIsKnown(correction)
    if type(correction) ~= "table" or type(correction.CorrectionMasks) ~= "table" then
        return false
    end
    if not treeIsArray(correction.CorrectionMasks) then return false end
    for _, mask in ipairs(correction.CorrectionMasks) do
        if type(mask) ~= "table" or type(mask.What) ~= "string" then return false end
    end
    return true
end

local function schemaState(settings)
    if type(settings) ~= "table" then return nil end
    if settings.EnableMaskGroupBasedCorrections == true
        and settings.MaskGroupBasedCorrections == nil then
        return "unmaterialized_empty"
    end
    if settings.EnableMaskGroupBasedCorrections ~= true then return nil end
    local tree = settings.MaskGroupBasedCorrections
    if not treeIsArray(tree) then return nil end
    for _, correction in ipairs(tree) do
        if not correctionShapeIsKnown(correction) then return nil end
    end
    return "materialized"
end

local function schemaDiagnostic(settings)
    if type(settings) ~= "table" then return "settings=" .. type(settings) end
    local enable = settings.EnableMaskGroupBasedCorrections
    local tree = settings.MaskGroupBasedCorrections
    local enableShape = enable == nil
        and "absent"
        or (type(enable) .. ":" .. tostring(enable))
    local treeShape = tree == nil
        and "absent"
        or type(tree)
    if type(tree) == "table" then
        treeShape = treeShape
            .. ":array=" .. tostring(treeIsArray(tree))
            .. ":count=" .. tostring(#tree)
    end
    return "enable=" .. enableShape .. ", tree=" .. treeShape
end

function MaskAdapter.schemaSupported(settings)
    return schemaState(settings) == "materialized"
end

function MaskAdapter.processVersion(settings)
    local value = settings.ProcessVersion
        or settings.ProcessVersion2012
        or settings.Version
        or settings.CompatibleVersion
    if value == nil then return "unknown" end
    return tostring(value)
end

local function unmaterializedEmptySchemaKnown(settings, lightroomVersion)
    return schemaState(settings) == "unmaterialized_empty"
        and lightroomVersion == "15.5.1"
        and MaskAdapter.processVersion(settings) == "15.4"
end

function MaskAdapter.unverifiedPersistentLocalSettings(settings, lightroomVersion, processVersion)
    if lightroomVersion ~= "15.5.1" or tostring(processVersion) ~= "15.4" then return {} end
    local verified = { exposure = true }
    local result = {}
    for name, _ in pairs(settings or {}) do
        if not verified[name] then table.insert(result, name) end
    end
    table.sort(result)
    return result
end

local function majorVersion(version)
    if type(version) ~= "string" then return nil end
    return tonumber(version:match("^(%d+)"))
end

function MaskAdapter.capability(settings, lightroomVersion, checkpointAvailable, applyAvailable)
    local state = schemaState(settings)
    local processVersion = MaskAdapter.processVersion(settings)
    local runtimeMajor = majorVersion(lightroomVersion)
    local processMajor = majorVersion(processVersion)
    local unmaterializedEmptyKnown = unmaterializedEmptySchemaKnown(settings, lightroomVersion)
    local schemaKnown = state == "materialized" or unmaterializedEmptyKnown
    local supported = schemaKnown
        and runtimeMajor ~= nil
        and runtimeMajor >= 11
        and processMajor ~= nil
        and processMajor >= 11
        and checkpointAvailable
        and applyAvailable
    local reason
    if state == "unmaterialized_empty" and not unmaterializedEmptyKnown then
        reason = "Unmaterialized empty mask schema is not verified for this Lightroom/process version"
    elseif not schemaKnown then
        reason = "MaskGroupBasedCorrections schema is unavailable or unrecognized ("
            .. schemaDiagnostic(settings)
            .. ")"
    elseif runtimeMajor == nil or runtimeMajor < 11 then
        reason = "Running Lightroom version does not expose the supported mask schema"
    elseif processMajor == nil or processMajor < 11 then
        reason = "Develop process version is unavailable"
    elseif not checkpointAvailable then
        reason = "Plugin Develop preset checkpoint API is unavailable"
    elseif not applyAvailable then
        reason = "Photo develop-settings write API is unavailable"
    end
    local brushReason = supported and nil or reason
    local aiReason = "AI Subject/Sky creation and payload readback adapter is not enabled"
    return {
        lightroom_version = lightroomVersion,
        process_version = processVersion,
        mask_schema = schemaKnown and MaskAdapter.SCHEMA or "unknown",
        kinds = {
            brush = {
                supported = supported,
                accepted_parameters = {
                    "coordinate_system", "coordinate_units", "path", "size",
                    "feather", "flow", "density",
                },
                readback_guarantees = supported and {
                    "MaskSyncID", "CorrectionSyncID", "Mask/Paint Dabs",
                    "Radius", "Feather", "Flow", "MaskValue", "local settings",
                } or {},
                reason = brushReason,
            },
            subject = {
                supported = false,
                accepted_parameters = {},
                readback_guarantees = {},
                reason = aiReason,
            },
            sky = {
                supported = false,
                accepted_parameters = {},
                readback_guarantees = {},
                reason = aiReason,
            },
        },
    }
end

function MaskAdapter.appendCorrection(settings, correction, lightroomVersion)
    local state = schemaState(settings)
    if not state then fail("MaskGroupBasedCorrections schema is unavailable or unrecognized") end
    if state == "unmaterialized_empty"
        and not unmaterializedEmptySchemaKnown(settings, lightroomVersion) then
        fail("Unmaterialized empty mask schema is not verified for this Lightroom/process version")
    end
    local updated, supported = cloneSerializable(settings, 0, {})
    if not supported then fail("Develop settings contain unsupported nested values") end
    updated.EnableMaskGroupBasedCorrections = true
    updated.MaskGroupBasedCorrections = updated.MaskGroupBasedCorrections or {}
    table.insert(updated.MaskGroupBasedCorrections, correction)
    return updated
end

local function settingsWithoutMaskTree(settings)
    local result, supported = cloneSerializable(settings, 0, {})
    if not supported then return nil, false end
    result.MaskGroupBasedCorrections = nil
    result.EnableMaskGroupBasedCorrections = nil
    return result, true
end

local function boundedValue(value)
    local result = tostring(value)
    if #result > 96 then return result:sub(1, 96) .. "..." end
    return result
end

local function boundedArray(value, maximum)
    if type(value) ~= "table" then return "<" .. type(value) .. ">" end
    local results = {}
    for index, item in ipairs(value) do
        if index > maximum then
            table.insert(results, "...")
            break
        end
        table.insert(results, boundedValue(item))
    end
    return "[" .. table.concat(results, "|") .. "]"
end

local function parsedDab(value)
    if type(value) ~= "string" then return nil end
    local x, y = value:match("^d%s+([%+%-]?[%d%.]+)%s+([%+%-]?[%d%.]+)$")
    x, y = tonumber(x), tonumber(y)
    if not isFiniteNumber(x) or not isFiniteNumber(y) then return nil end
    return x, y
end

local function dabsMismatch(actual, expected, parameters)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        return "Dabs expected=" .. boundedArray(expected, 16)
            .. " actual=" .. boundedArray(actual, 16)
    end
    local actualIndex = 1
    local flow = type(actual[1]) == "string"
        and tonumber(actual[1]:match("^f%s+([%+%-]?[%d%.]+)$"))
        or nil
    if flow ~= nil then
        if not isFiniteNumber(flow) or not numbersEqual(flow, parameters.flow) then
            return "Dabs flow expected=" .. boundedValue(parameters.flow)
                .. " actual=" .. boundedValue(flow)
        end
        actualIndex = 2
    end
    if (#actual - actualIndex + 1) ~= #expected then
        return "Dabs expected=" .. boundedArray(expected, 16)
            .. " actual=" .. boundedArray(actual, 16)
    end
    for expectedIndex, expectedDab in ipairs(expected) do
        local actualDab = actual[actualIndex + expectedIndex - 1]
        local actualX, actualY = parsedDab(actualDab)
        local expectedX, expectedY = parsedDab(expectedDab)
        if actualX == nil or expectedX == nil
            or not numbersEqual(actualX, expectedX)
            or not numbersEqual(actualY, expectedY) then
            return "Dabs expected=" .. boundedArray(expected, 16)
                .. " actual=" .. boundedArray(actual, 16)
        end
    end
    return nil
end

local function normalizedFeather(mask, allowCenterWeightFallback)
    if not mask or type(mask) ~= "table" then return nil end
    if mask.Feather ~= nil then
        if isFiniteNumber(mask.Feather) then return mask.Feather end
        return nil
    end
    if allowCenterWeightFallback and isFiniteNumber(mask.CenterWeight) then
        return 1 - mask.CenterWeight
    end
    return nil
end

local function maskPayloadMismatch(mask, expected, args, allowCenterWeightFallback)
    if type(mask) ~= "table" then return "mask_type=" .. type(mask) end
    if mask.What ~= "Mask/Paint" then
        return "What expected=Mask/Paint actual=" .. boundedValue(mask.What)
    end
    if mask.MaskActive ~= true then
        return "MaskActive expected=true actual=" .. boundedValue(mask.MaskActive)
    end
    if mask.MaskInverted ~= nil and mask.MaskInverted ~= false then
        return "MaskInverted expected=false actual=" .. boundedValue(mask.MaskInverted)
    end
    if mask.MaskBlendMode ~= nil and not numbersEqual(mask.MaskBlendMode, 0) then
        return "MaskBlendMode expected=0 actual=" .. boundedValue(mask.MaskBlendMode)
    end
    if mask.MaskName ~= args.name then
        return "MaskName expected=" .. boundedValue(args.name)
            .. " actual=" .. boundedValue(mask.MaskName)
    end
    local parameters = args.kind_parameters
    local dabError = dabsMismatch(mask.Dabs, expected.Dabs, parameters)
    if dabError then return dabError end
    local numericFields = {
        { "Radius", parameters.size },
        { "Feather", parameters.feather, normalizedFeather(mask, allowCenterWeightFallback) },
        { "Flow", parameters.flow },
        { "MaskValue", parameters.density },
        { "CenterWeight", 1 - parameters.feather },
    }
    for _, field in ipairs(numericFields) do
        local actual = field[3] == nil and mask[field[1]] or field[3]
        if not numbersEqual(actual, field[2]) then
            return field[1] .. " expected=" .. boundedValue(field[2])
                .. " actual=" .. boundedValue(actual)
        end
    end
    return nil
end

local function maskPayloadMatches(mask, expected, args, allowCenterWeightFallback)
    return maskPayloadMismatch(mask, expected, args, allowCenterWeightFallback) == nil
end

local IMPLICIT_LOCAL_DEFAULTS = {
    LocalCurveRefineSaturation = 100,
}

local function localSettingsMismatch(correction, settings)
    if type(correction) ~= "table" then return "correction_type=" .. type(correction) end
    local expectedKeys = {}
    for name, expected in pairs(settings) do
        local descriptor = LOCAL_SETTINGS[name]
        expectedKeys[descriptor.key] = true
        if not numbersEqual(correction[descriptor.key], expected) then
            return descriptor.key .. " expected=" .. boundedValue(expected)
                .. " actual=" .. boundedValue(correction[descriptor.key])
        end
    end
    for _, descriptor in pairs(LOCAL_SETTINGS) do
        local key = descriptor.key
        if not expectedKeys[key] and correction[key] ~= nil
            and not numbersEqual(correction[key], 0) then
            return key .. " was not requested; actual=" .. boundedValue(correction[key])
        end
    end
    for key, value in pairs(correction) do
        if type(key) == "string" and key:match("^Local")
            and not expectedKeys[key] then
            local known = false
            for _, descriptor in pairs(LOCAL_SETTINGS) do
                if descriptor.key == key then
                    known = true
                    break
                end
            end
            if not known then
                local implicitDefault = IMPLICIT_LOCAL_DEFAULTS[key]
                if implicitDefault == nil or not numbersEqual(value, implicitDefault) then
                    return key .. " is not a verified implicit default; actual=" .. boundedValue(value)
                end
            end
        end
    end
    return nil
end

local function localSettingsMatch(correction, settings)
    return localSettingsMismatch(correction, settings) == nil
end

local function correctionPayloadMismatch(correction, args)
    if type(correction) ~= "table" then return "correction_type=" .. type(correction) end
    if correction.What ~= "Correction" then
        return "What expected=Correction actual=" .. boundedValue(correction.What)
    end
    if correction.CorrectionActive ~= true then
        return "CorrectionActive expected=true actual=" .. boundedValue(correction.CorrectionActive)
    end
    if not numbersEqual(correction.CorrectionAmount, 1) then
        return "CorrectionAmount expected=1 actual=" .. boundedValue(correction.CorrectionAmount)
    end
    return localSettingsMismatch(correction, args.local_settings)
end

local function correctionPayloadMatches(correction, args)
    return correctionPayloadMismatch(correction, args) == nil
end

local function boundedLocalKeyValues(correction)
    if type(correction) ~= "table" then return "<" .. type(correction) .. ">" end
    local keys = {}
    for key, _ in pairs(correction) do
        if type(key) == "string" and key:match("^Local") then table.insert(keys, key) end
    end
    table.sort(keys)
    local results = {}
    for index, key in ipairs(keys) do
        if index > 32 then
            table.insert(results, "...")
            break
        end
        table.insert(results, key .. "=" .. boundedValue(correction[key]))
    end
    return "[" .. table.concat(results, ",") .. "]"
end

local function boundedCorrectionKeyValues(correction)
    if type(correction) ~= "table" then return "<" .. type(correction) .. ">" end
    local keys = {}
    for key, _ in pairs(correction) do
        if type(key) == "string" then table.insert(keys, key) end
    end
    table.sort(keys)
    local results = {}
    for index, key in ipairs(keys) do
        if index > 64 then
            table.insert(results, "...")
            break
        end
        local value = correction[key]
        table.insert(results, key .. "=" .. (type(value) == "table"
            and "<table:" .. tostring(#value) .. ">"
            or boundedValue(value)))
    end
    return "[" .. table.concat(results, ",") .. "]"
end

local function boundedMaskKeyValues(mask)
    if type(mask) ~= "table" then return "<" .. type(mask) .. ">" end
    local keys = {}
    for key, _ in pairs(mask) do
        if type(key) == "string" then table.insert(keys, key) end
    end
    table.sort(keys)
    local results = {}
    for index, key in ipairs(keys) do
        if index > 64 then
            table.insert(results, "...")
            break
        end
        local value = mask[key]
        table.insert(results, key .. "=" .. (type(value) == "table"
            and "<table:" .. tostring(#value) .. ">"
            or boundedValue(value)))
    end
    return "[" .. table.concat(results, ",") .. "]"
end

local function readbackGeometry(mask)
    if type(mask.Dabs) ~= "table" or not isArray(mask.Dabs, 1) then return nil end
    local bounds = { x_min = 1, x_max = 0, y_min = 1, y_max = 0 }
    local points = {}
    local startIndex = 1
    local normalizedFlow = type(mask.Dabs[1]) == "string"
        and tonumber(mask.Dabs[1]:match("^f%s+([%+%-]?[%d%.]+)$"))
        or nil
    if normalizedFlow ~= nil then
        if not isFiniteNumber(normalizedFlow) or not numbersEqual(normalizedFlow, mask.Flow) then
            return nil
        end
        startIndex = 2
    end
    for index = startIndex, #mask.Dabs do
        local x, y = parsedDab(mask.Dabs[index])
        if x == nil then return nil end
        if not isFiniteNumber(x) or not isFiniteNumber(y) or x < 0 or x > 1 or y < 0 or y > 1 then
            return nil
        end
        table.insert(points, { x = x, y = y })
        if x < bounds.x_min then bounds.x_min = x end
        if x > bounds.x_max then bounds.x_max = x end
        if y < bounds.y_min then bounds.y_min = y end
        if y > bounds.y_max then bounds.y_max = y end
    end
    return {
        coordinate_system = "normalized_image",
        coordinate_units = "unit_interval",
        point_count = #points,
        bounds = bounds,
        _points = points,
    }
end

local function readbackParameters(mask, allowCenterWeightFallback)
    local geometry = readbackGeometry(mask)
    if not geometry then return nil end
    local path = geometry._points
    geometry._points = nil
    return {
        coordinate_system = "normalized_image",
        coordinate_units = "unit_interval",
        path = path,
        size = mask.Radius,
        feather = normalizedFeather(mask, allowCenterWeightFallback),
        flow = mask.Flow,
        density = mask.MaskValue,
    }, geometry
end

local function readbackLocalSettings(correction, settings)
    local result = {}
    for name, _ in pairs(settings) do
        local descriptor = LOCAL_SETTINGS[name]
        result[name] = correction[descriptor.key]
    end
    return result
end

local function boundedIdentityList(tree, key, nestedKey)
    local values = {}
    for _, correction in ipairs(tree or {}) do
        local candidates = nestedKey and correction[nestedKey] or { correction }
        for _, candidate in ipairs(candidates or {}) do
            if type(candidate) == "table" and candidate[key] ~= nil then
                local value = tostring(candidate[key])
                if #value > 96 then value = value:sub(1, 96) .. "..." end
                table.insert(values, value)
                if #values >= 8 then return values end
            end
        end
    end
    return values
end

local function identityDiagnostic(tree, ids)
    local correctionIds = boundedIdentityList(tree, "CorrectionSyncID")
    local maskIds = boundedIdentityList(tree, "MaskSyncID", "CorrectionMasks")
    return "expected correction_id=" .. tostring(ids.correction_id)
        .. ", mask_id=" .. tostring(ids.mask_id)
        .. "; found correction_ids=[" .. table.concat(correctionIds, ",")
        .. "], mask_ids=[" .. table.concat(maskIds, ",") .. "]"
end

local function rewriteDiagnostic(tree, beforeTree, expectedCorrection, args, allowCenterWeightFallback)
    local results = {}
    for correctionIndex, correction in ipairs(tree or {}) do
        if #results >= 4 then break end
        local masks = type(correction) == "table" and correction.CorrectionMasks or nil
        local mask = type(masks) == "table" and #masks == 1 and masks[1] or nil
        local remaining = {}
        for index, item in ipairs(tree) do
            if index ~= correctionIndex then table.insert(remaining, item) end
        end
        table.insert(results,
            "index=" .. tostring(correctionIndex)
            .. ",CorrectionName=" .. boundedValue(type(correction) == "table" and correction.CorrectionName)
            .. ",mask_count=" .. tostring(type(masks) == "table" and #masks or -1)
            .. ",payload=" .. (maskPayloadMismatch(
                mask,
                expectedCorrection.CorrectionMasks[1],
                args,
                allowCenterWeightFallback
            ) or "ok")
            .. ",correction=" .. boundedValue(correctionPayloadMismatch(correction, args) or "ok")
            .. ",local_keys=" .. boundedLocalKeyValues(correction)
            .. ",correction_keys=" .. boundedCorrectionKeyValues(correction)
            .. ",mask_keys=" .. boundedMaskKeyValues(mask)
            .. ",delta=" .. tostring(deepEqual(remaining, beforeTree)))
    end
    return "rewrite_candidates=[" .. table.concat(results, ";") .. "]"
end

function MaskAdapter.reconcile(beforeSettings, currentSettings, args, ids, lightroomVersion)
    if type(beforeSettings) ~= "table" or type(currentSettings) ~= "table" then
        return nil, "Develop settings readback is unavailable"
    end
    local beforeGlobal, beforeOk = settingsWithoutMaskTree(beforeSettings)
    local currentGlobal, currentOk = settingsWithoutMaskTree(currentSettings)
    if not beforeOk or not currentOk or not deepEqual(beforeGlobal, currentGlobal) then
        return nil, "Global Develop settings changed while creating the mask"
    end

    local beforeState = schemaState(beforeSettings)
    local currentState = schemaState(currentSettings)
    if beforeState == nil or currentState ~= "materialized" then
        return nil, "MaskGroupBasedCorrections readback is unavailable or unrecognized"
    end
    if beforeState == "unmaterialized_empty"
        and not unmaterializedEmptySchemaKnown(beforeSettings, lightroomVersion) then
        return nil, "Unmaterialized empty mask schema is not verified for this Lightroom/process version"
    end
    local beforeTree = beforeState == "unmaterialized_empty"
        and {}
        or beforeSettings.MaskGroupBasedCorrections
    local currentTree = currentSettings.MaskGroupBasedCorrections
    if not treeIsArray(beforeTree) or not treeIsArray(currentTree) then
        return nil, "MaskGroupBasedCorrections readback is not an array"
    end
    local allowCenterWeightFallback = lightroomVersion == "15.5.1"
        and MaskAdapter.processVersion(beforeSettings) == "15.4"
        and MaskAdapter.processVersion(currentSettings) == "15.4"
    local expectedCorrection = MaskAdapter.buildCorrection(args, ids)
    local correctionMatches = {}
    local maskMatchesById = {}
    for correctionIndex, correction in ipairs(currentTree) do
        if type(correction) == "table" then
            if correction.CorrectionSyncID == ids.correction_id then
                table.insert(correctionMatches, { index = correctionIndex, correction = correction })
            end
            if type(correction.CorrectionMasks) == "table" then
                for maskIndex, mask in ipairs(correction.CorrectionMasks) do
                    if type(mask) == "table" and mask.MaskSyncID == ids.mask_id then
                        table.insert(maskMatchesById, {
                            correctionIndex = correctionIndex,
                            maskIndex = maskIndex,
                            correction = correction,
                            mask = mask,
                        })
                    end
                end
            end
        end
    end
    local match
    if #correctionMatches == 1 and #maskMatchesById == 1
        and maskMatchesById[1].correctionIndex == correctionMatches[1].index then
        match = maskMatchesById[1]
    else
        -- Lightroom may replace SDK-supplied SyncIDs when it persists and
        -- reopens the catalog. Reconcile such a rewrite only from the complete,
        -- unique checkpoint delta and exact requested payload; a name match
        -- alone is never ownership evidence.
        local rewrittenCandidates = {}
        for correctionIndex, correction in ipairs(currentTree) do
            local masks = type(correction) == "table" and correction.CorrectionMasks or nil
            local mask = type(masks) == "table" and #masks == 1 and masks[1] or nil
            if type(correction.CorrectionSyncID) == "string"
                and correction.CorrectionSyncID ~= ""
                and type(mask) == "table"
                and type(mask.MaskSyncID) == "string"
                and mask.MaskSyncID ~= ""
                and correction.CorrectionName == args.name
                and maskPayloadMatches(
                    mask,
                    expectedCorrection.CorrectionMasks[1],
                    args,
                    allowCenterWeightFallback
                )
                and correctionPayloadMatches(correction, args) then
                local remainingCandidate = {}
                for index, item in ipairs(currentTree) do
                    if index ~= correctionIndex then table.insert(remainingCandidate, item) end
                end
                if deepEqual(remainingCandidate, beforeTree) then
                    table.insert(rewrittenCandidates, {
                        correctionIndex = correctionIndex,
                        maskIndex = 1,
                        correction = correction,
                        mask = mask,
                    })
                end
            end
        end
        if #rewrittenCandidates == 1 then match = rewrittenCandidates[1] end
    end
    if not match then
        return nil, "Mask operation identity is absent or ambiguous ("
            .. identityDiagnostic(currentTree, ids)
            .. "; " .. rewriteDiagnostic(
                currentTree,
                beforeTree,
                expectedCorrection,
                args,
                allowCenterWeightFallback
            )
            .. ")"
    end
    if match.correction.CorrectionName ~= args.name
        or type(match.correction.CorrectionMasks) ~= "table"
        or #match.correction.CorrectionMasks ~= 1
        or not maskPayloadMatches(
            match.mask,
            expectedCorrection.CorrectionMasks[1],
            args,
            allowCenterWeightFallback
        )
        or not correctionPayloadMatches(match.correction, args) then
        return nil, "Mask readback parameters do not match the requested operation"
    end

    local remaining = {}
    for index, correction in ipairs(currentTree) do
        if index ~= match.correctionIndex then table.insert(remaining, correction) end
    end
    if not deepEqual(remaining, beforeTree) then
        return nil, "Existing mask tree changed while creating the mask"
    end

    local parameters, geometry = readbackParameters(match.mask, allowCenterWeightFallback)
    if not parameters then return nil, "Brush geometry readback is unavailable" end
    if not localSettingsMatch(match.correction, args.local_settings) then
        return nil, "Local mask settings readback is unavailable"
    end
    return {
        mask_id = match.mask.MaskSyncID,
        correction_id = match.correction.CorrectionSyncID,
        name = match.mask.MaskName or correctionMatches[1].correction.CorrectionName,
        mask_kind = "brush",
        kind_parameters = parameters,
        initial_local_settings = readbackLocalSettings(match.correction, args.local_settings),
        geometry = geometry,
        preservation = {
            exactly_one_mask_added = true,
            existing_mask_tree_unchanged = true,
            global_develop_unchanged = true,
            source_untouched = true,
            sidecar_untouched = true,
        },
    }
end

function MaskAdapter.hasOperationIdentity(settings, ids)
    local tree = settings and settings.MaskGroupBasedCorrections
    if not treeIsArray(tree) then return false end
    for _, correction in ipairs(tree) do
        if type(correction) == "table" then
            if correction.CorrectionSyncID == ids.correction_id then return true end
            for _, mask in ipairs(correction.CorrectionMasks or {}) do
                if type(mask) == "table" and mask.MaskSyncID == ids.mask_id then return true end
            end
        end
    end
    return false
end

return MaskAdapter
