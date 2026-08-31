# @mskalski/lightroom-mcp

MCP server bridging Claude / Codex / Cursor to Adobe Lightroom Classic via a bundled Lua plugin.

The preset round-trip tools can inspect and compare historical Develop presets, create versioned plugin-managed checkpoints from an edited representative photo, and export a preset backing file without overwriting an existing file. Plugin checkpoints are hidden from Lightroom's Develop panel by Adobe SDK design.

The `create_mask` tool is intentionally narrow: it accepts only a
UUID-verified Workflow Copy, explicit Brush geometry and allowlisted local
settings, creates a plugin checkpoint before mutation, and reports success
only after a readback proves the new mask and preservation invariants. Brush
creation, a full Lightroom restart/reconciliation, and before/after rendering
are live-verified on Lightroom Classic 15.5.1 / ProcessVersion 15.4. That
runtime may rewrite SyncIDs, prefix Dabs with a flow token, and persist feather
only as `CenterWeight`; the adapter accepts these normalizations only for a
unique exact checkpoint delta. Only local Exposure is currently live-verified
across restart on that runtime, so other local settings fail before mutation.
Subject and Sky return explicit `unsupported` until an AI payload adapter can
prove creation and readback. Human visual acceptance remains a separate gate.

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
