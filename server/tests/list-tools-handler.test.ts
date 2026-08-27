import { describe, it, expect } from '@jest/globals';
import fs from 'node:fs';
import path from 'node:path';
import { TOOL_DEFINITIONS, listToolsHandler } from '../src/list-tools-handler.js';
import {
  DEVELOP_CURVE_SETTING_KEYS,
  DEVELOP_SETTING_KEYS,
  OPERATION_SEMANTICS,
  OPERATION_SEMANTICS_META_KEY,
  TOOL_CONTRACTS,
} from '../src/tool-contracts.js';

const EXPECTED_TOOL_NAMES = [
  'search_photos',
  'get_selected_photos',
  'get_photo_metadata',
  'create_virtual_copy',
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
  it('contains exactly 19 tools', () => {
    expect(TOOL_DEFINITIONS).toHaveLength(19);
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
      TOOL_CONTRACTS.map(({ name, description, inputSchema, outputSchema, operationSemantics }) => ({
        name,
        description,
        inputSchema,
        ...(outputSchema ? { outputSchema } : {}),
        _meta: {
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
    expect(Object.keys(properties.settings.properties ?? {})).toEqual(DEVELOP_SETTING_KEYS);
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
