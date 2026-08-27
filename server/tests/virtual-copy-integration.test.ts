import { describe, it, expect, afterEach } from "@jest/globals";
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

const TOKEN = "virtual-copy-integration-token";
const OPERATION_ID = "safe-op-007";
const MARKER = `Lightroom MCP VC [${OPERATION_ID}]`;

async function waitFor(check: () => boolean, timeoutMs: number, label: string): Promise<void> {
  const start = Date.now();
  while (!check()) {
    if (Date.now() - start > timeoutMs) {
      throw new Error(`waitFor(${label}) timed out after ${timeoutMs}ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}

function identity(
  catalogId: string,
  uuid: string,
  copyName: string,
  isVirtualCopy: boolean,
) {
  return {
    catalog_id: catalogId,
    uuid,
    path: "/相片/夕陽.jpg",
    filename: "夕陽.jpg",
    copy_name: copyName,
    is_virtual_copy: isVirtualCopy,
  };
}

async function startHarness(): Promise<Harness> {
  const source = identity("100", "uuid-master", "原始版本", false);
  const master = { ...source };
  const copy = identity("103", "uuid-新副本", MARKER, true);
  const siblingOne = identity("101", "uuid-暖色", "暖色版本", true);
  const siblingTwo = identity("102", "uuid-冷色", "冷色版本", true);
  const result = {
    operation_id: OPERATION_ID,
    marker: MARKER,
    result: "created",
    partial: false,
    source,
    master,
    copy,
    is_virtual_copy: true,
    candidates: [siblingOne, siblingTwo],
    candidate_count: 2,
    selection_restoration: { status: "restored", verified: true },
  };
  let malformed = false;
  const [requestPort, responsePort] = await Promise.all([freePort(), freePort()]);
  const plugin = new FakePlugin({
    requestPort,
    responsePort,
    token: TOKEN,
    handler: (action, params) => {
      expect(action).toBe("create_virtual_copy");
      expect(params).toEqual({
        source_photo_id: "100",
        expected_source_uuid: "uuid-master",
        operation_id: OPERATION_ID,
      });
      if (!malformed) return result;
      return {
        ...result,
        copy: { ...copy, is_virtual_copy: "true" },
      };
    },
  });
  await plugin.start();

  let dispatcher: Dispatcher;
  const request = new PluginSocket({
    port: requestPort,
    label: "virtual-copy-request",
    reconnectDelayMs: 25,
    log: () => {},
  });
  const response = new PluginSocket({
    port: responsePort,
    label: "virtual-copy-response",
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
    "virtual-copy sockets connected",
  );

  const server = createMcpServer({
    dispatcher,
    isReady: () => request.isConnected() && response.isConnected(),
  });
  const client = new Client({ name: "virtual-copy-integration-client", version: "1.0.0" });
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

describe("identity-safe Virtual Copy creation across MCP and plugin transports", () => {
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

  it("round-trips typed Master/Copy identities and rejects output type drift", async () => {
    harness = await startHarness();
    const listed = await harness.client.listTools();
    const tool = listed.tools.find((entry) => entry.name === "create_virtual_copy");
    expect(tool?.inputSchema.additionalProperties).toBe(false);
    expect(tool?.inputSchema.required).toEqual([
      "source_photo_id",
      "expected_source_uuid",
      "operation_id",
    ]);
    expect(tool?.outputSchema?.required).toEqual(expect.arrayContaining([
      "operation_id",
      "marker",
      "result",
      "selection_restoration",
    ]));
    expect(tool?.outputSchema?.oneOf).toEqual(expect.arrayContaining([
      expect.objectContaining({
        required: expect.arrayContaining(["source", "master", "copy", "is_virtual_copy"]),
      }),
      expect.objectContaining({ required: expect.arrayContaining(["partial", "reason"]) }),
    ]));

    const callArguments = {
      name: "create_virtual_copy",
      arguments: {
        source_photo_id: "100",
        expected_source_uuid: "uuid-master",
        operation_id: OPERATION_ID,
      },
    } as const;
    const result = (await harness.client.callTool(callArguments)) as ToolResult;

    expect(result.isError).toBeFalsy();
    expect(result.structuredContent?.operation_id).toBe(OPERATION_ID);
    expect(result.structuredContent?.marker).toBe(MARKER);
    expect(result.structuredContent?.source).toEqual(expect.objectContaining({
      catalog_id: "100",
      uuid: "uuid-master",
      path: "/相片/夕陽.jpg",
      filename: "夕陽.jpg",
      is_virtual_copy: false,
    }));
    expect(result.structuredContent?.master).toEqual(result.structuredContent?.source);
    expect(result.structuredContent?.copy).toEqual(expect.objectContaining({
      catalog_id: "103",
      uuid: "uuid-新副本",
      copy_name: MARKER,
      is_virtual_copy: true,
    }));
    expect(result.structuredContent?.candidates).toEqual(expect.arrayContaining([
      expect.objectContaining({ catalog_id: "101", copy_name: "暖色版本" }),
      expect.objectContaining({ catalog_id: "102", copy_name: "冷色版本" }),
    ]));
    expect(JSON.parse(result.content[0].text)).toEqual(result.structuredContent);

    harness.setMalformed(true);
    await expect(harness.client.callTool(callArguments)).rejects.toThrow(
      /structured content does not match/i,
    );
  }, 20_000);
});
