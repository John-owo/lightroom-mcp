# Lightroom Classic MCP Server

Connect Codex, Claude, and other MCP clients to your **Adobe Lightroom Classic** catalog. Search photos, manage metadata, edit Develop settings, create verified Virtual Copies, and export Lightroom renders through local tools.

> **Preset round-trip fork (v0.10.0):** this branch adds exact preset inspection, historical-preset comparison, versioned checkpoint creation, safe preset export, and the complete `raw-photo-lightroom-preset` v2 Codex skill for RAW culling and iterative editing. See the [Traditional Chinese v2 guide](README.md) or open the [bundled skill](skills/raw-photo-lightroom-preset/SKILL.md).

## TL;DR

The Node.js MCP server connects to a Lua plug-in running inside Lightroom Classic and exposes 20 local tools. You can use this repository on its own or as the Lightroom backend for [`photo-agent`](https://github.com/John-owo/photo-agent). Versioned checkpoint creation, exact read-back, and safe preset export have passed live checks on one Windows Lightroom setup. Import compatibility and visual style still require a check in your Lightroom version with your photos.

## Contents

- [Feature overview](#feature-overview)
- [Architecture and project boundary](#architecture-and-project-boundary)
- [Glossary](#glossary)
- [Quick start](#quick-start)
- [Requirements](#requirements)
- [Install for other AI tools](#install-other-ai-tools)
- [Tools](#tools)
- [Iterative preset workflow](#iterative-preset-workflow)
- [CLI reference](#cli-reference)
- [Security](#security)
- [Develop](#develop)
- [Troubleshooting](#troubleshooting)

## Feature overview

| Area | What you can do |
| --- | --- |
| Catalog search | Find photos and read selected-photo metadata, including stable Master and Virtual Copy identity |
| Organization | Set ratings and keywords, manage collections, and import or export photos |
| Develop controls | Inspect or apply presets, copy settings, and write SDK-supported Develop values |
| Workflow Copies | Create or reconcile one identity-verified Virtual Copy with a reusable operation ID |
| Preset checkpoints | Create, compare, and export versioned plug-in presets without overwriting older files |
| RAW workflow skill | Pair RAW/JPEG files, triage selections, group lighting, and iterate on representative photos |
| Lightroom renders | Export previews or delivery files from Lightroom for read-back and comparison |
| XMP fallback | Generate a new sidecar when MCP is unavailable while refusing source or sidecar overwrite |

## Architecture and project boundary

```text
┌──────────────────────┐   MCP / stdio   ┌──────────────────────┐
│ Codex / Claude /     │ ◄──────────────► │ Node.js MCP server   │
│ photo-agent          │                  └──────────┬───────────┘
└──────────────────────┘                             │ localhost TCP
                                             :58763 │ request
                                             :58764 │ response
                                                    ▼
                                         ┌──────────────────────┐
                                         │ Lightroom Lua plug-in │
                                         └──────────┬───────────┘
                                                    ▼
                                         Lightroom catalog / Develop
```

This repository is the standalone Lightroom Classic integration layer. It owns
the MCP server, Lua plug-in, catalog/develop operations, checkpoints, and
render/export tools. Claude, Codex, or any other MCP client can use it directly.

Higher-level workflow development moved to
[`John-owo/photo-agent`](https://github.com/John-owo/photo-agent) during its v0.1
extraction. PhotoAgent owns durable workflow state, safety/recovery policy,
closed-loop evaluation, culling, scene clustering, and full-shoot orchestration;
it may use this repository as one backend. The dependency is one-way:
`photo-agent -> lightroom-mcp`. Lightroom MCP does not require PhotoAgent.

The bundled `raw-photo-lightroom-preset` remains historical workflow guidance
and a standalone client recipe. New workflow-engine features belong in
PhotoAgent; Lightroom-specific tools and transport belong here.

## Glossary

| Term | Meaning |
| --- | --- |
| MCP | Model Context Protocol, the interface an AI client uses to call this server's Lightroom tools |
| XMP sidecar | A small settings file stored beside a RAW file; it records edits without changing RAW pixels |
| Checkpoint | A named, versioned plug-in preset used to preserve and compare editing steps |
| Workflow Copy | An identity-verified Lightroom Virtual Copy used for automated edits while the Master stays unchanged |
| `REVIEW_REQUIRED` | A fail-closed result that stops automation when read-back cannot prove one safe outcome |
| Closed loop | Render or read back each bounded edit before choosing the next adjustment |

[![npm](https://img.shields.io/npm/v/@mskalski/lightroom-mcp.svg)](https://www.npmjs.com/package/@mskalski/lightroom-mcp)
[![release](https://img.shields.io/github/v/release/Automaat/lightroom-mcp.svg)](https://github.com/Automaat/lightroom-mcp/releases/latest)

> **Works with:** Claude Desktop, Claude Code, Codex CLI, Cursor, Windsurf, VS Code.
> **Needs:** Lightroom Classic on macOS or Windows. Nothing else — no programming required.

---

## Quick start

Use the three-step Claude Desktop installer below, or run this source checkout with Node.js:

```bash
git clone https://github.com/John-owo/lightroom-mcp.git
cd lightroom-mcp/server
npm ci
npm run build
node dist/index.js install-plugin
```

Restart Lightroom Classic, open **File → Plug-in Manager → Lightroom MCP**, and click **Start Server**. Connect your MCP client to `server/dist/index.js`, then begin with a read-only request such as “List my Lightroom collections.” Use a non-critical photo for the first write test.

## Requirements

| Item | Requirement | Notes |
| --- | --- | --- |
| Node.js | 18+ | Required for source builds; CI currently uses 24.19 |
| Lightroom Classic | A version that loads this Lua plug-in | The project does not claim a specific minimum release |
| Operating system | Windows or macOS | This fork's recorded live acceptance used Windows |
| MCP client | Codex, Claude, or another compatible client | PhotoAgent is optional |

## Install (Claude Desktop, 3 steps)

This is the recommended path. Takes ~2 minutes, no terminal needed.

### 1. Download the installer

Go to the [latest release page](https://github.com/Automaat/lightroom-mcp/releases/latest) and download the file ending in **`.mcpb`** (it's near the top, called `lightroom-mcp-<version>.mcpb`).

### 2. Double-click the downloaded file

Claude Desktop opens automatically and asks: *"Install Lightroom Classic extension?"*. Click **Install**.

> Don't have Claude Desktop yet? Get it free from [claude.com/download](https://claude.com/download). It runs on Mac and Windows.

### 3. Turn on the plugin in Lightroom

1. **Quit and reopen Lightroom Classic.** (The plugin needs a restart to show up.)
2. In Lightroom, click **File** in the menu bar → **Plug-in Manager**.
3. In the left list, click **Lightroom MCP**.
4. On the right, click the **Start Server** button.
5. You should see "Server running" appear. Done!

### Try it

Open Claude Desktop and type:

> *List all my Lightroom collections.*

Claude will list every collection in your catalog.

Some other things to try:
- *"Find all my 5-star photos from last summer."*
- *"Add the keyword 'portfolio' to the photos I have selected in Lightroom."*
- *"Apply the 'Vivid' develop preset to these photos."*
- *"Compare my approved 'John Warm v3' preset with the current candidate."*
- *"Create a versioned preset checkpoint from this representative photo and export it."*
- *"Export the selected photos to my Desktop as JPEGs at 2000px wide."*

---

## Install (other AI tools)

Already using Claude Code, Codex, Cursor, Windsurf, or VS Code? Pick your tool below. **All paths still end with the Lightroom step from the section above** — restart Lightroom and click **Start Server** in Plug-in Manager.

<details>
<summary><b>Claude Code</b></summary>

Same `.mcpb` file as Claude Desktop above — Claude Code accepts it too. Or install via the CLI:

```bash
claude mcp add lightroom -- npx -y @mskalski/lightroom-mcp
```

</details>

<details>
<summary><b>Codex CLI</b></summary>

```bash
codex mcp add lightroom -- npx -y @mskalski/lightroom-mcp
```

The Lightroom plugin installs itself the first time Codex talks to the server.

</details>

<details>
<summary><b>Cursor / Windsurf / VS Code (Continue, Cline, Roo, ...)</b></summary>

Open your client's MCP settings and add:

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

The plugin installs itself the first time your client starts the server. If your client only starts the server on first tool call, you can install the plugin upfront:

```bash
npx -y @mskalski/lightroom-mcp install-plugin
```

</details>

<details>
<summary><b>No Node.js installed? Use the standalone binary</b></summary>

1. Download the right file from the [latest release](https://github.com/Automaat/lightroom-mcp/releases/latest):
   - **Mac (Apple Silicon, M1/M2/M3/M4):** `lightroom-mcp-darwin-arm64`
   - **Mac (Intel):** `lightroom-mcp-darwin-x64`
   - **Windows:** `lightroom-mcp-windows-x64.exe`

2. **macOS only** — make it runnable and bypass Gatekeeper (the binary isn't signed):
   ```bash
   chmod +x ~/Downloads/lightroom-mcp-darwin-arm64
   xattr -d com.apple.quarantine ~/Downloads/lightroom-mcp-darwin-arm64
   ```

3. Install the Lightroom plugin:
   ```bash
   ~/Downloads/lightroom-mcp-darwin-arm64 install-plugin
   ```

4. Point your AI tool at the binary's full path. Example for Codex:
   ```bash
   codex mcp add lightroom -- /Users/you/Downloads/lightroom-mcp-darwin-arm64
   ```

</details>

<details>
<summary><b>Install the Lightroom plugin manually (any client)</b></summary>

If you'd rather drop the plugin in by hand:

1. Download the matching zip from the [latest release](https://github.com/Automaat/lightroom-mcp/releases/latest):
   - Mac: `LightroomMCP-macos.lrplugin.zip`
   - Windows: `LightroomMCP-windows.lrplugin.zip`
2. Unzip it. You get a folder called `LightroomMCP.lrplugin`.
3. Move that folder into Lightroom's Modules folder:
   - **Mac:** `~/Library/Application Support/Adobe/Lightroom/Modules/`
   - **Windows:** `%APPDATA%\Adobe\Lightroom\Modules\`
   - (If the `Modules` folder doesn't exist, create it.)
4. Restart Lightroom → **Plug-in Manager** → **Start Server**.

</details>

---

## Something not working?

1. Open Lightroom → **File → Plug-in Manager → Lightroom MCP → Show Status**. Both sockets should say `connected: true`. If not, click **Start Server**.
2. Make sure you **fully quit and reopened Lightroom** after install (Cmd+Q on Mac, Alt+F4 on Windows). "Reload Plug-in" alone is not enough.
3. See [Troubleshooting](#troubleshooting) below for specific errors.

## Tools

The server currently exposes 20 tools. The Virtual Copy creation and
read-only reconciliation tools have automated contract, mock, and transport
coverage; live acceptance of the new reconciliation endpoint is still
pending.

| Tool | What it does |
| --- | --- |
| `search_photos` | Search by filename / keywords / rating / date range. |
| `get_selected_photos` | Photos selected in Lightroom (or filmstrip). |
| `get_photo_metadata` | Stable catalog ID/UUID, Master and Virtual Copy relationships, EXIF, GPS, IPTC location, copyright + develop settings for one catalog photo. Source paths are display-only and cannot be used as photo selectors. |
| `create_virtual_copy` | Create or reconcile one identity-verified Virtual Copy by stable catalog ID, expected Master UUID, and operation marker. Ambiguous or partial outcomes fail closed with `REVIEW_REQUIRED`; collection placement is separate. Contract, mock, and transport integration coverage exists, but live Lightroom acceptance is still pending. |
| `reconcile_virtual_copy` | Read-only recovery query for an interrupted Virtual Copy creation. Scans the exact operation marker, verifies the expected Master and Copy relationship, and returns one Copy or `REVIEW_REQUIRED` without changing selection or creating a Copy. |
| `list_collections` | All collections and collection sets. |
| `create_collection` | New collection (optional parent set). |
| `add_to_collection` | Add photos to a named collection. |
| `set_keywords` | Add or remove keywords on photos. |
| `set_rating` | Set 0-5 star rating on photos. |
| `import_photos` | Import a file or folder into the catalog. |
| `export_photos` | Export with format / quality / dimensions. |
| `list_develop_presets` | Discover Lightroom-visible presets and plugin checkpoints. |
| `get_develop_preset` | Read settings and backing-file metadata for one exact preset. |
| `compare_develop_presets` | Diff an approved historical preset against a candidate. |
| `create_develop_preset` | Capture explicit settings from a photo as a versioned plugin checkpoint. |
| `export_develop_preset` | Copy a custom/checkpoint preset backing file without overwriting. |
| `apply_develop_preset` | Apply an exact preset by UUID or disambiguated name. |
| `copy_develop_settings` | Copy develop settings between photos. |
| `set_develop_settings` | Write SDK setting key/values directly. |

Full schemas and parameter docs: [`server/src/list-tools-handler.ts`](server/src/list-tools-handler.ts).

### Iterative preset workflow

Use a representative photo or virtual copy rather than a master edit:

1. Read an approved historical preset with `get_develop_preset`.
2. Apply bounded setting changes to the representative and export a Lightroom-rendered JPEG.
3. Create a uniquely named checkpoint such as `John Warm v4` with `create_develop_preset`.
4. Compare it with the approved preset using `compare_develop_presets`.
5. Repeat the render/inspect cycle; export the accepted checkpoint with `export_develop_preset`.

`create_develop_preset` uses Adobe's plugin preset API. These checkpoints are intentionally hidden from the Develop panel and are listed with `scope: "plugin"`. They are versioned instead of overwritten. `export_develop_preset` refuses existing destinations and preserves the backing file format Lightroom supplies. Built-in presets without a backing file cannot be exported.

## How it works

```
┌─────────────┐    stdio    ┌──────────────────┐  TCP :58763 →   ┌──────────────────┐
│  AI client  │ ◄─────────► │   MCP server     │ ──────────────► │ Lightroom plugin │
│ (Claude/    │             │  (Node TCP)      │ ←────────────── │   (LrSocket)     │
│  Codex/...) │             └──────────────────┘   ← TCP :58764  └──────────────────┘
└─────────────┘                                                           │
                                                                          ▼
                                                                catalog:withReadAccessDo
```

Plugin binds two `LrSocket` servers on localhost (`58763` request, `58764` response). Server connects as TCP client. Frame: line-delimited JSON, `\n` terminator. Auto-reconnect on both sides. Same dual-port pattern as MIDI2LR.

## CLI reference

```
lightroom-mcp [stdio]            Run MCP over stdio (default)
lightroom-mcp install-plugin     Copy bundled plugin into Lightroom Modules folder
lightroom-mcp --help | --version
```

Env vars:

| Var | Default | Purpose |
| --- | --- | --- |
| `LIGHTROOM_MCP_REQUEST_PORT` | `58763` | Plugin request port. |
| `LIGHTROOM_MCP_RESPONSE_PORT` | `58764` | Plugin response port. |
| `LIGHTROOM_MCP_TOKEN_PATH` | `~/.config/lightroom-mcp/token` | Auth token file. |

If you change ports on the server side, change them in **Plug-in Manager → Lightroom MCP** to match.

## Security

The plugin generates a 256-bit token in `~/.config/lightroom-mcp/token` on **Start Server**. The MCP server attaches it to every request. Localhost-only — no remote attack surface.

## Develop

```bash
mise install                        # tools (node, bun, lua + luarocks, selene)
mise run install                    # npm ci
mise run build                      # tsc
mise run test                       # jest
mise run mcpb                       # build .mcpb bundle
mise run binary                     # build single-file binaries via Bun
mise run lua:lint                   # selene-lint the Lua plugin
mise run lua:test                   # busted specs for the Lua plugin
```

Repo layout:

- `server/` — TypeScript MCP server (ESM, NodeNext).
- `plugin/LightroomMCP.lrplugin/` — Lua plugin loaded by Lightroom Classic.
- `mcpb/manifest.json` — `.mcpb` bundle manifest.
- `scripts/build-mcpb.mjs` — pack the .mcpb.
- `scripts/build-binary.mjs` — Bun `--compile` per-target binaries.
- `manual-test.mjs` — direct TCP probe (bypasses MCP).

## Adding a new tool

1. Add a new `Handler*.lua` under `plugin/LightroomMCP.lrplugin/`.
2. Register it in the `DISPATCH` table in `PluginInfoProvider.lua`.
3. Add a contract entry in `server/src/tool-contracts.ts`.
4. Declare any new LR globals in `lightroom.yml` (selene std).

## Troubleshooting

- **`failed to open localhost:58763` after Reload Plug-in** — old async task still owns the port. Quit Lightroom (Cmd+Q on macOS / Alt+F4 on Windows) and reopen.
- **Plugin not connected** — the server now self-restarts after a Reload Plug-in that tore down a running instance. If it's still stopped, click **Start Server** in Plug-in Manager; it reconnects within ~1s.
- **`MCP error -32000: Connection closed` after a client restart** — an older bridge process may still own the singleton lock. The server now watches MCP stdin and releases its TCP sockets, heartbeat, and lock when the client closes; restart the MCP host once after upgrading so an older child can exit cleanly.
- **`Another Lightroom MCP bridge is already running`** — do not delete the lock file while its PID is alive. Close the owning MCP host/session first; a stale lock with a dead PID is reclaimed automatically on the next start.
- **Timeout errors** — handler may be scanning a large catalog without filters; add `rating`, `filename`, `keywords`, or date filters to narrow.
- **macOS "cannot be opened because the developer cannot be verified"** (binary path) — `xattr -d com.apple.quarantine /path/to/binary`. Or right-click → Open the first time.
- **Windows SmartScreen blocks the .exe** — More info → Run anyway.

Logs:

| Component | macOS | Windows |
| --- | --- | --- |
| Plugin | `~/Documents/LrClassicLogs/LightroomMCP.log` | `%USERPROFILE%\Documents\LrClassicLogs\LightroomMCP.log` |
| Claude Desktop | `~/Library/Logs/Claude/mcp*.log` | `%APPDATA%\Claude\Logs\mcp*.log` |

The plugin resolves its log path via the OS (`LrPathUtils`), so on Windows with
OneDrive-redirected Documents the file follows the redirect. The exact resolved
path is shown as **Log file:** in Plug-in Manager → **Show Status** — use that if
the table path above is empty.

## License

MIT
