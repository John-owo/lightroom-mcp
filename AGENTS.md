# LIGHTROOM-MCP project instructions

Rule set: LIGHTROOM-MCP-20260905.

## 必要照片安全

- Never delete, rename, or overwrite a photo, RAW, JPEG/HEIC/TIFF, sidecar,
  preview, or export. This includes derived images and Lightroom-managed storage.
- Automated Lightroom Develop mutations target only an identity-verified
  **Workflow Copy**. Verify Copy ID/UUID, its Master relationship, catalog identity,
  and operation/session identity; a shared file path is not identity proof.
- Preserve the source asset and **Master Develop State**. Never modify the Master.
  Read-only Master inspection is allowed; create a Copy only for an authorized,
  executable edit. Retain existing Copies and reconcile the exact Copy on resume.
- Missing capability, uncertain identity, selection restoration failure, or an
  uncertain mutation result means **REVIEW_REQUIRED**. Stop mutations; read back
  and reconcile before any further action. Never blindly retry or create a second
  Copy to resolve uncertainty. Serialize Lightroom operations.
- A **Checkpoint is recovery evidence, not true Lightroom undo**. It does not
  replace a Workflow Copy or prove restoration of catalog, masks, files, or UI.
- Actual Lightroom execution and human render acceptance are separate gates.
  Only a recorded user `render PASS` satisfies the human gate for that exact run.

## Authority, scope, and first read

- This `AGENTS.md` is the authoritative project instruction entry. Any `CLAUDE.md`
  is a one-way compatibility pointer, not another maintained rule source.
- When working under `D:\photo`, read `D:\photo\AGENTS.md` and consult
  `D:\photo\PHOTO_WORKSPACE.md` for local paths. Do not assume an outer rule file
  was automatically loaded by Codex. Read each rule source once per task; do not
  follow already-read parent/project references repeatedly. The safety rules above
  also apply elsewhere.
- Start with the short current-state source below, then inspect this checkout's
  branch, HEAD, package version and dirty status. Use a supplied handoff only if
  its worktree/commit matches; otherwise treat it as historical evidence.
- Read only the relevant `WORKLOG.md` sections using headings, targeted `rg`, or
  a bounded tail (normally 80-120 lines). Do not load the entire history by default.
- Keep status separate: implemented, local tests passed, live Lightroom passed,
  human render accepted, merged, and deployed. Each claim needs its worktree,
  branch/commit, date and evidence. A package version is not an acceptance verdict.
  Local remote-tracking refs are cached evidence, not current remote verification.
- Current user scope controls actions. In a read-only task, do not create/append
  files (including logs), stage changes, fetch refs, build, test with output, start
  services, or call mutating tools. Report findings in chat; log only after write
  authorization. Tool names such as "read/export" do not prove no side effects.
- When writes are authorized, append material changes and exact verification
  commands/results (including failures and unrun boundaries) to this checkout's
  `WORKLOG.md`. Batch related checks in one factual entry; never rewrite history
  except an explicitly authorized, backed-up encoding repair.
- Preserve unrelated staged, unstaged and untracked changes. Worktree copies are
  independent; do not copy completion claims or bulk-update historical snapshots.
- User-approved delivery policy (2026-09-06): autonomously complete the normal
  commit/push/PR/merge, evidence-backed issue closure and deployment steps needed
  for the assigned implementation, fix or delivery. Do not require separate approval
  for each step. Stay within the task and verified target; preserve unrelated work
  and satisfy checks, required review and acceptance gates. Current read-only,
  local-only or no-publication instructions take precedence. Do not force-push,
  bypass protections, publish unrelated changes/messages or change repository features.
- The user authorizes bounded autonomous delegation. Choose gpt-5.6-luna for
  straightforward or repetitive work and gpt-5.6-sol for complex work, with suitable
  reasoning effort. Investigate missing information before reporting a real blocker;
  the main agent retains integration and final verification.
- Source/docs/tests and necessary builds belong in their repository's established
  paths. Extra reviews, backups, exports and audit output go under
  `D:\photo\_agent_workspace`. This exception never permits photo deletion or
  overwriting source images, sidecars, previews or exports.
- Documentation-only edits need link, encoding, instruction/type and scoped diff
  checks. Run code tests/builds only when the changed behavior or repository gate
  requires them; a prior pass is historical, not a test run in this task.

First state source: [photo-agent-t09-t58-t60-final-validation-matrix-20260901-v1.md](D:/photo/_agent_workspace/lightroom/handoffs/photo-agent-t09-t58-t60-final-validation-matrix-20260901-v1.md); read only its current-state block first. If this local handoff is unavailable,
use the short index in [WORKLOG.md](WORKLOG.md), verify the local checkout/HEAD,
and treat the recorded snapshot as historical until matched.

## Lightroom engineering reference

MCP server bridging Claude to Adobe Lightroom Classic.

## Layout

- `server/` — TypeScript MCP server (ESM, NodeNext). Stdio transport for Claude + raw TCP client to plugin sockets.
- `plugin/LightroomMCP.lrplugin/` — Lua plugin loaded by Lightroom Classic.
- `manual-test.mjs` — historical direct TCP probe. Its separate hello frame is
  incompatible with the per-message authentication described by the T09 work log.
  Do not treat it as a current health check or run a second client against an occupied bridge.

## Architecture (read before changing transport)

Plugin opens **two LrSocket binds** as servers; MCP server connects to both.

- Plugin :58763 (default) in `mode='receive'` — server writes line-delimited JSON requests
- Plugin :58764 (default) in `mode='send'` — server reads line-delimited JSON responses
- Frame: `\n` terminator on every message (LrSocket buffers until newline)
- Plugin allows **one client per port at a time**. MCP server holds a persistent connection.
- `LrSocket.bind` in `mode='receive'` has a 10s no-client timeout that fires `onError`. Plugin auto-calls `:reconnect()` from a monitor loop in response. Reconnect storms are prevented by setting flags in callbacks and acting on them in the loop (never `:reconnect()` synchronously from `onError`).
- `onMessage` runs in non-yielding context — handler dispatch must be wrapped in `LrTasks.startAsyncTask` so `catalog:withReadAccessDo` can yield.
- Catalog queries that yield (`getTargetPhotos`, `findPhotos`) must run **outside** `withReadAccessDo`. Nesting a yielding query inside the read gate deadlocks on Windows: the task yields to the UI thread holding the gate, never returns, never releases it, wedging the bridge until the server timeout (#124/#134). Only non-yielding per-photo metadata reads belong inside the gate. `getAllPhotos` is a non-yielding enumeration, safe either side. Specs guard this via `getQueriedInsideReadAccess()` in `spec_helper`.

Pattern verified against MIDI2LR (`rsjaffe/MIDI2LR`, see `src/plugin/Client.lua`) — same dual-port LrSocket model, ports 58763/58764 also chosen there.

## Commands

Use mise tasks from repo root:

- `mise run install` — currently npm install in `server/`; use explicit
  `npm.cmd ci` for a lockfile-based reproducibility check when installation is authorized
- `mise run build` — `tsc` (outputs `server/dist/`)
- `mise run test` — Jest (ESM via ts-jest)
- `mise run dev` — `tsc --watch`
- `mise run lua:lint` — `selene plugin/LightroomMCP.lrplugin`
- `mise run lua:test` — `busted` specs for the plugin

Lua tooling: `mise install` provisions `lua` + `luarocks` + `selene`. `lua:test` auto-installs `busted` into `lua_modules/` (gitignored) via the `lua:deps` task. `selene` is a mise tool (`aqua:Kampfkarren/selene`), a native binary that does not run on `lua` — so unlike luacheck it is immune to Lua-version breakage. `selene.toml` configures it; `lightroom.yml` is the custom std declaring LR SDK globals; `JSON.lua` is excluded.

## CI

- `.github/workflows/ci.yml` — build+test on ubuntu/macos/windows, Node 24.15.0.
- `.github/workflows/lua-lint.yml` — selene (via mise-action) on plugin changes.
- Type check runs `npm run check` (`tsc --noEmit` on src + `tsconfig.test.json` on tests); do not break it.
- Lint runs `npm run lint` (ESLint flat config, type-aware rules over src + tests); do not break it.

## Pre-commit checklist

For TypeScript behavior changes run the following gates; add Lua checks when Lua changes.
Documentation-only checks follow the scoped validation rule above:

- `cd server && npm run check` — type check (src + tests) must pass
- `cd server && npm run lint` — ESLint must pass
- `mise run build` — `tsc` compile must succeed
- `mise run test` — Jest suite must pass
- `mise run lua:lint` — only if Lua changed
- `mise run lua:test` — only if Lua changed

## Plugin install (automation permitted)

User-approved policy (2026-09-06): installation, updates and controlled reloads may
be automated when needed for the assigned Lightroom task, without separate manual
installation approval. Identify the actual loaded path/catalog and intended source/
version, back up the existing installation and stage a versioned replacement.
Switch/reload only with no conflicting Lightroom or bridge operation; do not blindly
overwrite an in-use or unknown plug-in, terminate Lightroom or modify the catalog.
Verify the actual loaded version, connectivity and a safe read afterward. If identity
or the result is uncertain, stop mutations and reconcile before continuing. Workflow
Copy and human render acceptance requirements remain in force.
The following legacy install locations are examples only:
- macOS: `~/Library/Application Support/Adobe/Lightroom/Plugins/`
- Windows: `%APPDATA%\Adobe\Lightroom\Plugins\`

Bundle is pure Lua — same content ships in both `LightroomMCP-macos.lrplugin.zip` and `LightroomMCP-windows.lrplugin.zip` release artifacts. Split is for download UX, not platform code.

Click **Start Server** in Plug-in Manager. Logs at `~/Documents/LrClassicLogs/LightroomMCP.log`.

**Reload behaviour**: "Reload Plug-in" cancels the old task's `LrFunctionContext` (freeing its LrSocket ports) and starts fresh. PluginInit sleeps 0.5 s before binding so the context cancel can flush. Server is ready in ~1 s.

## Conventions

- TS strict mode on. ESM imports must include `.js` extension (NodeNext).
- New Lua handlers: add file under `plugin/LightroomMCP.lrplugin/Handler*.lua`, register in `DISPATCH` table in `PluginInfoProvider.lua`, declare any new LR globals in `lightroom.yml`.
- New MCP tool: add contract in `server/src/tool-contracts.ts` **and** add a `DISPATCH` entry in `PluginInfoProvider.lua`.
- Default ports `58763` (request) / `58764` (response). Server overrides via env vars `LIGHTROOM_MCP_REQUEST_PORT` / `LIGHTROOM_MCP_RESPONSE_PORT` (parsed in `server/src/ports.ts`); plugin overrides via Plug-in Manager fields stored in `LrPrefs` (`requestPort` / `responsePort`). Both sides must agree — change in lockstep.
