import type { Tool } from "@modelcontextprotocol/sdk/types.js";
import {
  OPERATION_SEMANTICS_META_KEY,
  TOOL_CONTRACT_REVISION_META_KEY,
  TOOL_CONTRACTS,
} from "./tool-contracts.js";

export const TOOL_DEFINITIONS: Tool[] = TOOL_CONTRACTS.map(
  ({ name, description, inputSchema, outputSchema, operationSemantics, contractRevision }) => ({
    name,
    description,
    inputSchema,
    ...(outputSchema ? { outputSchema } : {}),
    _meta: {
      [OPERATION_SEMANTICS_META_KEY]: operationSemantics,
      ...(contractRevision
        ? { [TOOL_CONTRACT_REVISION_META_KEY]: contractRevision }
        : {}),
    },
  }),
);

export function listToolsHandler(): { tools: Tool[] } {
  return { tools: TOOL_DEFINITIONS };
}
