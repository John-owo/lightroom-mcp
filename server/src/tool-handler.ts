import type { Dispatcher } from "./dispatcher.js";
import { TOOL_CONTRACTS } from "./tool-contracts.js";

export interface ToolHandlerDeps {
  dispatcher: Pick<Dispatcher, "call">;
  isReady: () => boolean;
}

export interface ToolResponse {
  content: Array<{ type: "text"; text: string }>;
  isError?: boolean;
  [key: string]: unknown;
}

const NOT_CONNECTED_MESSAGE =
  "Lightroom plugin not connected. Open Lightroom and click 'Start Server' in Plug-in Manager.";

function asStructuredContent(value: unknown): Record<string, unknown> | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }
  return value as Record<string, unknown>;
}

export function createCallToolHandler(deps: ToolHandlerDeps) {
  return async (name: string, args: unknown): Promise<ToolResponse> => {
    if (!deps.isReady()) {
      return {
        content: [{ type: "text", text: NOT_CONNECTED_MESSAGE }],
        isError: true,
      };
    }

    try {
      const resp = await deps.dispatcher.call(name, args);
      if (resp.error) {
        return {
          content: [{ type: "text", text: `Error: ${resp.error}` }],
          isError: true,
        };
      }
      const response: ToolResponse = {
        content: [{ type: "text", text: JSON.stringify(resp.result, null, 2) }],
      };
      const contract = TOOL_CONTRACTS.find((tool) => tool.name === name);
      if (contract?.outputSchema) {
        const structuredContent = asStructuredContent(resp.result);
        if (structuredContent) response.structuredContent = structuredContent;
      }
      return response;
    } catch (e) {
      return {
        content: [{ type: "text", text: e instanceof Error ? e.message : String(e) }],
        isError: true,
      };
    }
  };
}
