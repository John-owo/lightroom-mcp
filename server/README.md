# @mskalski/lightroom-mcp

MCP server bridging Claude / Codex / Cursor to Adobe Lightroom Classic via a bundled Lua plugin.

The preset round-trip tools can inspect and compare historical Develop presets, create versioned plugin-managed checkpoints from an edited representative photo, and export a preset backing file without overwriting an existing file. Plugin checkpoints are hidden from Lightroom's Develop panel by Adobe SDK design.

The `create_mask` tool is intentionally narrow: it accepts only a
UUID-verified Workflow Copy and allowlisted local settings, creates a
non-overwriting plugin checkpoint before mutation, and reports success only after
readback proves the new mask and preservation invariants. Brush uses explicit
geometry. Subject adds a request fingerprint to its checkpoint, calls Lightroom SDK Select Subject, accepts only one exact
`Mask/Image` / `MaskSubType=1` checkpoint delta, and preserves Lightroom's
opaque AI payload. Reused checkpoints never blindly re-invoke the AI controller.
The advertised `create-mask.v2` contract also includes fail-closed transport
handling: if the plug-in returns malformed post-operation output, the server
does not expose it as successful structured content. It returns a schema-valid
`REVIEW_REQUIRED` result with explicitly unverified capability/selection state,
the request operation ID, a full-payload SHA-256, and at most 16,384 characters
of serialized raw evidence. Standard MCP clients can therefore preserve the
failure for reconciliation without blindly retrying the mutation.
Brush and Subject creation, full Lightroom restart/reconciliation, and isolated
before/after rendering are live-verified on Lightroom Classic 15.5.1 /
ProcessVersion 15.4. Only local Exposure is currently live-verified across
restart on that runtime, so other local settings fail before mutation. Sky
remains explicit `unsupported`. The user gave the T63 Subject v8 render a
functional `render PASS`, confirming that the mask is active. Its deliberately
strong `+0.65 EV` appearance remains aesthetically over-bright and is diagnostic
evidence, not a publishable edit.

## Quick install

### Claude Desktop / Claude Code (one-click)

Grab the `.mcpb` from [GitHub Releases](https://github.com/Automaat/lightroom-mcp/releases/latest) and double-click. The Lightroom plugin auto-installs on first run.

### Codex CLI

```bash
codex mcp add lightroom -- npx -y @mskalski/lightroom-mcp
```

Then install the Lightroom plugin once:

```bash
npx -y @mskalski/lightroom-mcp install-plugin
```

### Cursor / Windsurf / VS Code

Add to MCP config:

```json
{
  "mcpServers": {
    "lightroom": {
      "command": "npx",
      "args": ["-y", "@mskalski/lightroom-mcp"]
    }
  }
}
```

## Commands

```
lightroom-mcp [stdio]            Run MCP over stdio (default)
lightroom-mcp install-plugin     Copy plugin into Lightroom Modules folder
```

## Docs and source

Full documentation, architecture notes, and the Lightroom plugin live at
<https://github.com/Automaat/lightroom-mcp>.

## License

MIT
