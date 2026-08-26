import type { Tool } from "@modelcontextprotocol/sdk/types.js";

type InputSchema = Tool["inputSchema"];

export const OPERATION_SEMANTICS_META_KEY =
  "com.john-owo/lightroom-mcp/operation-semantics";

export type OperationSideEffect =
  | "read_only"
  | "temporary"
  | "mutating"
  | "delivery_export";
export type OperationReversibility =
  | "true_undo"
  | "checkpoint_only"
  | "new_file"
  | "irreversible";
export type OperationScope =
  | "photo"
  | "selection"
  | "catalog"
  | "filesystem"
  | "session";
export type OperationConcurrency =
  | "parallel_safe"
  | "per_photo_serialized"
  | "exclusive_backend";
export type OperationRetryPolicy =
  | "automatic"
  | "readback_before_retry"
  | "manual_review_only";
/**
 * Stable safety metadata for one Lightroom operation.
 *
 * These fields are intentionally snake_case: they are part of the public MCP
 * extension payload and mirror the operation-semantics vocabulary used by the
 * workflow/orchestrator contract. They are hints for callers, not a substitute
 * for backend readback or the plugin's serialized dispatch queue.
 */
export interface OperationSemantics {
  supported: boolean;
  side_effect: OperationSideEffect;
  idempotent: boolean;
  reversible: OperationReversibility;
  scope: OperationScope;
  requires_active_selection: boolean;
  requires_editor_foreground: boolean;
  concurrency: OperationConcurrency;
  retry_policy: OperationRetryPolicy;
  safe_to_resume: boolean;
}

export interface ToolContract {
  name: string;
  description: string;
  luaHandler: string;
  inputSchema: InputSchema;
  outputSchema?: Tool["outputSchema"];
  operationSemantics: OperationSemantics;
}

interface ToolContractDefinition {
  name: string;
  description: string;
  luaHandler: string;
  inputSchema: InputSchema;
  outputSchema?: Tool["outputSchema"];
}

const MAX_BULK_PHOTO_IDS = 1000;
const MAX_KEYWORDS = 1000;

export const DEVELOP_SETTING_KEYS = [
  "WhiteBalance",
  "Temperature",
  "Tint",
  "Exposure2012",
  "Contrast2012",
  "Highlights2012",
  "Shadows2012",
  "Whites2012",
  "Blacks2012",
  "Texture",
  "Clarity2012",
  "Dehaze",
  "Vibrance",
  "Saturation",
  "SaturationAdjustmentRed",
  "SaturationAdjustmentOrange",
  "SaturationAdjustmentYellow",
  "SaturationAdjustmentGreen",
  "SaturationAdjustmentAqua",
  "SaturationAdjustmentBlue",
  "SaturationAdjustmentPurple",
  "SaturationAdjustmentMagenta",
  "HueAdjustmentRed",
  "HueAdjustmentOrange",
  "HueAdjustmentYellow",
  "HueAdjustmentGreen",
  "HueAdjustmentAqua",
  "HueAdjustmentBlue",
  "HueAdjustmentPurple",
  "HueAdjustmentMagenta",
  "LuminanceAdjustmentRed",
  "LuminanceAdjustmentOrange",
  "LuminanceAdjustmentYellow",
  "LuminanceAdjustmentGreen",
  "LuminanceAdjustmentAqua",
  "LuminanceAdjustmentBlue",
  "LuminanceAdjustmentPurple",
  "LuminanceAdjustmentMagenta",
  "ParametricShadows",
  "ParametricDarks",
  "ParametricLights",
  "ParametricHighlights",
  "ParametricShadowSplit",
  "ParametricMidtoneSplit",
  "ParametricHighlightSplit",
  "ToneCurveName2012",
  "ToneCurvePV2012",
  "ToneCurvePV2012Red",
  "ToneCurvePV2012Green",
  "ToneCurvePV2012Blue",
  "ConvertToGrayscale",
  "Sharpness",
  "SharpenRadius",
  "SharpenDetail",
  "SharpenEdgeMasking",
  "LuminanceSmoothing",
  "LuminanceNoiseReductionDetail",
  "LuminanceNoiseReductionContrast",
  "ColorNoiseReduction",
  "ColorNoiseReductionDetail",
  "ColorNoiseReductionSmoothness",
  "LensProfileEnable",
  "LensManualDistortionAmount",
  "PerspectiveVertical",
  "PerspectiveHorizontal",
  "PerspectiveRotate",
  "PerspectiveScale",
  "PerspectiveAspect",
  "PerspectiveUpright",
  "PostCropVignetteAmount",
  "PostCropVignetteMidpoint",
  "PostCropVignetteRoundness",
  "PostCropVignetteFeather",
  "PostCropVignetteStyle",
  "GrainAmount",
  "GrainSize",
  "GrainFrequency",
  "CropTop",
  "CropLeft",
  "CropBottom",
  "CropRight",
  "CropAngle",
] as const;

export const DEVELOP_CURVE_SETTING_KEYS = [
  "ToneCurvePV2012",
  "ToneCurvePV2012Red",
  "ToneCurvePV2012Green",
  "ToneCurvePV2012Blue",
] as const;

const developCurveSettingKeySet = new Set<string>(DEVELOP_CURVE_SETTING_KEYS);

const stringArray = (description: string, maxItems?: number) => ({
  type: "array",
  items: { type: "string" },
  minItems: 1,
  ...(maxItems ? { maxItems } : {}),
  description,
});

const catalogPhotoId = {
  type: "string",
  minLength: 1,
  pattern: "^[0-9]+$",
  description: "Stable Lightroom catalog photo ID (localIdentifier); paths are not accepted",
};

const photoIdArray = (description: string) => ({
  ...stringArray(description, MAX_BULK_PHOTO_IDS),
  items: catalogPhotoId,
});

const photoIdentityReferenceOutputSchema = {
  type: "object",
  properties: {
    catalog_id: catalogPhotoId,
    uuid: { type: "string", minLength: 1 },
    path: { type: "string" },
    filename: { type: "string" },
    copy_name: { type: "string" },
    is_virtual_copy: { type: "boolean" },
  },
  required: ["catalog_id", "uuid", "is_virtual_copy"],
};

/**
 * Identity fields returned by get_photo_metadata. Other metadata fields stay
 * additive, while these fields are validated by MCP structuredContent.
 */
export const PHOTO_METADATA_OUTPUT_SCHEMA: NonNullable<Tool["outputSchema"]> = {
  type: "object",
  properties: {
    catalog_id: catalogPhotoId,
    uuid: { type: "string", minLength: 1 },
    copy_name: { type: "string" },
    is_virtual_copy: { type: "boolean" },
    master: photoIdentityReferenceOutputSchema,
    master_id: catalogPhotoId,
    master_uuid: { type: "string", minLength: 1 },
    virtual_copies: {
      type: "array",
      items: photoIdentityReferenceOutputSchema,
    },
    virtual_copy_count: { type: "integer", minimum: 0 },
  },
  required: ["catalog_id", "uuid", "is_virtual_copy", "virtual_copy_count"],
};

const dateStringSchema = (description: string) => ({
  type: "string",
  pattern: "^\\d{4}-\\d{2}-\\d{2}$",
  description,
});

const developSettingValueSchema = {
  oneOf: [{ type: "number" }, { type: "string" }, { type: "boolean" }],
};

const developCurveValueSchema = {
  type: "array",
  items: { type: "number" },
  minItems: 4,
  maxItems: 512,
  description: "Flat x,y coordinate pairs (2-256 points)",
};

const developSettingsProperties = Object.fromEntries(
  DEVELOP_SETTING_KEYS.map((key) => [
    key,
    developCurveSettingKeySet.has(key) ? developCurveValueSchema : developSettingValueSchema,
  ]),
);

const presetSelectorProperties = {
  preset_name: { type: "string", minLength: 1, description: "Develop preset name" },
  preset_uuid: { type: "string", minLength: 1, description: "Develop preset UUID (preferred)" },
  preset_folder: { type: "string", minLength: 1, description: "Preset folder for disambiguation" },
  preset_scope: {
    type: "string",
    enum: ["lightroom", "plugin"],
    description: "Lightroom-visible preset or plugin-managed checkpoint",
  },
};

const presetSelectorSchema: InputSchema = {
  type: "object",
  additionalProperties: false,
  properties: presetSelectorProperties,
  anyOf: [{ required: ["preset_uuid"] }, { required: ["preset_name"] }],
};

const TOOL_CONTRACT_DEFINITIONS: ToolContractDefinition[] = [
  {
    name: "search_photos",
    luaHandler: "HandlerSearch.searchPhotos",
    description:
      "Search for photos in Lightroom catalog by criteria (paginated, default limit 100). Providing at least one filter (filename, keywords, rating, or date) significantly improves performance on large catalogs.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        filename: { type: "string", description: "Search by filename (partial match)" },
        keywords: stringArray("Search by keywords"),
        rating: {
          type: "number",
          description: "Filter by star rating (0-5)",
          minimum: 0,
          maximum: 5,
        },
        start_date: dateStringSchema("Start date (YYYY-MM-DD)"),
        end_date: dateStringSchema("End date (YYYY-MM-DD)"),
        limit: { type: "number", description: "Max photos to return (default 100)", minimum: 0 },
        offset: { type: "number", description: "Number of photos to skip (default 0)", minimum: 0 },
      },
    },
  },
  {
    name: "get_selected_photos",
    luaHandler: "HandlerSelection.getSelectedPhotos",
    description: "Get currently selected photos in Lightroom (or filmstrip if no selection). Paginated, default limit 100.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        limit: { type: "number", description: "Max photos to return (default 100)", minimum: 0 },
        offset: { type: "number", description: "Number of photos to skip (default 0)", minimum: 0 },
      },
    },
  },
  {
    name: "get_photo_metadata",
    luaHandler: "HandlerMetadata.getPhotoMetadata",
    description:
      "Get detailed metadata and persistent identity for a Lightroom catalog photo: stable catalog ID, UUID, Master relationship, Virtual Copy status and siblings, EXIF, title/caption/headline, GPS (latitude/longitude/altitude), IPTC location (sublocation/city/stateProvince/country/isoCountryCode), copyright, and develop settings. Use the catalog ID for identity; source paths are display-only and are not accepted as selectors.",
    outputSchema: PHOTO_METADATA_OUTPUT_SCHEMA,
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_id: catalogPhotoId,
      },
      required: ["photo_id"],
    },
  },
  {
    name: "list_collections",
    luaHandler: "HandlerCollections.listCollections",
    description: "List all collections in Lightroom catalog (paginated, default limit 100)",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        limit: { type: "number", description: "Max collections to return (default 100)", minimum: 0 },
        offset: { type: "number", description: "Number of collections to skip (default 0)", minimum: 0 },
      },
    },
  },
  {
    name: "create_collection",
    luaHandler: "HandlerCollections.createCollection",
    description: "Create a new collection",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        name: { type: "string", description: "Collection name" },
        parent: { type: "string", description: "Parent collection set (optional)" },
      },
      required: ["name"],
    },
  },
  {
    name: "add_to_collection",
    luaHandler: "HandlerCollections.addToCollection",
    description: "Add photos to a collection",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        collection_name: { type: "string", description: "Collection name" },
        photo_ids: photoIdArray("Array of stable Lightroom catalog photo IDs; paths are not accepted"),
      },
      required: ["collection_name", "photo_ids"],
    },
  },
  {
    name: "set_keywords",
    luaHandler: "HandlerOrganization.setKeywords",
    description: "Add or remove keywords from photos",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_ids: photoIdArray("Array of stable Lightroom catalog photo IDs; paths are not accepted"),
        add_keywords: stringArray("Keywords to add", MAX_KEYWORDS),
        remove_keywords: stringArray("Keywords to remove", MAX_KEYWORDS),
      },
      required: ["photo_ids"],
    },
  },
  {
    name: "set_rating",
    luaHandler: "HandlerOrganization.setRating",
    description: "Set star rating for photos",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_ids: photoIdArray("Array of stable Lightroom catalog photo IDs; paths are not accepted"),
        rating: {
          type: "number",
          description: "Star rating (0-5)",
          minimum: 0,
          maximum: 5,
        },
      },
      required: ["photo_ids", "rating"],
    },
  },
  {
    name: "import_photos",
    luaHandler: "HandlerImport.importPhotos",
    description: "Import photos into Lightroom catalog",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        source_path: { type: "string", description: "Path to photo or folder to import" },
        collection_name: {
          type: "string",
          description: "Collection to add imported photos to (optional)",
        },
        copy_to: {
          type: "string",
          description: "Destination folder for copying files (optional)",
        },
      },
      required: ["source_path"],
    },
  },
  {
    name: "export_photos",
    luaHandler: "HandlerExport.exportPhotos",
    description: "Export photos from Lightroom",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_ids: photoIdArray("Array of stable Lightroom catalog photo IDs to export; paths are not accepted"),
        destination: { type: "string", description: "Export destination folder" },
        format: {
          type: "string",
          description: "Export format (jpeg, png, tiff, original)",
          enum: ["jpeg", "png", "tiff", "original"],
        },
        quality: {
          type: "number",
          description: "JPEG quality (0-100)",
          minimum: 0,
          maximum: 100,
        },
        width: { type: "number", description: "Max width in pixels (optional)" },
        height: { type: "number", description: "Max height in pixels (optional)" },
      },
      required: ["photo_ids", "destination"],
    },
  },
  {
    name: "list_develop_presets",
    luaHandler: "HandlerDevelop.listDevelopPresets",
    description: "List Lightroom-visible Develop presets and plugin-managed preset checkpoints",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {},
    },
  },
  {
    name: "get_develop_preset",
    luaHandler: "HandlerDevelop.getDevelopPreset",
    description:
      "Read the settings and backing-file metadata for one exact Develop preset. Use preset_uuid or provide folder/scope when names are duplicated.",
    inputSchema: presetSelectorSchema,
  },
  {
    name: "compare_develop_presets",
    luaHandler: "HandlerDevelop.compareDevelopPresets",
    description:
      "Compare two Develop presets and return a deterministic per-setting diff for iterative style matching",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        base: { ...presetSelectorSchema, description: "Approved historical/base preset" },
        candidate: { ...presetSelectorSchema, description: "Candidate preset checkpoint" },
      },
      required: ["base", "candidate"],
    },
  },
  {
    name: "create_develop_preset",
    luaHandler: "HandlerDevelop.createDevelopPreset",
    description:
      "Create a versioned plugin-managed Develop preset checkpoint from selected settings on one photo. The checkpoint is hidden from the Develop panel; export it for handoff.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_id: { ...catalogPhotoId, description: "Stable Lightroom catalog photo ID; paths are not accepted" },
        preset_name: {
          type: "string",
          minLength: 1,
          description: "Unique versioned checkpoint name; existing plugin names are refused",
        },
        settings: {
          type: "array",
          items: { type: "string", enum: DEVELOP_SETTING_KEYS },
          minItems: 1,
          maxItems: DEVELOP_SETTING_KEYS.length,
          uniqueItems: true,
          description: "Explicit Lightroom SDK setting keys to capture from the source photo",
        },
      },
      required: ["photo_id", "preset_name", "settings"],
    },
  },
  {
    name: "export_develop_preset",
    luaHandler: "HandlerDevelop.exportDevelopPreset",
    description:
      "Copy one exact custom or plugin-managed Develop preset backing file to a destination directory. Existing files are never overwritten; built-in presets without backing files cannot be exported.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        ...presetSelectorProperties,
        destination_dir: {
          type: "string",
          minLength: 1,
          description: "Destination directory; created when missing",
        },
        filename: {
          type: "string",
          minLength: 1,
          description: "Optional leaf filename. Extension must match the Lightroom backing file.",
        },
      },
      required: ["destination_dir"],
      anyOf: [{ required: ["preset_uuid"] }, { required: ["preset_name"] }],
    },
  },
  {
    name: "apply_develop_preset",
    luaHandler: "HandlerDevelop.applyDevelopPreset",
    description: "Apply one exact Develop preset to one or more photos",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_ids: photoIdArray("Array of stable Lightroom catalog photo IDs; paths are not accepted"),
        preset_name: {
          type: "string",
          description: "Preset name",
        },
        preset_uuid: { type: "string", description: "Preset UUID (preferred)" },
        preset_folder: { type: "string", description: "Preset folder for disambiguation" },
        preset_scope: { type: "string", enum: ["lightroom", "plugin"] },
      },
      required: ["photo_ids"],
      anyOf: [{ required: ["preset_uuid"] }, { required: ["preset_name"] }],
    },
  },
  {
    name: "copy_develop_settings",
    luaHandler: "HandlerDevelop.copyDevelopSettings",
    description: "Copy Develop settings from one photo to others",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        source_id: {
          ...catalogPhotoId,
          description: "Stable Lightroom catalog photo ID; paths are not accepted",
        },
        target_ids: photoIdArray("Target stable Lightroom catalog photo IDs; paths are not accepted"),
        settings: {
          type: "array",
          items: {
            type: "string",
            enum: DEVELOP_SETTING_KEYS,
          },
          minItems: 1,
          maxItems: DEVELOP_SETTING_KEYS.length,
          description:
            "Optional whitelist of SDK setting keys (e.g., Exposure2012, Contrast2012, HueAdjustmentOrange). Omit to copy all.",
        },
      },
      required: ["source_id", "target_ids"],
    },
  },
  {
    name: "set_develop_settings",
    luaHandler: "HandlerDevelop.setDevelopSettings",
    description:
      "Set Develop settings directly on a photo. Keys use allowlisted Lightroom SDK names (Exposure2012, WhiteBalance, Contrast2012, Highlights2012, Shadows2012, Whites2012, Blacks2012, Clarity2012, Vibrance, Saturation, HueAdjustmentRed, SaturationAdjustmentOrange, LuminanceAdjustmentYellow, etc.)",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        photo_id: {
          ...catalogPhotoId,
          description: "Stable Lightroom catalog photo ID; paths are not accepted",
        },
        settings: {
          type: "object",
          properties: developSettingsProperties,
          additionalProperties: false,
          minProperties: 1,
          description:
            "Allowlisted SDK setting key/value pairs (e.g., {\"Exposure2012\": 0.5, \"SaturationAdjustmentOrange\": -10})",
        },
      },
      required: ["photo_id", "settings"],
    },
  },
];

const readOnlySemantics = (
  scope: OperationScope,
  overrides: Partial<OperationSemantics> = {},
): OperationSemantics => ({
  supported: true,
  side_effect: "read_only",
  idempotent: true,
  reversible: "true_undo",
  scope,
  requires_active_selection: false,
  requires_editor_foreground: false,
  concurrency: "parallel_safe",
  retry_policy: "automatic",
  safe_to_resume: true,
  ...overrides,
});

const mutatingSemantics = (
  scope: OperationScope,
  overrides: Partial<OperationSemantics> = {},
): OperationSemantics => ({
  supported: true,
  side_effect: "mutating",
  idempotent: false,
  reversible: "irreversible",
  scope,
  requires_active_selection: false,
  requires_editor_foreground: false,
  concurrency: "exclusive_backend",
  retry_policy: "manual_review_only",
  safe_to_resume: false,
  ...overrides,
});

const deliverySemantics = (
  scope: OperationScope,
  overrides: Partial<OperationSemantics> = {},
): OperationSemantics => ({
  supported: true,
  side_effect: "delivery_export",
  idempotent: false,
  reversible: "new_file",
  scope,
  requires_active_selection: false,
  requires_editor_foreground: false,
  concurrency: "exclusive_backend",
  retry_policy: "readback_before_retry",
  safe_to_resume: false,
  ...overrides,
});

/**
 * Operation semantics are keyed separately from the input schemas so adding a
 * safety constraint cannot accidentally loosen argument validation. The
 * public `TOOL_CONTRACTS` export below joins the two contract layers and fails
 * fast if a newly-added tool forgets to declare its execution semantics.
 */
export const OPERATION_SEMANTICS: Readonly<Record<string, OperationSemantics>> = {
  search_photos: readOnlySemantics("catalog"),
  get_selected_photos: readOnlySemantics("selection", {
    requires_active_selection: true,
    concurrency: "exclusive_backend",
    retry_policy: "readback_before_retry",
    safe_to_resume: true,
  }),
  get_photo_metadata: readOnlySemantics("photo"),
  list_collections: readOnlySemantics("catalog"),
  create_collection: mutatingSemantics("catalog"),
  add_to_collection: mutatingSemantics("catalog", {
    idempotent: true,
    retry_policy: "readback_before_retry",
    safe_to_resume: false,
  }),
  set_keywords: mutatingSemantics("photo", {
    retry_policy: "readback_before_retry",
    safe_to_resume: false,
  }),
  set_rating: mutatingSemantics("photo", {
    idempotent: true,
    retry_policy: "readback_before_retry",
    safe_to_resume: false,
  }),
  import_photos: mutatingSemantics("catalog"),
  export_photos: deliverySemantics("filesystem"),
  list_develop_presets: readOnlySemantics("catalog"),
  get_develop_preset: readOnlySemantics("catalog"),
  compare_develop_presets: readOnlySemantics("catalog"),
  create_develop_preset: mutatingSemantics("filesystem"),
  export_develop_preset: deliverySemantics("filesystem", {
    concurrency: "parallel_safe",
  }),
  apply_develop_preset: mutatingSemantics("photo", {
    idempotent: true,
    retry_policy: "readback_before_retry",
    safe_to_resume: false,
  }),
  copy_develop_settings: mutatingSemantics("photo", {
    retry_policy: "readback_before_retry",
    safe_to_resume: false,
  }),
  set_develop_settings: mutatingSemantics("photo", {
    idempotent: true,
    retry_policy: "readback_before_retry",
    safe_to_resume: false,
  }),
};

export const TOOL_CONTRACTS: ToolContract[] = TOOL_CONTRACT_DEFINITIONS.map(
  (contract) => {
    const operationSemantics = OPERATION_SEMANTICS[contract.name];
    if (!operationSemantics) {
      throw new Error(`Missing operation semantics for tool: ${contract.name}`);
    }
    return { ...contract, operationSemantics };
  },
);
