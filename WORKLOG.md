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
- Review follow-up started from `c8714a0` without rewriting or resetting it.
  The new scope addresses queue generation ownership across stop/reload/start,
  stale-worker response suppression, MCP metadata-key grammar, truthful
  `get_selected_photos` selection semantics, and bidirectional contract/map
  equality.
- Verification fallback Lua runner after the lifecycle fixes passed 23 specs,
  including Stop->Start and reset/reload mid-flight generation cases.
- Verification `npm.cmd test -- --runInBand tests/list-tools-handler.test.ts`
  passed 1 suite and 58 tests after metadata-key and bidirectional-map tests.
- Corrected legacy `_G.LightroomMCP_State` backfill so an existing live server
  from before the generation flag was introduced remains queue-accepting after
  InfoProvider re-evaluation instead of silently dropping authenticated calls.
- Review follow-up verification with the prepared fallback Lua runner passed 25
  specs, including Stop->Start, reset/reload mid-flight, worker-start failure,
  and server-task-start failure recovery cases.
- Review-required fixes implemented: queue generations now capture their own
  request table and retain old-worker ownership through stop/reload/start;
  stale responses are suppressed, pending old requests are cleared, and worker,
  server-task, stop, reset, and context-cleanup error paths release ownership
  safely. Added observable lifecycle/error tests.
- Changed the MCP semantics key to
  `io.github.john-owo.lightroom-mcp/operation-semantics`, added one-slash
  reverse-DNS grammar coverage and bidirectional definition/map key equality,
  and corrected `get_selected_photos.requires_active_selection` to false
  because it falls back to filmstrip selection.
- Review follow-up verification `npm.cmd test -- --runInBand
  tests/list-tools-handler.test.ts`: passed 1 suite and 58 tests.
- Review follow-up verification `npm.cmd run check` from `server`: passed.
- Review follow-up verification `npm.cmd run lint` from `server`: passed.
- Review follow-up verification `npm.cmd run build` from `server`: passed.
- Review follow-up verification `npm.cmd test -- --runInBand` from `server`:
  passed 13 suites and 163 tests.
- Review follow-up verification using the prepared fallback Lua runner:
  passed 25 specs. Lua 5.4.6 `luac -p` passed for plugin/spec, Selene passed
  with 0 errors/0 warnings/0 parse errors, and `git diff --check` passed with
  only normal CRLF normalization warnings.
- Review follow-up note: prior final-amend commit `c7dbca2` was superseded by
  `c8714a0`; this follow-up remains an additive, unre-written correction on the
  same `codex/roadmap-t02` branch and is not yet committed.
- Final pre-commit `git diff --check`, `git status --short --branch`, and
  `git diff --stat HEAD` passed; only the five intended follow-up files are
  modified on `codex/roadmap-t02`.
- Next command is the additive commit `git add -- <five follow-up files>` and
  `git commit -m "fix: close T02 review findings (#3)"`.

## T02 worker/server lifecycle re-review (2026-08-27)

- Status correction: the historical note saying `c7dbca2` was the final
  amend and that the next command was a commit is superseded by `c8714a0`,
  then by `28e5b46`; no prior commit is being rewritten.
- Re-review work started additively for explicit queue-worker context cleanup,
  instance-scoped server loops/sockets/callbacks, and rejection of requests
  during an old-generation ownership handoff. No live Lightroom mutation is
  used.
- Baseline verification (before this red step) with the prepared Lua 5.4.6
  fallback runner, not official Busted, passed 25 specs. This confirms the
  existing `28e5b46` behavior before adding the new review tests.
- TDD red verification: after adding the worker-context cancellation test and
  switching the implementation seam to `postAsyncTaskWithContext`, the new
  test reached the expected lifecycle behavior, while the old worker-start
  failure test failed because it still injected `LrTasks.startAsyncTask`.
  This is an expected test-fixture update, not a production failure.
- Verification command typo (failed before process creation): the fallback
  Lua runner path used `_workspace` instead of `_agent_workspace`; no test
  result was inferred from that failure.
- TDD red verification after adding the retained async server-loop test
  initially exposed the mock socket closure's self-reference bug (the test
  reached Stop but the stub socket did not mark itself closed). The fixture
  was corrected to initialize the socket local before its methods.
- Verification with the corrected fixture: the fallback Lua runner passed 27
  specs, including worker cleanup cancellation, rapid Stop->Start instance
  retirement, stale callback rejection, and post-restart request gating.
- Reviewed the production diff and `PluginInit.lua` lifecycle wiring. A
  narrow `rg` wildcard probe was invalid on PowerShell (OS error 123); no
  source change or test claim was based on that failed probe.
- Verification after the acceptance-gate assertion and coroutine fixture
  hardening: the fallback Lua runner (not official Busted) passed 27 specs.
- Verification with Lua 5.4.6 `luac -p` passed for the modified
  `PluginInfoProvider.lua` and `PluginInfoProvider_spec.lua`.
- Verification after hardening local-socket usage, stale restart scheduling,
  and cancellation exception paths: the fallback Lua runner (not official
  Busted) passed 27 specs.
- Updated socket teardown to close each handle once across Stop and delayed
  stale-context cleanup, and added close-count assertions to the retained
  async-loop test. The fallback Lua runner then passed 27 specs.
- Added stale-instance guards before the server task mutates shared rebind
  state and before a delayed response rebind; the fallback Lua runner passed
  27 specs with server cleanup idempotence assertions.
- A targeted Lua verification retry used an incorrect `LUA_PATH` that pointed
  at `lua-spec-runner.lua` instead of the prepared Lua rocks paths and failed
  with a C stack overflow while resolving `luassert`; this result is
  discarded and not counted as a test run.
- Corrected targeted Lua verification with the prepared Lua rocks `LUA_PATH`:
  fallback runner passed all 27 `PluginInfoProvider_spec.lua` specs.
- Final Selene 0.31.0 verification after the stale-start and teardown guards:
  `plugin/LightroomMCP.lrplugin` passed with 0 errors, 0 warnings, and 0 parse
  errors.
- Final Lua 5.4.6 `luac -p` verification passed for all plugin and plugin-spec
  Lua files.
- Final full Lua fallback verification with the prepared runner (not official
  Busted) passed 133 specs across all plugin handler, lookup, JSON, lifecycle,
  and PluginInit suites.
- Final pre-commit `git diff --check`, `git status --short --branch`, and
  `git diff --stat HEAD` passed. Only `WORKLOG.md`,
  `PluginInfoProvider.lua`, and `PluginInfoProvider_spec.lua` are modified on
  `codex/roadmap-t02`; Git emitted only expected LF/CRLF normalization
  warnings.
- Additive fix commit completed as `ab8e87f` (`fix: harden T02 worker
  lifecycle (#3)`). This records the post-review implementation and does not
  rewrite `c8714a0` or `28e5b46`.
- Post-commit verification before this final log append: `git status
  --short --branch`, `git log -3 --oneline --decorate`, and `git diff --check`
  passed on a clean `codex/roadmap-t02` branch at `b930f69`, with
  `ab8e87f` immediately below it and `28e5b46` preserved.
- Verification `git diff --check` passed; Git emitted only expected LF/CRLF
  normalization warnings for the three edited text files.
- Full server verification: `npm.cmd test -- --runInBand` passed 13 suites and
  163 tests.
- Final server verification: `npm.cmd run check` passed source and test
  TypeScript checks.
- Final server verification: `npm.cmd run lint` passed ESLint for `src` and
  `tests`.
- Final server verification: `npm.cmd run build` passed TypeScript build.
- Enumerated the focused Lua spec files under `plugin/spec` with `rg --files`
  to prepare a fallback full-plugin run; no generated or source files were
  touched by the inventory command.
- Full Lua fallback verification using Lua 5.4.6 and the prepared runner (not
  official Busted) passed 133 specs across handler, lookup, JSON, lifecycle,
  and PluginInit spec files.
- Lua static verification with Selene 0.31.0 on `plugin/LightroomMCP.lrplugin`
  passed with 0 errors, 0 warnings, and 0 parse errors.
- Lua 5.4.6 `luac -p` passed for all `.lua` files in `plugin/LightroomMCP.lrplugin`
  and `plugin/spec`.
- Verification from `server`: `npm.cmd test -- --runInBand
  tests/list-tools-handler.test.ts` passed 1 suite and 58 tests.
- Verification from `server`: `npm.cmd run check` passed TypeScript source and
  test-config checks.
- Verification from `server`: `npm.cmd run lint` passed ESLint for `src` and
  `tests`.
