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
}

const TOKEN = "identity-integration-token";

async function waitFor(check: () => boolean, timeoutMs: number, label: string): Promise<void> {
  const start = Date.now();
  while (!check()) {
    if (Date.now() - start > timeoutMs) {
      throw new Error(`waitFor(${label}) timed out after ${timeoutMs}ms`);
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
}

async function startHarness(): Promise<Harness> {
  const master = {
    id: 100,
    catalog_id: "100",
    uuid: "uuid-master",
    path: "/相片/夕陽.jpg",
    filename: "夕陽.jpg",
    copy_name: "原始版本",
    is_virtual_copy: false,
    virtual_copy_count: 2,
    virtual_copies: [
      {
        id: 101,
        catalog_id: "101",
        uuid: "uuid-copy-one",
        path: "/相片/夕陽.jpg",
        filename: "夕陽.jpg",
        copy_name: "暖色版本",
        is_virtual_copy: true,
      },
      {
        id: 102,
        catalog_id: "102",
        uuid: "uuid-copy-two",
        path: "/相片/夕陽.jpg",
        filename: "夕陽.jpg",
        copy_name: "冷色版本",
        is_virtual_copy: true,
      },
    ],
  };
  const masterReference = {
    id: master.id,
    catalog_id: master.catalog_id,
    uuid: master.uuid,
    path: master.path,
    filename: master.filename,
    copy_name: master.copy_name,
    is_virtual_copy: master.is_virtual_copy,
  };
  const photos: Record<string, Record<string, unknown>> = {
    "100": master,
    "101": {
      ...master.virtual_copies[0],
      master: masterReference,
      master_id: master.catalog_id,
      master_uuid: master.uuid,
      virtual_copy_count: 0,
    },
    "102": {
      ...master.virtual_copies[1],
      master: masterReference,
      master_id: master.catalog_id,
      master_uuid: master.uuid,
      virtual_copy_count: 0,
    },
    "999": {
      ...master,
      catalog_id: "999",
      uuid: "uuid-malformed",
      virtual_copy_count: "2",
    },
  };
  const [requestPort, responsePort] = await Promise.all([freePort(), freePort()]);
  const plugin = new FakePlugin({
    requestPort,
    responsePort,
    token: TOKEN,
    handler: (action, params) => {
      expect(action).toBe("get_photo_metadata");
      const photoId = (params as { photo_id: string }).photo_id;
      return photos[photoId];
    },
  });
  await plugin.start();

  let dispatcher: Dispatcher;
  const request = new PluginSocket({
    port: requestPort,
    label: "identity-request",
    reconnectDelayMs: 25,
    log: () => {},
  });
  const response = new PluginSocket({
    port: responsePort,
    label: "identity-response",
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
    "identity sockets connected",
  );

  const server = createMcpServer({
    dispatcher,
    isReady: () => request.isConnected() && response.isConnected(),
  });
  const client = new Client({ name: "identity-integration-client", version: "1.0.0" });
  const [clientTransport, serverTransport] = InMemoryTransport.createLinkedPair();
  await Promise.all([server.connect(serverTransport), client.connect(clientTransport)]);
  return { client, server, plugin, request, response };
}

describe("persistent photo identity across MCP and plugin transports", () => {
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

  it("round-trips Master and both Chinese Virtual Copies with typed structured content", async () => {
    harness = await startHarness();
    const listed = await harness.client.listTools();
    const metadataTool = listed.tools.find((tool) => tool.name === "get_photo_metadata");
    expect(metadataTool?.outputSchema?.required).toEqual(expect.arrayContaining([
      "catalog_id",
      "uuid",
      "is_virtual_copy",
      "virtual_copy_count",
    ]));

    const expectedIds = ["100", "101", "102"];
    for (const photoId of expectedIds) {
      const result = (await harness.client.callTool({
        name: "get_photo_metadata",
        arguments: { photo_id: photoId },
      })) as ToolResult;

      expect(result.isError).toBeFalsy();
      expect(result.structuredContent?.catalog_id).toBe(photoId);
      expect(result.structuredContent?.uuid).toMatch(/^uuid-/);
      expect(JSON.parse(result.content[0].text)).toEqual(result.structuredContent);
    }

    const masterResult = (await harness.client.callTool({
      name: "get_photo_metadata",
      arguments: { photo_id: "100" },
    })) as ToolResult;
    expect(masterResult.structuredContent?.virtual_copies).toEqual(expect.arrayContaining([
      expect.objectContaining({ catalog_id: "101", uuid: "uuid-copy-one", copy_name: "暖色版本" }),
      expect.objectContaining({ catalog_id: "102", uuid: "uuid-copy-two", copy_name: "冷色版本" }),
    ]));

    await expect(harness.client.callTool({
      name: "get_photo_metadata",
      arguments: { photo_id: "999" },
    })).rejects.toThrow(/structured content does not match/i);
  }, 20_000);
});
