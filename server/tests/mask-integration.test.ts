import { afterEach, describe, expect, it } from "@jest/globals";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { InMemoryTransport } from "@modelcontextprotocol/sdk/inMemory.js";
import { createMcpServer } from "../src/create-server.js";
import { Dispatcher } from "../src/dispatcher.js";
import { PluginSocket } from "../src/plugin-socket.js";
import { FakePlugin, freePort } from "./helpers/fake-plugin.js";

interface ToolResult {
  content: Array<{ type: string; text: string }>;
  structuredContent?: Record<string, unknown>;
  isError?: boolean;
}

interface Harness {
  client: Client;
  server: ReturnType<typeof createMcpServer>;
  plugin: FakePlugin;
  request: PluginSocket;
  response: PluginSocket;
  setMalformed: (value: boolean) => void;
}

const TOKEN = "mask-integration-token";
const OPERATION_ID = "mask-op-transport-001";

async function waitFor(check: () => boolean, timeoutMs: number, label: string): Promise<void> {
  const start = Date.now();
  while (!check()) {
    if (Date.now() - start > timeoutMs) {
      throw new Error(`waitFor(${label}) timed out after ${timeoutMs}ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}

async function expectMalformedEvidence(resultPromise: Promise<unknown>): Promise<void> {
  const result = (await resultPromise) as ToolResult;
  expect(result.isError).toBeFalsy();
  expect(result.structuredContent).toMatchObject({
    operation_id: OPERATION_ID,
    result: "REVIEW_REQUIRED",
    validation_failure: { raw_response_truncated: false },
  });
  expect(JSON.parse(result.content[0].text)).toEqual(result.structuredContent);
}

function identity(catalogId: string, uuid: string, isVirtualCopy: boolean) {
  return {
    catalog_id: catalogId,
    uuid,
    path: "/相片/夕陽.jpg",
    filename: "夕陽.jpg",
    copy_name: isVirtualCopy ? "Workflow Copy" : "原始版本",
    is_virtual_copy: isVirtualCopy,
  };
}

function successResult() {
  return {
    operation_id: OPERATION_ID,
    result: "created",
    capability: {
      lightroom_version: "13.0",
      process_version: "11.0",
      mask_schema: "MaskGroupBasedCorrections.v1",
      kinds: {
        brush: {
          supported: true,
          accepted_parameters: [
            "coordinate_system", "coordinate_units", "path", "size",
            "feather", "flow", "density",
          ],
          readback_guarantees: ["MaskSyncID", "CorrectionSyncID", "Mask/Paint Dabs"],
        },
        subject: {
          supported: false,
          accepted_parameters: [],
          readback_guarantees: [],
          reason: "AI adapter unavailable",
        },
        sky: {
          supported: false,
          accepted_parameters: [],
          readback_guarantees: [],
          reason: "AI adapter unavailable",
        },
      },
    },
    selection_restoration: { status: "restored", verified: true },
    photo: identity("101", "uuid-copy", true),
    master: identity("100", "uuid-master", false),
    mask_id: "mask-id-001",
    correction_id: "correction-id-001",
    name: "Face lift",
    mask_kind: "brush",
    kind_parameters: {
      coordinate_system: "normalized_image",
      coordinate_units: "unit_interval",
      path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
      size: 0.12,
      feather: 0.35,
      flow: 0.7,
      density: 0.8,
    },
    initial_local_settings: { exposure: 0.5, clarity: 12 },
    lightroom_version: "13.0",
    process_version: "11.0",
    mask_schema: "MaskGroupBasedCorrections.v1",
    geometry: {
      coordinate_system: "normalized_image",
      coordinate_units: "unit_interval",
      point_count: 2,
      bounds: { x_min: 0.2, x_max: 0.4, y_min: 0.3, y_max: 0.5 },
    },
    checkpoint: {
      name: `Lightroom MCP Mask Checkpoint [${OPERATION_ID}]`,
      uuid: "checkpoint-001",
      scope: "plugin",
      recovery_evidence: true,
      true_undo: false,
    },
    preservation: {
      exactly_one_mask_added: true,
      existing_mask_tree_unchanged: true,
      global_develop_unchanged: true,
      source_untouched: true,
      sidecar_untouched: true,
    },
  };
}

function subjectSuccessResult() {
  return {
    ...successResult(),
    mask_id: "subject-mask-id-001",
    correction_id: "subject-correction-id-001",
    name: "Squirrel Subject",
    mask_kind: "subject",
    kind_parameters: {},
    initial_local_settings: { exposure: 0.65 },
    geometry: {
      coordinate_system: "lightroom_ai",
      coordinate_units: "opaque",
      ai_payload_present: true,
      ai_payload_field_count: 10,
      ai_mask_type: "Mask/Image",
      ai_mask_subtype: 1,
      ai_error_state: "zero",
      error_reason: 0,
    },
    capability: {
      ...successResult().capability,
      kinds: {
        ...successResult().capability.kinds,
        subject: {
          supported: true,
          accepted_parameters: [],
          readback_guarantees: [
            "Mask/Image",
            "MaskSubType=1",
            "ErrorReason absent-or-zero",
            "opaque AI payload",
          ],
        },
      },
    },
  };
}

async function startHarness(options?: {
  expectedArgs?: Record<string, unknown>;
  resultFactory?: () => Record<string, unknown>;
}): Promise<Harness> {
  const expectedArgs = options?.expectedArgs ?? {
    photo_id: "101",
    expected_photo_uuid: "uuid-copy",
    expected_master_uuid: "uuid-master",
    operation_id: OPERATION_ID,
    mask_kind: "brush",
    name: "Face lift",
    kind_parameters: {
      coordinate_system: "normalized_image",
      coordinate_units: "unit_interval",
      path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
      size: 0.12,
      feather: 0.35,
      flow: 0.7,
      density: 0.8,
    },
    local_settings: { exposure: 0.5, clarity: 12 },
  };
  let malformed = false;
  const [requestPort, responsePort] = await Promise.all([freePort(), freePort()]);
  const plugin = new FakePlugin({
    requestPort,
    responsePort,
    token: TOKEN,
    handler: (action, params) => {
      expect(action).toBe("create_mask");
      expect(params).toEqual(expectedArgs);
      const result = options?.resultFactory?.() ?? successResult();
      return malformed ? { ...result, mask_id: 42 } : result;
    },
  });
  await plugin.start();

  let dispatcher: Dispatcher;
  const request = new PluginSocket({
    port: requestPort,
    label: "mask-request",
    reconnectDelayMs: 25,
    log: () => {},
  });
  const response = new PluginSocket({
    port: responsePort,
    label: "mask-response",
    reconnectDelayMs: 25,
    log: () => {},
    onLine: (line) => dispatcher.handleResponseLine(line),
  });
  dispatcher = new Dispatcher({
    send: (line) => request.send(line),
    getToken: () => TOKEN,
    timeoutMs: 5_000,
    log: () => {},
  });
  request.connect();
  response.connect();
  await waitFor(
    () => request.isConnected() && response.isConnected(),
    3_000,
    "mask sockets connected",
  );

  const server = createMcpServer({
    dispatcher,
    isReady: () => request.isConnected() && response.isConnected(),
  });
  const client = new Client({ name: "mask-integration-client", version: "1.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  return {
    client,
    server,
    plugin,
    request,
    response,
    setMalformed: (value) => { malformed = value; },
  };
}

describe("create_mask across MCP and plugin transports", () => {
  let harness: Harness | null = null;

  afterEach(async () => {
    if (!harness) return;
    await harness.client.close();
    await harness.server.close();
    harness.request.stop();
    harness.response.stop();
    await harness.plugin.stop();
    harness = null;
  });

  it("round-trips a typed Brush result and rejects output type drift", async () => {
    harness = await startHarness();
    const listed = await harness.client.listTools();
    const tool = listed.tools.find((entry) => entry.name === "create_mask");
    expect(tool?.inputSchema.additionalProperties).toBe(false);
    expect(tool?.inputSchema.required).toEqual([
      "photo_id",
      "expected_photo_uuid",
      "expected_master_uuid",
      "operation_id",
      "mask_kind",
      "name",
      "kind_parameters",
      "local_settings",
    ]);
    expect(tool?.outputSchema?.required).toEqual(["operation_id", "result"]);

    const result = (await harness.client.callTool({
      name: "create_mask",
      arguments: {
        photo_id: "101",
        expected_photo_uuid: "uuid-copy",
        expected_master_uuid: "uuid-master",
        operation_id: OPERATION_ID,
        mask_kind: "brush",
        name: "Face lift",
        kind_parameters: {
          coordinate_system: "normalized_image",
          coordinate_units: "unit_interval",
          path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
          size: 0.12,
          feather: 0.35,
          flow: 0.7,
          density: 0.8,
        },
        local_settings: { exposure: 0.5, clarity: 12 },
      },
    })) as ToolResult;

    expect(result.isError).toBeFalsy();
    expect(result.structuredContent).toMatchObject({
      operation_id: OPERATION_ID,
      result: "created",
      mask_kind: "brush",
      mask_id: "mask-id-001",
      preservation: {
        exactly_one_mask_added: true,
        existing_mask_tree_unchanged: true,
        global_develop_unchanged: true,
      },
    });
    expect(JSON.parse(result.content[0].text)).toEqual(result.structuredContent);

    harness.setMalformed(true);
    const malformed = (await harness.client.callTool({
      name: "create_mask",
      arguments: {
        photo_id: "101",
        expected_photo_uuid: "uuid-copy",
        expected_master_uuid: "uuid-master",
        operation_id: OPERATION_ID,
        mask_kind: "brush",
        name: "Face lift",
        kind_parameters: {
          coordinate_system: "normalized_image",
          coordinate_units: "unit_interval",
          path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
          size: 0.12,
          feather: 0.35,
          flow: 0.7,
          density: 0.8,
        },
        local_settings: { exposure: 0.5, clarity: 12 },
      },
    })) as ToolResult;
    expect(malformed.isError).toBeFalsy();
    expect(malformed.structuredContent).toMatchObject({
      operation_id: OPERATION_ID,
      result: "REVIEW_REQUIRED",
      validation_failure: { raw_response_truncated: false },
    });
    expect(JSON.parse(malformed.content[0].text)).toEqual(malformed.structuredContent);
    const validationFailure = malformed.structuredContent?.validation_failure as {
      raw_response_json: string;
    };
    expect(JSON.parse(validationFailure.raw_response_json)).toMatchObject({
      operation_id: OPERATION_ID,
      result: "created",
      mask_id: 42,
    });
  }, 20_000);

  it("round-trips a typed Lightroom-generated Subject result", async () => {
    const subjectArgs = {
      photo_id: "101",
      expected_photo_uuid: "uuid-copy",
      expected_master_uuid: "uuid-master",
      operation_id: OPERATION_ID,
      mask_kind: "subject",
      name: "Squirrel Subject",
      kind_parameters: {},
      local_settings: { exposure: 0.65 },
    };
    harness = await startHarness({
      expectedArgs: subjectArgs,
      resultFactory: subjectSuccessResult,
    });

    const result = (await harness.client.callTool({
      name: "create_mask",
      arguments: subjectArgs,
    })) as ToolResult;

    expect(result.isError).toBeFalsy();
    expect(result.structuredContent).toMatchObject({
      result: "created",
      mask_kind: "subject",
      name: "Squirrel Subject",
      kind_parameters: {},
      initial_local_settings: { exposure: 0.65 },
      geometry: {
        coordinate_system: "lightroom_ai",
        coordinate_units: "opaque",
        ai_payload_present: true,
        ai_mask_type: "Mask/Image",
        ai_mask_subtype: 1,
        ai_error_state: "zero",
        error_reason: 0,
      },
      preservation: {
        exactly_one_mask_added: true,
        existing_mask_tree_unchanged: true,
        global_develop_unchanged: true,
      },
    });
    expect(JSON.parse(result.content[0].text)).toEqual(result.structuredContent);
  }, 20_000);

  it("rejects a successful Brush result paired with Subject geometry", async () => {
    harness = await startHarness({
      resultFactory: () => ({
        ...successResult(),
        geometry: subjectSuccessResult().geometry,
      }),
    });
    await harness.client.listTools();

    await expectMalformedEvidence(harness.client.callTool({
      name: "create_mask",
      arguments: {
        photo_id: "101",
        expected_photo_uuid: "uuid-copy",
        expected_master_uuid: "uuid-master",
        operation_id: OPERATION_ID,
        mask_kind: "brush",
        name: "Face lift",
        kind_parameters: {
          coordinate_system: "normalized_image",
          coordinate_units: "unit_interval",
          path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
          size: 0.12,
          feather: 0.35,
          flow: 0.7,
          density: 0.8,
        },
        local_settings: { exposure: 0.5, clarity: 12 },
      },
    }));
  }, 20_000);

  it("rejects a successful Subject result paired with Brush geometry", async () => {
    const subjectArgs = {
      photo_id: "101",
      expected_photo_uuid: "uuid-copy",
      expected_master_uuid: "uuid-master",
      operation_id: OPERATION_ID,
      mask_kind: "subject",
      name: "Squirrel Subject",
      kind_parameters: {},
      local_settings: { exposure: 0.65 },
    };
    harness = await startHarness({
      expectedArgs: subjectArgs,
      resultFactory: () => ({
        ...subjectSuccessResult(),
        geometry: successResult().geometry,
      }),
    });
    await harness.client.listTools();

    await expectMalformedEvidence(harness.client.callTool({
      name: "create_mask",
      arguments: subjectArgs,
    }));
  }, 20_000);

  it("rejects a successful Brush result paired with empty Subject parameters", async () => {
    harness = await startHarness({
      resultFactory: () => ({
        ...successResult(),
        kind_parameters: {},
      }),
    });
    await harness.client.listTools();

    await expectMalformedEvidence(harness.client.callTool({
      name: "create_mask",
      arguments: {
        photo_id: "101",
        expected_photo_uuid: "uuid-copy",
        expected_master_uuid: "uuid-master",
        operation_id: OPERATION_ID,
        mask_kind: "brush",
        name: "Face lift",
        kind_parameters: {
          coordinate_system: "normalized_image",
          coordinate_units: "unit_interval",
          path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
          size: 0.12,
          feather: 0.35,
          flow: 0.7,
          density: 0.8,
        },
        local_settings: { exposure: 0.5, clarity: 12 },
      },
    }));
  }, 20_000);

  it("rejects a successful Subject result paired with Brush parameters", async () => {
    const subjectArgs = {
      photo_id: "101",
      expected_photo_uuid: "uuid-copy",
      expected_master_uuid: "uuid-master",
      operation_id: OPERATION_ID,
      mask_kind: "subject",
      name: "Squirrel Subject",
      kind_parameters: {},
      local_settings: { exposure: 0.65 },
    };
    harness = await startHarness({
      expectedArgs: subjectArgs,
      resultFactory: () => ({
        ...subjectSuccessResult(),
        kind_parameters: successResult().kind_parameters,
      }),
    });
    await harness.client.listTools();

    await expectMalformedEvidence(harness.client.callTool({
      name: "create_mask",
      arguments: subjectArgs,
    }));
  }, 20_000);

  it("normalizes a success payload that also carries validation failure evidence", async () => {
    harness = await startHarness({
      resultFactory: () => ({
        ...successResult(),
        validation_failure: {
          raw_response_json: "{}",
          raw_response_truncated: false,
          raw_response_sha256: "a".repeat(64),
          validator_summary: "must never accompany success",
        },
      }),
    });
    await harness.client.listTools();

    await expectMalformedEvidence(harness.client.callTool({
      name: "create_mask",
      arguments: {
        photo_id: "101",
        expected_photo_uuid: "uuid-copy",
        expected_master_uuid: "uuid-master",
        operation_id: OPERATION_ID,
        mask_kind: "brush",
        name: "Face lift",
        kind_parameters: {
          coordinate_system: "normalized_image",
          coordinate_units: "unit_interval",
          path: [{ x: 0.2, y: 0.3 }, { x: 0.4, y: 0.5 }],
          size: 0.12,
          feather: 0.35,
          flow: 0.7,
          density: 0.8,
        },
        local_settings: { exposure: 0.5, clarity: 12 },
      },
    }));
  }, 20_000);
});
