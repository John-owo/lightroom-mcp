# lightroom-mcp work log

Every agent reads this file after `CLAUDE.md`. Keep entries factual and use the
named files as the starting point instead of scanning the whole repository.

## 2026-08-12 - project-boundary documentation

Baseline observed:

- Branch `main` was two commits ahead of `upstream/main` and matched
  `origin/main` at `19431c0`.
- Pre-existing uncommitted lifecycle work exists in `README.en.md`,
  `server/README.md`, `server/src/dispatcher.ts`, `server/src/index.ts`,
  `server/tests/dispatcher.test.ts`, and `server/tests/stdio-lifecycle.test.ts`.
  Preserve it; it is not part of the project-boundary documentation request.

Requested update:

- Clarify in the README that this repository is the standalone Lightroom
  Classic MCP bridge/backend, while `John-owo/photo-agent` owns higher-level
  workflow orchestration, evaluation, culling, clustering, and batch decisions.
- Document the v0.1 extraction history and link both repositories in both
  directions. README edits and their targeted checks are still pending.

Unverified boundaries:

- No live Lightroom connection, plugin/UI test, or visual QA has been performed
  in this continuation.

### Documentation checkpoint

- Updated `README.md` and `README.en.md` with the project boundary and extraction
  history.
- Defined the dependency as `photo-agent -> lightroom-mcp`: this repository owns
  Lightroom transport/tools and remains independently usable; PhotoAgent owns
  orchestration, evaluation, culling, clustering, and batch job state.
- Preserved all pre-existing server lifecycle changes. Post-documentation diff
  checks are still pending; no runtime behavior was changed by this checkpoint.

### Verification checkpoint

- `git diff --check`: passed for the complete working tree.
- Targeted literal checks confirmed both README languages contain the one-way
  dependency and link to `John-owo/photo-agent`.
- No Lightroom runtime tests were required for this documentation-only change;
  the pre-existing server lifecycle code remains outside this task's verified
  scope.
- Updated the workspace-level `D:\photo\AGENTS.md` to require every agent to
  read the active project's nearest `WORKLOG.md` first, use targeted paths and
  searches, and append material updates plus pass/fail checks. No Lightroom code
  or photo was changed by this workspace-instruction update.
- `git diff --check` passed after the instruction update; Git emitted only
  line-ending normalization warnings. Targeted literal checks confirmed both
  README languages contain the PhotoAgent boundary and one-way dependency, and
  this repository's `AGENTS.md` requires reading `WORKLOG.md` first.

## 2026-08-12 - authorized publish preparation

- User authorized pushing both repositories.
- This worktree is mixed. The project-boundary update scope is limited to
  `AGENTS.md`, `README.md`, `README.en.md`, and this `WORKLOG.md`.
- The pre-existing lifecycle changes in `server/README.md`,
  `server/src/dispatcher.ts`, `server/src/index.ts`,
  `server/tests/dispatcher.test.ts`, and the untracked
  `server/tests/stdio-lifecycle.test.ts` remain unstaged and will not be pushed
  by this publish.
- Current branch is `main`; before committing the confirmed documentation scope,
  create a feature branch and push that branch to
  `https://github.com/John-owo/lightroom-mcp.git`.
- Fresh publish-scope verification: `git diff --check` passed with only Git's
  normal LF-to-CRLF normalization warnings. Targeted literal checks confirmed
  both README languages still contain the PhotoAgent link and one-way dependency.
- No Lightroom runtime test was run because the staged scope is documentation and
  agent instructions only; existing lifecycle code remains unstaged and outside
  this publish.
- Created branch `codex/project-boundary-docs` from `main` for this authorized
  documentation publish. The existing server lifecycle edits remain untouched.
- Authorized push succeeded: branch `codex/project-boundary-docs` was created on
  `origin` at commit `0ccfc88`. GitHub printed the pull-request URL; no PR was
  created because the user authorized pushing, not PR creation.
- Final ref/status check: local `HEAD` and `origin/codex/project-boundary-docs`
  both equal `cc51c6a`. Only the pre-existing server lifecycle files remain
  modified/untracked locally; the published documentation scope is clean.

## 2026-08-27 - roadmap implementation orchestration baseline

- Read the workspace/project instructions, `CLAUDE.md`, this work log, PhotoAgent
  roadmap/domain documents, and the published GitHub issue graph before selecting
  implementation work. Live GitHub readback showed all 61 roadmap nodes open.
- Selected unblocked backend tickets T01 (`lightroom-mcp#2`) and T02
  (`lightroom-mcp#3`) for parallel isolated implementation because both are
  prerequisites of T03 and neither depends on live Lightroom evidence.
- Preserved the mixed configured checkout at `D:\photo\lightroom-mcp-john` and
  created clean worktrees from committed baseline `46d3543` for T01, T02, and
  integration review. The first sandboxed `git worktree add -b` attempt created
  branch refs but failed to create worktree metadata with `Permission denied`;
  the approved retry attached the existing refs successfully.
- Integration baseline `npm.cmd run check` and `npm.cmd run lint` passed. The
  first combined command yielded while tests were still running, so it was not
  counted as a complete suite result. The explicit `npm.cmd test -- --runInBand`
  rerun passed: 13 suites and 160 tests. `npm.cmd run build` passed.
- `git status --short` and `git diff --check` were clean after the baseline.
  A read-only `Get-CimInstance Win32_Process` diagnostic was denied by Windows
  access control; it did not change repository or runtime state.
- No Lightroom connection, catalog operation, photo mutation, visual QA, GitHub
  write, commit, push, or issue closure has been performed by this baseline.

## 2026-08-27 - T01 identity implementation

- Read this worktree's `AGENTS.md`, `CLAUDE.md`, `WORKLOG.md`, and workspace
  `PHOTO_WORKSPACE.md` before inspecting code. Worktree branch is
  `codex/roadmap-t01`; status was clean at `46d3543`.
- `gh issue view 2 --repo John-owo/lightroom-mcp --comments` could not reach
  GitHub from the sandbox (`connectex ... socket ... forbidden`). The issue
  acceptance criteria supplied by the orchestrator are the active scope.
- Web retrieval of the issue page/API was attempted but returned cache miss /
  unsafe URL; no live GitHub issue evidence is claimed.
- Escalated read-only `gh issue view 2 --repo John-owo/lightroom-mcp --json
  number,title,body,state,labels,assignees,parent,subIssues,blockedBy,blocking,url`.
  GitHub confirms title `[T01] Read stable Lightroom photo identity and
  relationships`, no blockers, and blocker edge to issue #4 `[T03] Create and
  reconcile an identity-verified Workflow Copy`. Acceptance criteria are:
  distinguish Master/every Virtual Copy sharing a path; fail closed for
  path-only or ambiguous identity; cover persistent identity and non-ASCII data
  in MCP contract/integration tests.
- Targeted repository inventory found the existing TypeScript contract at
  `server/src/tool-contracts.ts`, server tests under `server/tests`, plugin
  dispatch in `plugin/LightroomMCP.lrplugin/PluginInfoProvider.lua`, and Lua
  handlers/specs under the corresponding plugin/spec directories.
- Read-only dependency audit: issue #4 is blocked by #2 (T01) and #3 (T02);
  issue #2 has no blockers and blocks #4. The T01 implementation therefore
  stops at identity/readback and does not implement creation/serialization,
  which belongs to T03/T02.
- Read-only `gh issue view 3 ...`: T02 owns the serialized plugin queue,
  exclusive selection ownership, operation concurrency/retry semantics, and
  queue/error-finalization/dispatch-parity tests. T01 avoids those boundaries.
- `gh issue view 2 --json comments` returned no comments, so no additional
  issue-specific acceptance detail was available.
- TDD red test added first in `plugin/spec/HandlerMetadata_spec.lua` for
  persistent catalog/UUID identity, Master/Virtual Copy relationships, copy
  names, and non-ASCII catalog data. Implementation is intentionally pending
  until the red result is observed.
- `mise exec -- busted plugin/spec/HandlerMetadata_spec.lua` failed because
  this worktree's `.mise.toml` was untrusted; `mise trust` succeeded in the
  local mise state, but `mise run lua:deps` then failed before running tests
  because network/tool-install access is unavailable and the existing shared
  `lua_modules` junction has no `bin/busted`. No Lua test result is claimed.
- Added the first TypeScript red test in `server/tests/list-tools-handler.test.ts`
  for a stable catalog-ID schema and persistent identity wording. The targeted
  command `npm test -- --runInBand server/tests/list-tools-handler.test.ts`
  failed as expected: the existing `photo_id` schema lacked `minLength` and
  numeric `pattern`; 55 existing tests passed and the new test failed.
- Implemented the smallest contract change: `get_photo_metadata.photo_id` now
  requires a non-empty numeric catalog ID, and its description documents UUID,
  Master/Virtual Copy readback and path rejection. The same targeted TypeScript
  test command passed (56/56).
- Implemented the identity readback seam in `PhotoIdentity.lua` and enriched
  metadata, search, and selection photo results with canonical string
  `catalog_id`, persistent `uuid`, `copy_name`, `is_virtual_copy`, Master
  identity, and the Master's complete Virtual Copy identity list. The helper
  reads only official SDK metadata keys (`uuid`, `isVirtualCopy`,
  `masterPhoto`, `virtualCopies`, `countVirtualCopies`, and formatted
  `copyName`). `PhotoLookup` now rejects path identifiers and duplicate local
  catalog IDs instead of guessing.
- Fallback Lua spec runner verification (the repository's official Busted
  runner is unavailable in this environment): all 12 plugin spec files passed,
  `RESULT: 127 passed, 0 failed`.
- Targeted TypeScript integration verification:
  `npm test -- --runInBand server/tests/list-tools-handler.test.ts
  server/tests/server.test.ts` passed 2 suites and 69/69 tests.
- `npm run check` passed after the identity contract and handler changes.
- `luac.exe -p` passed for all 10 changed Lua source/spec files.
- `selene.exe` over the 10 changed Lua source/spec files failed with 189
  pre-existing-style spec-environment diagnostics (`describe`, `it`, Busted
  assertions, and helper globals are not declared by the repository's Selene
  config) plus 3 warnings; this is a lint limitation rather than a parse
  failure. A source-only lint run is recorded next.
- Source-only `selene.exe` lint for the five changed plugin modules passed:
  `0 errors, 0 warnings, 0 parse errors`.
- Server `npm run lint` passed (`eslint src tests`).
- Server `npm run build` passed (`tsc`).
- Server `npm test -- --runInBand` passed: 13 suites, 162 tests.
- `git diff --check` passed; Git emitted only expected LF-to-CRLF normalization
  warnings for modified text files.
- Tightened the remaining singular MCP photo selectors (`copy_develop_settings`
  source and `set_develop_settings` photo) to reuse the non-empty numeric
  catalog-ID schema; targeted `npm test -- --runInBand
  server/tests/list-tools-handler.test.ts` passed 56/56.
- Final server `npm run check` passed (`tsc --noEmit` and test-config typecheck).
- Final server `npm run lint` passed (`eslint src tests`).
- Final server `npm run build` passed (`tsc`).
- Final server `npm test -- --runInBand` passed: 13 suites, 162 tests.
- Final `git diff --check` passed; only expected LF-to-CRLF normalization
  warnings were emitted.
- Reviewed the uncommitted diff against base `46d3543` and T01 acceptance:
  identity output is additive, selectors are catalog-ID-only, duplicate IDs
  fail closed, and the existing `PluginInfoProvider` dispatch mapping remains
  intact. No unresolved in-scope spec gap was found; no real Lightroom/live
  evidence is available in this environment.
- Finalization plan: stage only the T01 files listed by `git status`, run
  cached diff checks, and commit with a message referencing issue #2 on
  `codex/roadmap-t01`.
- Initial `git add` failed before staging because Git could not create the
  worktree index lock under the shared repository metadata:
  `Permission denied` for
  `D:/photo/lightroom-mcp-john/.git/worktrees/lightroom-mcp-t01/index.lock`.
- Escalated `git add` succeeded for the scoped T01 files. `git diff --cached
  --check` passed with no whitespace errors.
- `git commit -m "feat: expose stable Lightroom photo identity (#2)"`
  succeeded as `a5d6121`. The final append-only worklog entry will be folded
  into this same commit with `git commit --amend --no-edit`; no additional
  source changes are planned.
- Review correction: the amend completed and superseded `a5d6121` with final
  commit `d453190`; the repository is currently clean at `d453190`. This
  entry is append-only factual history; the review-fix commit will be added
  without rewriting either prior commit.
- Review-fix red run: targeted Jest could not compile because the inferred
  output schema widened `type` to `string`, which is incompatible with the
  MCP Tool output-schema literal type `"object"`.
- Review-fix Lua red run: the existing unknown-photo test passed the now-invalid
  identifier `"missing"`; after numeric-only validation this correctly failed
  closed, so the test was updated to use unknown numeric ID `"999"`.
- Review-fix targeted Lua fallback runner passed: HandlerMetadata,
  PhotoLookup, HandlerSelection, and HandlerSearch specs, `RESULT: 47 passed,
  0 failed`.
- Review-fix targeted server run passed: list-tools, MCP server, and real
  Dispatcher/FakePlugin transport integration suites, 3 suites and 71 tests.
- Expanded the transport integration to assert the MCP client rejects a
  malformed `virtual_copy_count` type; `npm test -- --runInBand
  server/tests/identity-integration.test.ts` passed 1/1.
- Review-fix full Lua fallback runner passed all 12 plugin specs:
  `RESULT: 129 passed, 0 failed`.
- `luac.exe -p` passed for all 30 plugin Lua source/spec files.
- Review-fix source-only Selene lint passed for the five changed plugin
  modules: `0 errors, 0 warnings, 0 parse errors`.
- Review-fix server `npm run check` passed (`tsc --noEmit` and test-config
  typecheck).
- Review-fix server `npm run lint` passed (`eslint src tests`).
- Review-fix server `npm run build` passed (`tsc`).
- Review-fix full server `npm test -- --runInBand` passed: 14 suites, 164
  tests.
- Review-fix `git diff --check` passed; Git emitted only expected
  LF-to-CRLF normalization warnings.
- Final pre-commit `git diff --check` passed; only expected LF-to-CRLF
  normalization warnings were emitted.
- Review-fix finalization plan: stage the scoped identity, lookup, output
  contract, integration-test, compatibility-test, and WORKLOG changes, then
  create a new commit `fix: close T01 review findings (#2)` without rewriting
  `d453190`.
- Review-fix scoped `git add` succeeded and `git diff --cached --check`
  passed with no whitespace errors. A new commit will follow without
  rewriting `d453190`.
- Standards re-review correction: the earlier commit/amend planning entries
  above are superseded by the factual result recorded here. Review-fix commit
  `229d524` was successfully created; post-commit `git status --short
  --branch` returned only `## codex/roadmap-t01`, so the T01 review-fix
  worktree was clean and no commit remained pending at that verification.
- Worklog-only correction `git diff --check` passed; Git emitted only the
  expected LF-to-CRLF normalization warning.

## 2026-08-27 - T02 serialization investigation

- Started on branch `codex/roadmap-t02` in the dedicated T02 worktree. Read
  `AGENTS.md`, `CLAUDE.md`, and this work log before inspecting code. Existing
  working tree was clean; no unrelated edits were present.
- Read the implement and TDD skill instructions. The agreed seams are the
  server request-dispatch boundary and the public operation-semantics contract;
  tests will observe those interfaces rather than private queue helpers.
- GitHub issue/repository inspection was attempted with `gh issue view` for
  `John-owo/lightroom-mcp#3`, the parent repository issue, and issue listing;
  all failed before request creation because the sandbox denied the GitHub API
  socket. Direct web fetches of the same GitHub URLs also returned cache-miss
  errors. No GitHub/live-Lightroom evidence is claimed; implementation scope
  follows the delegated #3 acceptance criteria and local architecture.
- Targeted local inspection found the current `Dispatcher` sends every call
  immediately while the Lua `PluginInfoProvider` dispatches each request in a
  new async task, so serialized ownership and contract exposure are not yet
  present.
- Added the first red TDD slice at the plugin request-dispatch boundary: two
  authenticated requests must share one queued worker, preserve arrival order,
  and finalize in-flight bookkeeping.
- Verification attempt `mise run lua:test -- plugin/spec/PluginInfoProvider_spec.lua`
  could not start because `mise` is not available in this environment; no Lua
  test result is claimed yet.
- The delegated mise runtime was then invoked explicitly after trusting the
  worktree config, but `mise run lua:test -- plugin/spec/PluginInfoProvider_spec.lua`
  failed while trying to resolve/install missing Lua, Node, Bun, and Selene
  tools because network access and the user mise install directory were denied.
- Added the second red TDD slice at the MCP `tools/list` boundary: every tool
  must expose `concurrency` and `retry_policy` metadata, with
  `get_selected_photos` requiring exclusive backend ownership and active
  selection. `npm.cmd test -- --runInBand tests/list-tools-handler.test.ts`
  failed as expected: 55 tests passed and the new semantics test failed because
  current tool definitions have no metadata.
- Added a typed operation-semantics contract to every existing tool and expose
  it through the MCP tool `_meta` extension. The public payload includes side
  effect, idempotency, reversibility, scope, selection/foreground requirements,
  concurrency, retry policy, and resume safety. Selection reads are marked
  `exclusive_backend` with active-selection/readback constraints; mutating
  Lightroom operations default to exclusive/manual-review semantics.
- Verification `npm.cmd test -- --runInBand tests/list-tools-handler.test.ts`
  passed: 1 suite and 56 tests.
- Reconciled the public operation-semantics payload with PhotoAgent's canonical
  `OperationSemanticsSchema`: added `supported`, used boolean `safe_to_resume`,
  and canonicalized reversibility/scope values. Retained the roadmap's
  Lightroom-specific active-selection and foreground hints as additive fields.
- Verification `npm.cmd test -- --runInBand tests/list-tools-handler.test.ts`
  passed after the contract alignment: 1 suite and 56 tests.
- Verification used the prepared fallback Lua spec runner (not official
  Busted): `lua-spec-runner.lua plugin/spec/PluginInfoProvider_spec.lua`
  passed 20 specs, including both serialized dispatch and response-finalization
  cases. No real Lightroom mutation or live evidence was used.
- Verification `npm.cmd run check` from `server`: passed TypeScript source and
  test-config checks.
- Verification `npm.cmd run lint` from `server`: passed ESLint for `src` and
  `tests`.
- Verification `npm.cmd run build` from `server`: passed TypeScript build.
- Verification `npm.cmd test -- --runInBand` from `server`: passed 13 suites and
  161 tests.
- Verification with Lua 5.4.6 `luac -p` for `PluginInfoProvider.lua` and its
  spec, followed by Selene 0.31.0 on `plugin/LightroomMCP.lrplugin`: passed;
  Selene reported 0 errors, 0 warnings, and 0 parse errors.
- Review checkpoint: inspected the complete `git diff HEAD` against the T02
  acceptance criteria and local AGENTS/CLAUDE conventions. Queue ownership,
  handler/response error finalization, dispatch parity, and public concurrency
  plus retry metadata are covered. No standards violation was found. The
  repository has no `docs/agents/issue-tracker.md`, and live GitHub issue data
  remains unverified because the environment denied the GitHub socket.
- Added a handler-exception queue test so a failed Lightroom handler also
  finalizes in-flight state and allows the following request to run.
- Verification fallback Lua runner passed 21 specs, including handler-error
  and response-send-error continuation cases. `luac -p` for the plugin/spec,
  Selene 0.31.0, and `git diff --check` all passed (only normal CRLF
  normalization warnings were emitted by Git).
- Final pre-commit `git diff --check`, `git status --short --branch`, and
  `git diff --stat` passed; only the six intended T02 files are modified on
  `codex/roadmap-t02`.
- Next command is the scoped commit `git add` for those six files followed by
  `git commit -m "feat(plugin): serialize requests and publish semantics (#3)"`.
- Commit attempt failed before staging: `git add -- <six T02 files>; git commit
  -m "feat(plugin): serialize requests and publish semantics (#3)"` could not
  create the linked worktree index lock at
  `D:/photo/lightroom-mcp-john/.git/worktrees/lightroom-mcp-t02/index.lock`
  (`Permission denied`). No commit was created; inspect the lock/ACL/process
  state before retrying and do not remove another worktree's lock blindly.
- Retried the exact scoped add/commit with the approved elevated Git operation;
  commit succeeded as `6fa0b7d` (`feat(plugin): serialize requests and publish
  semantics (#3)`). Git emitted only normal LF-to-CRLF normalization warnings.
- The following amend records this successful commit result in the append-only
  work log itself: `git add -- WORKLOG.md; git commit --amend --no-edit`.
- Post-amend `git status --short --branch`, `git log -1 --oneline --decorate`,
  and `git diff --check --cached` passed: branch `codex/roadmap-t02` was clean,
  HEAD was `c7dbca2`, and the index had no whitespace errors. The final amend
  below only records this verification in the work log.
