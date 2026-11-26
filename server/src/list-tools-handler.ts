import type { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  OPERATION_SEMANTICS_META_KEY,
  TOOL_CONTRACTS,
} from "./tool-contracts.js";

export const TOOL_DEFINITIONS: Tool[] = TOOL_CONTRACTS.map(
  ({ name, description, inputSchema, outputSchema, extraMeta, operationSemantics }) => ({
    name,
    description,
    inputSchema,
    ...(outputSchema ? { outputSchema } : {}),
    _meta: {
      ...extraMeta,
      [OPERATION_SEMANTICS_META_KEY]: operationSemantics,
    },
  }),
);

export function listToolsHandler(): { tools: Tool[] } {
  return { tools: TOOL_DEFINITIONS };
}
