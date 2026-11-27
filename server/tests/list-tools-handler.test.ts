import { describe, it, expect } from '@jest/globals';
import fs from 'node:fs';
import { AjvJsonSchemaValidator } from '@modelcontextprotocol/sdk/validation/ajv';
import path from 'node:path';
import { TOOL_DEFINITIONS, listToolsHandler } from '../src/list-tools-handler.js';
import {
  DEVELOP_CURVE_SETTING_KEYS,
  DEVELOP_SETTING_KEYS,
  MASK_READBACK_META_KEY,
  OPERATION_SEMANTICS,
  OPERATION_SEMANTICS_META_KEY,
  TOOL_CONTRACTS,
} from '../src/tool-contracts.js';

const EXPECTED_TOOL_NAMES = [
  'search_photos',
  'get_selected_photos',
  'get_photo_metadata',
  'create_virtual_copy',
  'reconcile_virtual_copy',
  'rename_virtual_copy',
  'list_collections',
  'create_collection',
  'add_to_collection',
  'set_keywords',
  'set_rating',
  'import_photos',
  'export_photos',
  'list_develop_presets',
  'get_develop_preset',
  'compare_develop_presets',
  'create_develop_preset',
  'export_develop_preset',
  'apply_develop_preset',
  'copy_develop_settings',
  'set_develop_settings',
] as const;

describe('TOOL_DEFINITIONS', () => {
  it('contains exactly 21 tools', () => {
    expect(TOOL_DEFINITIONS).toHaveLength(21);
  });

  it('tool names are unique', () => {
    const names = TOOL_DEFINITIONS.map((t) => t.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it.each(EXPECTED_TOOL_NAMES)('"%s" is present', (name) => {
    expect(TOOL_DEFINITIONS.some((t) => t.name === name)).toBe(true);
  });

  it('every tool has name, description, and inputSchema', () => {
    for (const tool of TOOL_DEFINITIONS) {
      expect(typeof tool.name).toBe('string');
      expect(typeof tool.description).toBe('string');
      expect(tool.inputSchema).toBeDefined();
      expect(tool.inputSchema.type).toBe('object');
    }
  });

  it('is generated from tool contracts', () => {
    expect(TOOL_DEFINITIONS).toEqual(
      TOOL_CONTRACTS.map(({ name, description, inputSchema, outputSchema, extraMeta, operationSemantics }) => ({
        name,
        description,
        inputSchema,
        ...(outputSchema ? { outputSchema } : {}),
        _meta: {
          ...extraMeta,
          [OPERATION_SEMANTICS_META_KEY]: operationSemantics,
        },
      })),
    );
  });

  it('rejects unknown top-level arguments for every tool', () => {
    for (const tool of TOOL_DEFINITIONS) {
      expect(tool.inputSchema.additionalProperties).toBe(false);
    }
  });
});

describe('listToolsHandler', () => {
  it('returns { tools: TOOL_DEFINITIONS }', () => {
    const result = listToolsHandler();
    expect(result.tools).toEqual(TOOL_DEFINITIONS);
  });
});

describe('tool required fields', () => {
  function toolRequired(name: string): string[] | undefined {
    return TOOL_DEFINITIONS.find((t) => t.name === name)?.inputSchema.required as string[] | undefined;
  }

  it.each<[string, string[]]>([
    ['get_photo_metadata', ['photo_id']],
    ['create_virtual_copy', ['source_photo_id', 'expected_source_uuid', 'operation_id']],
    ['reconcile_virtual_copy', ['source_photo_id', 'expected_source_uuid', 'operation_id']],
    ['rename_virtual_copy', ['photo_id', 'expected_uuid', 'expected_copy_name', 'copy_name']],
    ['create_collection', ['name']],
    ['add_to_collection', ['collection_name', 'photo_ids']],
    ['set_keywords', ['photo_ids']],
    ['set_rating', ['photo_ids', 'rating']],
    ['import_photos', ['source_path']],
    ['export_photos', ['photo_ids', 'destination']],
    ['compare_develop_presets', ['base', 'candidate']],
    ['create_develop_preset', ['photo_id', 'preset_name', 'settings']],
    ['export_develop_preset', ['destination_dir']],
    ['apply_develop_preset', ['photo_ids']],
    ['copy_develop_settings', ['source_id', 'target_ids']],
    ['set_develop_settings', ['photo_id', 'settings']],
  ])('%s requires %j', (name, required) => {
    expect(toolRequired(name)).toEqual(required);
  });

  it.each([
    'search_photos',
    'get_selected_photos',
    'list_collections',
    'list_develop_presets',
    'get_develop_preset',
  ])(
    '%s has no required fields',
    (name) => {
      expect(toolRequired(name)).toBeUndefined();
    },
  );
});

describe('photo identity contract', () => {
  it('requires a stable catalog ID and documents persistent relationships', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'get_photo_metadata');
    const properties = tool?.inputSchema.properties as Record<string, {
      type?: string;
      minLength?: number;
      pattern?: string;
    }>;

    expect(properties.photo_id).toMatchObject({
      type: 'string',
      minLength: 1,
      pattern: '^[0-9]+$',
    });
    expect(tool?.description).toMatch(/UUID/i);
    expect(tool?.description).toMatch(/Virtual Copy/i);
  });

  it('declares a typed structured identity output', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'get_photo_metadata');
    const outputSchema = tool?.outputSchema;
    const properties = outputSchema?.properties as Record<string, {
      type?: string;
      pattern?: string;
      items?: { properties?: Record<string, object>; required?: string[] };
    }>;

    expect(outputSchema?.type).toBe('object');
    expect(outputSchema?.required).toEqual(expect.arrayContaining([
      'catalog_id',
      'uuid',
      'is_virtual_copy',
      'virtual_copy_count',
    ]));
    expect(properties.catalog_id).toMatchObject({ type: 'string', pattern: '^[0-9]+$' });
    expect(properties.uuid).toMatchObject({ type: 'string' });
    expect(properties.virtual_copies).toMatchObject({
      type: 'array',
      items: expect.objectContaining({
        required: expect.arrayContaining(['catalog_id', 'uuid', 'is_virtual_copy']),
      }),
    });
  });
});

describe('virtual copy creation contract', () => {
  it('exposes a strict identity-safe create_virtual_copy tool', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'create_virtual_copy');
    const properties = tool?.inputSchema.properties as Record<string, {
      type?: string;
      pattern?: string;
      minLength?: number;
      maxLength?: number;
    }>;
    const metadata = tool?._meta as Record<string, unknown> | undefined;
    const semantics = metadata?.[OPERATION_SEMANTICS_META_KEY] as Record<string, unknown> | undefined;

    expect(tool).toBeDefined();
    expect(tool?.inputSchema.required).toEqual([
      'source_photo_id',
      'expected_source_uuid',
      'operation_id',
    ]);
    expect(properties.source_photo_id).toMatchObject({
      type: 'string',
      pattern: '^[0-9]+$',
    });
    expect(properties.operation_id).toMatchObject({
      type: 'string',
      minLength: 1,
      maxLength: 64,
      pattern: '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$',
    });
    expect(tool?.outputSchema).toMatchObject({
      type: 'object',
      required: expect.arrayContaining([
        'operation_id',
        'marker',
        'result',
        'selection_restoration',
      ]),
    });
    expect(tool?.outputSchema?.oneOf).toEqual(expect.arrayContaining([
      expect.objectContaining({
        required: expect.arrayContaining(['source', 'master', 'copy', 'is_virtual_copy']),
      }),
      expect.objectContaining({ required: expect.arrayContaining(['partial', 'reason']) }),
    ]));
    expect(semantics).toMatchObject({
      scope: 'selection',
      requires_active_selection: true,
      requires_editor_foreground: true,
      idempotent: false,
      concurrency: 'exclusive_backend',
      retry_policy: 'readback_before_retry',
      safe_to_resume: false,
    });
  });
});

describe('virtual copy reconciliation contract', () => {
  it('exposes a read-only operation-marker query with no selection or editor requirement', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'reconcile_virtual_copy');
    const metadata = tool?._meta as Record<string, unknown> | undefined;
    const semantics = metadata?.[OPERATION_SEMANTICS_META_KEY] as Record<string, unknown> | undefined;

    expect(tool?.inputSchema.required).toEqual([
      'source_photo_id',
      'expected_source_uuid',
      'operation_id',
    ]);
    expect(tool?.description).toMatch(/read.only/i);
    expect(tool?.description).toMatch(/never.*creates/i);
    expect(tool?.outputSchema).toEqual(TOOL_DEFINITIONS.find(
      (entry) => entry.name === 'create_virtual_copy',
    )?.outputSchema);
    expect(semantics).toMatchObject({
      side_effect: 'read_only',
      idempotent: true,
      scope: 'catalog',
      requires_active_selection: false,
      requires_editor_foreground: false,
      concurrency: 'exclusive_backend',
      retry_policy: 'automatic',
      safe_to_resume: true,
    });
  });
});

describe('set_keywords schema', () => {
  it('caps add/remove keyword arrays', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'set_keywords');
    const properties = tool?.inputSchema.properties as Record<string, { maxItems?: number }>;

    expect(properties.add_keywords.maxItems).toBe(1000);
    expect(properties.remove_keywords.maxItems).toBe(1000);
  });
});

describe('photo array schema', () => {
  it.each([
    ['add_to_collection', 'photo_ids'],
    ['set_keywords', 'photo_ids'],
    ['set_rating', 'photo_ids'],
    ['export_photos', 'photo_ids'],
    ['apply_develop_preset', 'photo_ids'],
    ['copy_develop_settings', 'target_ids'],
  ])('%s.%s requires 1-1000 ids', (toolName, propertyName) => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === toolName);
    const properties = tool?.inputSchema.properties as Record<
      string,
      { minItems?: number; maxItems?: number }
    >;

    expect(properties[propertyName].minItems).toBe(1);
    expect(properties[propertyName].maxItems).toBe(1000);
  });
});

describe('develop setting schema', () => {
  function parseLuaDevelopSettingKeys(): string[] {
    const pluginPath = path.resolve(process.cwd(), '..', 'plugin', 'LightroomMCP.lrplugin', 'HandlerDevelop.lua');
    const source = fs.readFileSync(pluginPath, 'utf8');
    const match = source.match(/local ALLOWED_DEVELOP_SETTING_KEYS = \{([\s\S]*?)\n\}/);
    if (!match) {
      throw new Error('ALLOWED_DEVELOP_SETTING_KEYS table not found');
    }

    return [...match[1].matchAll(/^\s*"([^"]+)",/gm)].map((entry) => entry[1]);
  }

  it('restricts copy whitelist to allowlisted SDK keys', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'copy_develop_settings');
    const properties = tool?.inputSchema.properties as Record<
      string,
      { items?: { enum?: readonly string[] }; minItems?: number }
    >;

    expect(properties.settings.minItems).toBe(1);
    expect(properties.settings.items?.enum).toEqual(DEVELOP_SETTING_KEYS);
  });

  it('restricts direct settings object to allowlisted SDK keys', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'set_develop_settings');
    const properties = tool?.inputSchema.properties as Record<
      string,
      { additionalProperties?: boolean; minProperties?: number; properties?: Record<string, unknown> }
    >;

    expect(properties.settings.additionalProperties).toBe(false);
    expect(properties.settings.minProperties).toBe(1);
    expect(Object.keys(properties.settings.properties ?? {})).toEqual([
      ...DEVELOP_SETTING_KEYS,
      "MaskGroupBasedCorrections",
    ]);
  });

  it('uses numeric coordinate arrays for point-curve settings', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'set_develop_settings');
    const properties = tool?.inputSchema.properties as Record<
      string,
      { properties?: Record<string, { type?: string; minItems?: number; maxItems?: number }> }
    >;

    for (const key of DEVELOP_CURVE_SETTING_KEYS) {
      expect(properties.settings.properties?.[key]).toMatchObject({
        type: 'array',
        minItems: 4,
        maxItems: 512,
      });
    }
  });

  it('requires explicit allowlisted keys when creating a preset checkpoint', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'create_develop_preset');
    const properties = tool?.inputSchema.properties as Record<
      string,
      { items?: { enum?: readonly string[] }; minItems?: number; uniqueItems?: boolean }
    >;

    expect(properties.settings.items?.enum).toEqual(DEVELOP_SETTING_KEYS);
    expect(properties.settings.minItems).toBe(1);
    expect(properties.settings.uniqueItems).toBe(true);
  });

  it('matches Lua develop setting allowlist', () => {
    expect(parseLuaDevelopSettingKeys()).toEqual(DEVELOP_SETTING_KEYS);
  });
});

describe('tool contracts vs Lua dispatch', () => {
  function parseLuaDispatch(): Record<string, string> {
    const pluginPath = path.resolve(process.cwd(), '..', 'plugin', 'LightroomMCP.lrplugin', 'PluginInfoProvider.lua');
    const source = fs.readFileSync(pluginPath, 'utf8');
    const match = source.match(/local DISPATCH = \{([\s\S]*?)\n\}/);
    if (!match) {
      throw new Error('DISPATCH table not found');
    }

    return Object.fromEntries(
      [...match[1].matchAll(/^\s*([a-z_]+)\s*=\s*([A-Za-z][A-Za-z0-9_]*\.[A-Za-z][A-Za-z0-9_]*)\s*,/gm)]
        .map((entry) => [entry[1], entry[2]]),
    );
  }

  it('matches manifest names and handler targets', () => {
    const dispatch = parseLuaDispatch();
    const manifest = Object.fromEntries(
      TOOL_CONTRACTS.map((contract) => [contract.name, contract.luaHandler]),
    );

    expect(dispatch).toEqual(manifest);
  });
});

describe('MCP operation semantics', () => {
  const semanticsKey = OPERATION_SEMANTICS_META_KEY;

  it('uses a valid reverse-DNS MCP metadata key with one slash', () => {
    expect(semanticsKey).toMatch(
      /^[a-z0-9-]+(?:\.[a-z0-9-]+)+\/[a-z0-9][a-z0-9._-]*$/,
    );
    expect(semanticsKey.split('/')).toHaveLength(2);
  });

  it('keeps contract and semantics keys in both directions', () => {
    expect(Object.keys(OPERATION_SEMANTICS).sort()).toEqual(
      TOOL_CONTRACTS.map(({ name }) => name).sort(),
    );
  });

  it('exposes the canonical operation semantics contract for every tool', () => {
    for (const tool of TOOL_DEFINITIONS) {
      const metadata = tool._meta as Record<string, unknown> | undefined;
      const semantics = metadata?.[semanticsKey] as Record<string, unknown> | undefined;

      expect(semantics).toMatchObject({
        supported: true,
        side_effect: expect.any(String),
        idempotent: expect.any(Boolean),
        reversible: expect.any(String),
        scope: expect.any(String),
        concurrency: expect.any(String),
        retry_policy: expect.any(String),
        safe_to_resume: expect.any(Boolean),
      });
    }

    const selectedPhotos = TOOL_DEFINITIONS.find((tool) => tool.name === 'get_selected_photos');
    const selectedMetadata = selectedPhotos?._meta as Record<string, unknown> | undefined;
    expect(selectedMetadata?.[semanticsKey]).toMatchObject({
      concurrency: 'exclusive_backend',
      retry_policy: 'readback_before_retry',
      requires_active_selection: false,
    });
  });
});

describe('mask readback and geometric mask writes', () => {
  const validator = new AjvJsonSchemaValidator();

  const radialMask = {
    What: 'Mask/CircularGradient',
    MaskActive: true,
    MaskValue: 1,
    Top: 0.2,
    Left: 0.12,
    Bottom: 0.54,
    Right: 0.48,
    Angle: 0,
    Midpoint: 50,
    Feather: 85,
    Flipped: true,
    Roundness: 0,
    Version: 2,
  };
  const linearMask = {
    What: 'Mask/Gradient',
    MaskActive: true,
    MaskValue: 1,
    ZeroX: 0.5,
    ZeroY: 0.8,
    FullX: 0.5,
    FullY: 1,
    Version: 2,
  };
  const correction = (masks: unknown[]) => ({
    What: 'Correction',
    CorrectionName: 'x',
    CorrectionAmount: 1,
    CorrectionActive: true,
    LocalExposure2012: 0.12,
    CorrectionMasks: masks,
  });

  function validateSetDevelopSettings(masks: unknown) {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'set_develop_settings');
    if (!tool) throw new Error('set_develop_settings missing');
    return validator.getValidator(tool.inputSchema as Parameters<typeof validator.getValidator>[0])({
      photo_id: '1',
      settings: { MaskGroupBasedCorrections: masks },
    });
  }

  it('advertises mask readback on get_photo_metadata _meta only', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'get_photo_metadata');
    const meta = tool?._meta as Record<string, unknown> | undefined;

    expect(meta?.[MASK_READBACK_META_KEY]).toEqual({
      version: 1,
      field: 'developSettings.MaskGroupBasedCorrections',
    });
    expect(MASK_READBACK_META_KEY).toBe('io.github.john-owo.lightroom-mcp/mask-readback');
    expect(meta?.[OPERATION_SEMANTICS_META_KEY]).toBeDefined();

    for (const other of TOOL_DEFINITIONS.filter((t) => t.name !== 'get_photo_metadata')) {
      expect((other._meta as Record<string, unknown>)[MASK_READBACK_META_KEY]).toBeUndefined();
    }
  });

  it('types the mask readback in the get_photo_metadata output schema', () => {
    const tool = TOOL_DEFINITIONS.find((t) => t.name === 'get_photo_metadata');
    if (!tool?.outputSchema) throw new Error('outputSchema missing');
    const validate = validator.getValidator(tool.outputSchema as Parameters<typeof validator.getValidator>[0]);
    const identity = { catalog_id: '7', uuid: 'uuid-7', is_virtual_copy: false, virtual_copy_count: 0 };

    expect(validate({
      ...identity,
      developSettings: { exposure: 0, MaskGroupBasedCorrections: [], maskReadback: 'absent' },
    }).valid).toBe(true);
    expect(validate({
      ...identity,
      developSettings: { MaskGroupBasedCorrections: [correction([radialMask])], maskReadback: 'ok' },
    }).valid).toBe(true);
    expect(validate({
      ...identity,
      developSettings: { maskReadback: 'unsupported_values' },
    }).valid).toBe(true);
    // Lua's ambiguous empty table must never reach clients as an object.
    expect(validate({
      ...identity,
      developSettings: { MaskGroupBasedCorrections: {} },
    }).valid).toBe(false);
  });

  it('accepts radial and linear gradient corrections', () => {
    expect(validateSetDevelopSettings([correction([radialMask]), correction([linearMask])]).valid).toBe(true);
    expect(validateSetDevelopSettings([]).valid).toBe(true);
  });

  it('rejects brush, AI and range masks', () => {
    expect(validateSetDevelopSettings([correction([radialMask, { What: 'Mask/Paint', MaskValue: 1 }])]).valid)
      .toBe(false);
    expect(validateSetDevelopSettings([correction([{ What: 'Mask/Image', MaskSubType: 1 }])]).valid).toBe(false);
    expect(validateSetDevelopSettings([{ ...correction([radialMask]), CorrectionRangeMask: { Type: 1 } }]).valid)
      .toBe(false);
  });

  it('rejects non-correction items, empty mask lists and more than 50 corrections', () => {
    expect(validateSetDevelopSettings([{ ...correction([radialMask]), What: 'Other' }]).valid).toBe(false);
    expect(validateSetDevelopSettings([correction([])]).valid).toBe(false);
    expect(validateSetDevelopSettings(Array.from({ length: 51 }, () => correction([radialMask]))).valid).toBe(false);
  });
});
