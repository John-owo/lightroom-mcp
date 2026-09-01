import { describe, it, expect } from '@jest/globals';
import { createCallToolHandler } from '../src/tool-handler.js';

import type { PluginResponse } from '../src/dispatcher.js';

function makeHandler(opts: {
  ready?: boolean;
  call?: (action: string, params: unknown) => Promise<PluginResponse>;
} = {}) {
  return createCallToolHandler({
    isReady: () => opts.ready ?? true,
    dispatcher: {
      call: opts.call ?? (async () => ({ id: 'x', result: null })),
    },
  });
}

describe('createCallToolHandler', () => {
  it('returns isError when plugin not connected', async () => {
    const handler = makeHandler({ ready: false });
    const result = await handler('list_collections', {});
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toMatch(/not connected/i);
  });

  it('forwards action and args to dispatcher', async () => {
    let captured: { action: string; params: unknown } | null = null;
    const handler = makeHandler({
      call: async (action, params) => {
        captured = { action, params };
        return { id: '1', result: { ok: true } };
      },
    });
    await handler('search_photos', { rating: 5 });
    expect(captured).toEqual({ action: 'search_photos', params: { rating: 5 } });
  });

  it('serializes successful result as pretty JSON in text content', async () => {
    const handler = makeHandler({
      call: async () => ({ id: '1', result: { count: 3, items: ['a', 'b'] } }),
    });
    const result = await handler('list_collections', {});
    expect(result.isError).toBeUndefined();
    expect(result.content[0].type).toBe('text');
    expect(JSON.parse(result.content[0].text)).toEqual({ count: 3, items: ['a', 'b'] });
  });

  it('returns isError with prefixed message on plugin error response', async () => {
    const handler = makeHandler({
      call: async () => ({ id: '1', error: 'Unknown action' }),
    });
    const result = await handler('bogus', {});
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe('Error: Unknown action');
  });

  it('catches dispatcher rejections and returns isError', async () => {
    const handler = makeHandler({
      call: async () => {
        throw new Error('Plugin response timeout (30s)');
      },
    });
    const result = await handler('x', {});
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe('Plugin response timeout (30s)');
  });

  it('handles non-Error throws by stringifying', async () => {
    const handler = makeHandler({
      call: async () => {
        throw 'raw string';
      },
    });
    const result = await handler('x', {});
    expect(result.isError).toBe(true);
    expect(result.content[0].text).toBe('raw string');
  });

  it('returns bounded REVIEW_REQUIRED evidence for malformed typed output', async () => {
    const handler = makeHandler({
      call: async () => ({
        id: '1',
        result: {
          operation_id: 'mask-op-001',
          result: 'created',
          mask_id: 42,
          oversized: 'x'.repeat(20_000),
        },
      }),
    });

    const result = await handler('create_mask', { operation_id: 'mask-op-001' });
    const evidence: unknown = JSON.parse(result.content[0].text);
    const evidenceRecord = evidence as {
      validation_failure: { raw_response_json: string; raw_response_truncated: boolean };
    };

    expect(result.isError).toBeUndefined();
    expect(result.structuredContent).toEqual(evidence);
    expect(evidence).toMatchObject({
      operation_id: 'mask-op-001',
      result: 'REVIEW_REQUIRED',
      capability: { lightroom_version: 'unverified' },
      selection_restoration: { status: 'not_attempted', verified: false },
      validation_failure: { raw_response_truncated: true },
    });
    expect(evidenceRecord.validation_failure.raw_response_json.length).toBe(16_384);
  });
});
