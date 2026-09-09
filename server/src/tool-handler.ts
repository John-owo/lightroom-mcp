import { AjvJsonSchemaValidator } from "@modelcontextprotocol/sdk/validation/ajv";
import { createHash } from "node:crypto";

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
const MAX_RAW_EVIDENCE_CHARS = 16_384;
const MAX_VALIDATOR_SUMMARY_CHARS = 2_048;
const outputValidatorProvider = new AjvJsonSchemaValidator();
const outputValidators = new Map(
  TOOL_CONTRACTS.flatMap((tool) =>
    tool.outputSchema
      ? [[tool.name, outputValidatorProvider.getValidator(tool.outputSchema)] as const]
      : [],
  ),
);

function asStructuredContent(value: unknown): Record<string, unknown> | undefined {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }
  return value as Record<string, unknown>;
}

function boundedRawEvidence(value: unknown): {
  raw_response_json: string;
  raw_response_truncated: boolean;
  raw_response_sha256: string;
} {
  let serialized: string;
  try {
    const json = JSON.stringify(value);
    serialized = typeof json === "string" ? json : String(value);
  } catch {
    serialized = String(value);
  }
  return {
    raw_response_json: serialized.slice(0, MAX_RAW_EVIDENCE_CHARS),
    raw_response_truncated: serialized.length > MAX_RAW_EVIDENCE_CHARS,
    raw_response_sha256: createHash("sha256").update(serialized).digest("hex"),
  };
}

function unverifiedMaskCapability() {
  const unavailableKind = {
    supported: false,
    accepted_parameters: [],
    readback_guarantees: [],
    reason: "Plugin result failed contract validation",
  };
  return {
    lightroom_version: "unverified",
    process_version: "unverified",
    mask_schema: "unverified",
    kinds: {
      brush: unavailableKind,
      subject: unavailableKind,
      sky: unavailableKind,
    },
  };
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
        const validation = structuredContent
          ? outputValidators.get(name)?.(structuredContent)
          : { valid: false, errorMessage: "result is not an object" };
        if (!validation?.valid && (name === "create_mask" || name === "reconcile_mask")) {
          const requestOperationId = asStructuredContent(args)?.operation_id;
          const structuredContent = {
            operation_id:
              typeof requestOperationId === "string" ? requestOperationId : "unknown",
            result: "REVIEW_REQUIRED",
            capability: unverifiedMaskCapability(),
            selection_restoration: {
              status: "not_attempted",
              verified: false,
              reason: "Plugin result failed contract validation",
            },
            reason:
              "Plugin returned malformed post-operation evidence; reconcile by operation ID before retrying",
            validation_failure: {
              ...boundedRawEvidence(resp.result),
              validator_summary: String(
                validation?.errorMessage ?? `result failed ${name} output validation`,
              ).slice(0, MAX_VALIDATOR_SUMMARY_CHARS),
            },
          };
          const recoveryValidation = outputValidators.get(name)?.(structuredContent);
          if (!recoveryValidation?.valid) {
            return {
              content: [
                {
                  type: "text",
                  text: `${name} output and recovery evidence both failed contract validation`,
                },
              ],
              isError: true,
            };
          }
          return {
            content: [
              {
                type: "text",
                text: JSON.stringify(structuredContent),
              },
            ],
            structuredContent,
          };
        }
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
