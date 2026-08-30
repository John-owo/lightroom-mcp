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

## 2026-08-27 - T01/T02 integration verification

- Cherry-picked the reviewed T01 and T02 commit chains into
  `codex/roadmap-integration`. The first commit from each chain conflicted in
  this append-only work log; both histories were retained. T02 also conflicted
  with T01 in the tool contract/list-tools files. The manual merge preserves
  both T01 `outputSchema` publication and T02 operation-semantics `_meta` for
  each tool; no feature was selected over the other.
- Integration `npm.cmd test -- --runInBand` passed 14 suites and 167 tests,
  including the identity socket/Dispatcher/MCP round trip and tool-semantics
  contract coverage. `npm.cmd run check`, `npm.cmd run lint`, and
  `npm.cmd run build` all passed.
- A first all-files fallback Lua run loaded all specs into one custom runner
  process and reported 135 passed / 3 failed in `JSON_spec.lua`. Inspection and
  an isolated rerun showed the failures came from cross-file
  `package.loaded.JSON` mock contamination in this non-official runner, not a
  JSON implementation failure. This failed command is retained as evidence and
  is not counted as a passing suite.
- Re-ran all 12 Lua spec files in separate Lua 5.4.6 processes with the prepared
  fallback runner: 138 tests passed and 0 failed. This avoids cross-file module
  cache contamination and includes 27/27 serialized queue/server lifecycle
  tests plus T01 identity/lookup/handler coverage. Official mise/Busted remains
  unavailable in this environment.
- Lua 5.4.6 `luac -p` passed for all 30 Lua files under the plugin source and
  spec directories. Selene 0.31.0 passed the plugin source with 0 errors,
  0 warnings, and 0 parse errors. `git diff --check` is the remaining
  post-worklog/commit check.
- No real Lightroom catalog, SDK cancellation, socket lifecycle, photo
  mutation, UI/visual verification, GitHub write, push, issue closure, or PR
  creation is claimed by this integration verification.
- Integration post-commit verification `git diff --check 46d3543...HEAD` and
  `git status --short --branch` passed at `2381d93`; the worktree was clean.
  This supersedes the earlier sentence that described `git diff --check` as a
  remaining check.
- Final Standards review found that `ToolContractDefinition` duplicated the
  public `ToolContract` fields, which made T01 `outputSchema` and T02
  `operationSemantics` a future synchronization hazard. Replaced the duplicate
  declaration with `Omit<ToolContract, "operationSemantics">`; no runtime
  contract or behavior was changed.
- Post-refactor targeted verification passed: identity integration plus
  list-tools contract tests ran 2 suites / 61 tests, and `npm.cmd run check`
  passed both source and test TypeScript configurations.
- Final integration Spec review passed with 0 actionable findings after
  independently running the identity/contract suites (61/61), focused queue
  lifecycle Lua specs (27/27), and full server suite (167/167). Final Standards
  re-review also passed with 0 findings after commit `498575a`; TypeScript
  checks and `git diff --check 46d3543...HEAD` passed and the worktree was
  clean.
- With T01 and T02 locally integrated and reviewed, live issue #4 (`T03`) is
  the next dependency-frontier item. Created local branch/worktree
  `codex/roadmap-t03` from `498575a` for isolated implementation. No GitHub
  issue state or remote branch was changed.

## 2026-08-27 - T03 Virtual Copy creation implementation

- Re-read this worktree's `AGENTS.md`, `CLAUDE.md`, `WORKLOG.md`, and the
  accepted PhotoAgent ADR `0006-use-identity-safe-serialized-virtual-copy-creation.md`
  before inspecting implementation files. Branch `codex/roadmap-t03` starts
  clean at base `498575a`, which already contains reviewed T01 identity and
  T02 serialized queue changes.
- Escalated read-only `gh issue view 4 --repo John-owo/lightroom-mcp --json
  number,title,body,state,labels,assignees,parent,subIssues,blockedBy,blocking,url`
  confirmed `[T03] Create and reconcile an identity-verified Workflow Copy`,
  ready-for-agent, blocked by open #2 and #3, and blocking PhotoAgent #11 plus
  lightroom-mcp #5. Live acceptance requires source ID/UUID/operation ID,
  Master-only source, verified Copy/Master identities and selection restore,
  separate collection placement with retained partial failure, and same-op
  timeout reconciliation without blind duplicate creation.
- Inspected the T03 base seams (`tool-contracts.ts`, `list-tools-handler.test.ts`,
  `PluginInfoProvider.lua`, `spec_helper.lua`, and existing plugin/server tests).
  The branch currently has 18 public tools, no Virtual Copy dispatch entry, and
  the fake catalog has no selected-photo/active-source mutation API; these are
  the scoped seams needed for the TDD implementation.
- TDD red: added the single public `create_virtual_copy` contract assertion and
  ran `npm.cmd test -- --runInBand tests/list-tools-handler.test.ts` from
  `server`; it failed as expected because the tool is not yet defined (60
  existing tests passed, 1 new test failed).
- Added the TypeScript `create_virtual_copy` input/output contract and its
  conservative operation semantics, then expanded list-tools expectations to
  19 tools. The same targeted Jest command reached 61 passing tests but failed
  the existing Lua dispatch-parity assertion because the plugin dispatch entry
  is intentionally not added yet.
- Verified the Lightroom SDK catalog boundary against the published API
  reference: `getActiveSources`/`setActiveSources` preserve the viewed sources,
  `getTargetPhoto` is the active photo, `getTargetPhotos` is the selected/target
  set, `setSelectedPhotos(activePhoto, otherSelectedPhotos)` takes the Master
  as its first argument, and `createVirtualCopies(copyName)` operates on the
  current selection and selects returned copies. No live Lightroom mutation
  was performed.
- Added `HandlerVirtualCopy.lua`, the plugin dispatch entry, realistic fake
  selected-photo/active-source APIs and `HandlerVirtualCopy_spec.lua`. The
  prepared fallback Lua runner passed all 9 initial T03 behavior specs. This
  is a mock-only result; no real Lightroom mutation was attempted.
- Verification command typo (failed before the runner started): the fallback
  Lua command used `D:\photo\_workspace\runtime\lua-spec-runner.lua` instead
  of the prepared `D:\photo\_agent_workspace\runtime\lua-spec-runner.lua`.
- Hardened the handler after review: direct SDK `createVirtualCopies` call
  without an unrequired write gate, exact marker equality, catalog-wide marker
  evidence, retained returned-photo arrays, set-based selection readback,
  yield-safe `LrTasks.pcall`, malformed status fail-closed behavior, and no
  active-photo mutation refusal. Expanded behavior coverage accordingly; the
  fallback Lua runner passed 14 T03 specs. No live Lightroom mutation was
  performed.
- Targeted server contract verification: `npm.cmd test -- --runInBand
  tests/list-tools-handler.test.ts` passed 1 suite / 62 tests, including the
  new strict input/output and operation-semantics contract.
- Re-ran the T03 fallback Lua handler spec after the SDK/review hardening;
  `lua-spec-runner.lua plugin\\spec\\HandlerVirtualCopy_spec.lua` passed 14/14.
  This remains mock-only evidence and does not verify Lightroom runtime
  behavior.
- Added a real `Dispatcher` + `PluginSocket` + `FakePlugin` + MCP
  `InMemoryTransport` integration harness. `npm.cmd test -- --runInBand
  tests/virtual-copy-integration.test.ts` passed 1 suite / 1 test, including
  Chinese Master/Virtual Copy identity transport, strict structured output,
  and rejection of a malformed output type. This is transport integration
  only; it does not prove live Lightroom behavior.
- The fallback Lua runner passed the complete `PluginInfoProvider_spec.lua`
  dispatch/lifecycle suite (27/27), including loading the new
  `HandlerVirtualCopy` dispatch module. No real socket/plugin runtime was used.
- A targeted regression check initially failed: `npm.cmd test -- --runInBand
  tests/identity-integration.test.ts` rejected T01 Virtual Copy references
  because the newly strict shared identity schema omitted the legacy numeric
  `id` compatibility field. Added that explicitly as a typed number/string
  property; the same integration test then passed 1/1, preserving the existing
  identity contract while keeping extra relationship fields rejected.
- Incorporated review hardening: the plugin now uses the SDK-documented
  `setSelectedPhotos(activePhoto, otherSelectedPhotos)` shape and refuses a
  missing restorable active photo before UI/mutation work; identity status is
  accepted only when the SDK returns a Boolean; exact marker evidence is
  catalog-wide and catches malformed/non-Master entries; returned arrays are
  retained as evidence even when their count is unexpected; selection sets are
  compared order-independently. SDK-wrapping error paths use `LrTasks.pcall`.
- Updated `README.md` and `README.en.md` for the 19-tool surface and
  `create_virtual_copy` safety boundary. Both documents explicitly distinguish
  automated contract/mock/transport coverage from the still-pending live
  Lightroom Classic acceptance; no live evidence is claimed.
- Targeted server regression command `npm.cmd test -- --runInBand
  tests/list-tools-handler.test.ts tests/identity-integration.test.ts
  tests/virtual-copy-integration.test.ts tests/server.test.ts` passed 4 suites
  / 77 tests.
- Server TypeScript check `npm.cmd run check` passed both source and test
  configurations.
- Server lint `npm.cmd run lint` passed with no ESLint diagnostics.
- Server production build `npm.cmd run build` passed.
- Full server suite `npm.cmd test -- --runInBand` passed 15 suites / 170 tests.
- Ran each of the 13 Lua spec files individually through the prepared
  non-official `lua-spec-runner.lua` fallback; all files passed (total reported
  behavior tests: 148). This validates mocks/specs only, not Lightroom.
- Correction to the immediately preceding summary: summing the runner output
  gives 152 passing Lua behavior tests (not 148); all 13 files still passed.
- `luac.exe -p` parsed all five modified Lua/plugin spec files successfully:
  `HandlerVirtualCopy.lua`, `PluginInfoProvider.lua`, `spec_helper.lua`,
  `HandlerVirtualCopy_spec.lua`, and `PluginInfoProvider_spec.lua`.
- Selene source lint passed for the changed production modules and then the
  complete `plugin/LightroomMCP.lrplugin` directory: both runs reported 0
  errors, 0 warnings, and 0 parse errors (JSON.lua remains configured out).
- Extended the contract test to assert the success/review output branches and
  all T03 safety semantics; targeted `npm.cmd test -- --runInBand
  tests/list-tools-handler.test.ts` passed 1 suite / 63 tests.
- Re-ran both MCP transport identity integrations after tightening the shared
  identity schema: `npm.cmd test -- --runInBand
  tests/virtual-copy-integration.test.ts tests/identity-integration.test.ts`
  passed 2 suites / 2 tests.
- Corrected the Traditional Chinese README wording to say the operation ID is
  reusable (not "recomposable") and added an explicit 19-tool note to the
  English README; live Lightroom acceptance remains clearly pending.
- Final T03 self-review started from the clean base plus only the scoped
  contract, handler, fake-catalog, tests, dispatch, and README changes shown
  by `git status`; no unrelated worktree changes were present.
- Final targeted server regression: `npm.cmd test -- --runInBand
  tests/list-tools-handler.test.ts tests/identity-integration.test.ts
  tests/virtual-copy-integration.test.ts tests/server.test.ts` passed 4
  suites / 78 tests.
- Final server type check: `npm.cmd run check` passed source and test
  TypeScript configurations.
- Final server lint: `npm.cmd run lint` passed with no ESLint diagnostics.
- Final server production build: `npm.cmd run build` passed.
- Final full server suite: `npm.cmd test -- --runInBand` passed 15 suites /
  171 tests.
- Final all-Lua fallback invocation initially ran all 13 spec files with zero
  process failures; its wrapper used the wrong summary label and therefore
  printed `TOTAL_TESTS=0` despite each per-file `RESULT` being passing. A
  corrected parser immediately reran the same command and reported
  `FALLBACK_LUA_FILES=13 PASSED=152 FAILED=0`. This is the prepared,
  non-official Lua 5.4.6 runner, not Lightroom.
- Final Lua syntax check: `luac.exe -p` parsed the five changed Lua/plugin
  spec files successfully (`LUAC_PARSED=5`).
- Final Lua source lint: `selene.exe plugin\\LightroomMCP.lrplugin` reported
  0 errors, 0 warnings, and 0 parse errors.
- Final pre-commit whitespace check: `git diff --check` passed. Git reported
  only expected LF-to-CRLF normalization warnings for changed text files; the
  worktree contained only the scoped T03 files listed by `git status`.
- Final standards/spec self-review covered the public contract's strict
  success/review branches, exact marker reconciliation, identity/status
  fail-closed paths, selection snapshot/readback/finally restoration, retained
  partial evidence, dispatch parity, faithful mock side effects, and the
  README live-acceptance disclaimer; no additional in-scope finding remains.
- All T03 checks are complete; the scoped files will now be staged and made
  into one local additive commit on `codex/roadmap-t03`.
- First explicit `git add -- <scoped T03 files>` attempt failed before staging
  because the shared worktree metadata denied creation of
  `D:/photo/lightroom-mcp-john/.git/worktrees/lightroom-mcp-t03/index.lock`.
  No source files were changed by this failed staging attempt; retrying the
  same scoped operation with the required workspace escalation.
- Escalated retry staged only the 12 scoped T03 files. `git diff --cached
  --check` passed, and staged status showed the expected README, WORKLOG,
  server contract/tests, plugin handler/dispatch/spec/helper files only.
- Follow-up T03 P1 review finding: when temporary selection ownership begins
  but readback detects drift before `createVirtualCopies`, the handler still
  raises a generic error after successful restoration. ADR 0006 requires this
  uncertain boundary to return a structured `REVIEW_REQUIRED` result with
  `partial=false`, identity envelope, reason, and restoration status so a
  caller cannot apply a generic retry policy.
- TDD red test: updated the existing selection-drift Lua spec to assert the
  required structured review envelope. The prepared fallback runner failed
  1/14 (`13 passed, 1 failed`) because the handler still raised the generic
  `Selection changed before Virtual Copy creation` error at its old branch.
- Minimal handler fix: both pre-mutation outcomes (restored selection and
  failed restoration) now return `reviewResult(..., partial=false)` with the
  operation marker, source/master identity, reason, and machine-readable
  restoration status. Targeted fallback Lua green: `HandlerVirtualCopy_spec.lua`
  passed 14/14.
- Adding a real `Dispatcher` + `PluginSocket` + MCP in-memory transport
  assertion for the same pre-mutation `REVIEW_REQUIRED` branch, including its
  strict output-schema validation and JSON text/structured-content parity.
- Added the transport regression with a fake plugin returning the precise
  pre-mutation review envelope. `npm.cmd test -- --runInBand
  tests/virtual-copy-integration.test.ts` passed 1 suite / 2 tests, proving
  both created and pre-mutation review branches pass MCP structured-content
  validation and retain matching JSON text.
- Follow-up standards review adds a second P1: `restoreSelection` currently
  calls `samePhoto` outside `withReadAccessDo`, which reads UUID metadata
  outside the repository's Lightroom read gate. The requested regression will
  make the fake reject gate-external metadata reads and require restoration to
  remain verified.
- The review also found stale pre-commit WORKLOG wording after commit `9dd64dd`;
  a later append-only correction will supersede those historical "will now be
  staged/committed" lines with the actual commit/status/diff-check evidence.
- TDD red for the metadata-gate finding: enabled a fake-catalog guard that
  rejects UUID metadata reads outside `withReadAccessDo` on the selection-drift
  regression. The fallback Lua runner failed 1/14 because `restoreSelection`
  still called `samePhoto` outside the gate, and the returned review reported
  `selection_restoration.status=failed`.
- Moved `restoreSelection`'s `samePhoto`/UUID comparison into one read gate;
  the gate-external section now performs only `setSelectedPhotos`. The fake
  metadata guard regression is green: `HandlerVirtualCopy_spec.lua` passed
  14/14, including verified restoration and the structured pre-mutation review.
- Re-ran the MCP transport regression after adding the pre-mutation review
  branch: `npm.cmd test -- --runInBand
  tests/virtual-copy-integration.test.ts` passed 1 suite / 2 tests.
- T03 review-fix server type check: `npm.cmd run check` passed source and
  test TypeScript configurations.
- T03 review-fix server lint: `npm.cmd run lint` passed with no ESLint
  diagnostics.
- T03 review-fix server production build: `npm.cmd run build` passed.
- T03 review-fix full server suite: `npm.cmd test -- --runInBand` passed 15
  suites / 172 tests.
- T03 review-fix fallback Lua sweep: the prepared non-official Lua 5.4.6
  runner executed all 13 spec files and reported `PASSED=152 FAILED=0`.
  This remains mock/spec evidence, not live Lightroom validation.
- T03 review-fix Lua syntax check: `luac.exe -p` parsed all five changed Lua
  and Lua-spec files (`LUAC_PARSED=5`).
- T03 review-fix Lua lint: `selene.exe plugin\\LightroomMCP.lrplugin`
  reported 0 errors, 0 warnings, and 0 parse errors.
- T03 review-fix pre-commit whitespace check: `git diff --check` passed; only
  expected LF-to-CRLF normalization warnings were emitted. Status showed the
  five intentional review-fix files (`WORKLOG.md`, HandlerVirtualCopy,
  HandlerVirtualCopy_spec, spec_helper, and virtual-copy-integration) and no
  unrelated changes.
- Historical WORKLOG correction: the earlier "will now be staged/committed"
  and "staged retry" entries describe the pre-`9dd64dd` implementation
  checkpoint and are superseded by this entry. Commit `9dd64dd` was already
  created and clean before this review-fix began; the five files above are the
  new, intentionally uncommitted P1 review-fix scope.
- First review-fix `git add -- <five scoped files>` attempt again failed before
  staging because shared worktree metadata denied `index.lock` creation;
  retrying the same scoped add with workspace escalation.
- Escalated review-fix add staged exactly the five scoped files. `git diff
  --cached --check` passed and staged status contained no unrelated paths.
- Additive review-fix commit succeeded as `6fcae2d4b9767d05a7141cb4198795d8a647b775`
  (`fix: return structured review on selection drift (#4)`), containing the
  handler gate fix, fake metadata-read guard, Lua assertions, MCP transport
  assertion, and this append-only worklog evidence.
- Post-commit verification for `6fcae2d4b9767d05a7141cb4198795d8a647b775`:
  `git rev-parse HEAD` returned that SHA, `git status --short --branch`
  returned only `## codex/roadmap-t03` (clean), and `git diff --check` passed.
  This supersedes the earlier pending/staged wording; the review-fix commit is
  complete and the post-commit worktree was clean at this checkpoint.
- The append-only final-status correction itself passed `git diff --check`;
  status showed only the intended WORKLOG modification pending its small
  follow-up documentation commit.
- Completion record superseding that pending sentence: T03 review-fix
  implementation and documentation are committed; the worktree was clean at
  the post-commit checkpoint; the post-commit full-range diff check passed; no
  further T03 code or documentation change is pending. Independent review-fix
  rerun evidence: server full `npm.cmd test -- --runInBand` passed 15 suites /
  172 tests; `npm.cmd run check`, `npm.cmd run lint`, and `npm.cmd run build`
  passed; `HandlerVirtualCopy_spec.lua` passed 14/14; and
  `git diff --check 498575a...89cfd96` passed. Lua results remain fallback
  mock/spec evidence and live Lightroom acceptance remains unverified.

## 2026-08-27 - T03 roadmap integration verification

- The first scoped `git cherry-pick 9dd64dd 6fcae2d 89cfd96 7518ce4`
  attempt failed before sequencing because the shared worktree Git metadata
  denied creation of the sequencer directory. The escalated retry reached one
  expected `WORKLOG.md` conflict with the T01/T02 integration closeout.
- Resolved the append-only work-log conflict by retaining both the T01/T02
  integration closeout and the complete T03 implementation/review history.
  The four reviewed T03 commits were integrated as `ac20d9f`, `59eb600`,
  `14aacf2`, and `d5c35fb`; no production-code conflict occurred.
- Post-integration server verification passed: full Jest 15 suites / 172
  tests, TypeScript source/test checks, ESLint, and production build.
- Ran all 13 Lua spec files in separate processes through the prepared
  non-official fallback runner; all 152 reported behavior tests passed.
  `luac -p` parsed all 32 Lua source/spec files, and Selene reported 0
  errors, 0 warnings, and 0 parse errors for the plugin source.
- `git diff --check 46d3543...HEAD` passed. This integration evidence is
  contract/mock/transport/static verification only: no live Lightroom
  mutation, rendered-output inspection, source/sidecar proof, GitHub write,
  push, issue closure, or PR is claimed.

## 2026-08-27 - takeover after referenced orchestrator usage limit

- Re-read the workspace `PHOTO_WORKSPACE.md`, this worktree's `AGENTS.md`,
  `CLAUDE.md`, and `WORKLOG.md` before continuing the roadmap task.
- Read the referenced Codex task `Implement photo-agent roadmap issues`. Its
  latest captured state was interrupted by the account usage limit while T03
  was still described as pending; direct worktree inspection supersedes that
  stale snapshot: T03 is complete on `codex/roadmap-t03` at `7518ce4`, and its
  reviewed commits are integrated into this clean worktree at `285244c`.
- Read-only status checks confirmed `codex/roadmap-integration` is clean and
  contains the T01-T03 integration closeout. No source or photo files were
  changed by this takeover check.
- The first read-only `gh issue view 5 --repo John-owo/lightroom-mcp ...`
  attempt failed because the sandbox denied GitHub socket access. The
  explicitly requested read-only escalated retry was rejected by the same
  account 5-hour usage limit before process creation. No GitHub state changed;
  the exact T04 remote body remains unverified in this continuation.
- Local accepted ADRs and the complete roadmap specification remain the
  authoritative scope available offline. No T04 implementation has started
  until its local contract seams are checked against those documents.

## 2026-08-27 - T04 live-gate preflight and blocked boundary

- GitHub connector readback confirmed issue #5 is `[T04] Live-verify the
  Workflow Copy P0 gate`. Its required evidence is live creation, identity,
  response-loss reconciliation, selection restoration, failure handling, and
  unchanged Master Develop State, source hash/timestamp, and sidecar state.
  It is blocked by lightroom-mcp issue #4 (T03).
- Read-only local preflight found no Lightroom process, both plugin sockets
  (`127.0.0.1:58763` and `:58764`) closed, and no readable token. The token
  path check itself returned Windows `Access to the path ... is denied`; the
  direct probe consequently failed with `EPERM`. No Lightroom or photo state
  was changed.
- The configured checkout `D:\photo\lightroom-mcp-john` remains on the
  boundary-docs branch with pre-existing unrelated lifecycle changes and does
  not contain the T03 `create_virtual_copy` implementation. No plugin was
  installed or replaced, so T04 live acceptance cannot be claimed in this
  environment.
- Because T04 is an evidence-only gate blocked by unavailable Lightroom,
  implementation work moves to the next locally actionable dependency frontier:
  PhotoAgent T06 (`photo-agent#11`), versioned backend handshake before work.

## 2026-08-28 - T01-T03 release gate and dependency refresh

- Re-read the workspace/repository instructions, CLAUDE architecture rules,
  current roadmap, accepted PhotoAgent ADRs, GitHub issue bodies, and native
  parent/dependency graph. GitHub still showed T01-T03 open even though their
  reviewed commits are integrated here; T04 remains the next required live
  gate and blocks PhotoAgent T07 plus later Lightroom capability work.
- `git fetch --prune origin` succeeded. The integration branch is 17 commits
  ahead of `origin/codex/project-boundary-docs`; no remote roadmap branch
  exists. The only pre-verification working-tree change was the prior
  append-only T04 blocker record in this file.
- Fresh server verification passed: `npm.cmd test -- --runInBand` reported 15
  Jest suites / 172 tests; `npm.cmd run check`, `npm.cmd run lint`,
  `npm.cmd run build`, and `git diff --check 46d3543...HEAD` passed.
- Official Lua verification could not start because `mise` is not on PATH in
  this environment. This failure does not replace the previously recorded
  integration evidence from the prepared fallback runner: 13 spec files / 152
  behavior tests, complete Lua syntax parsing, and Selene source lint all
  passed for the same integrated commits.
- No Lightroom process, plug-in installation, catalog operation, Develop
  mutation, render, source/sidecar write, or visual QA is claimed by this gate.

### 2026-08-28 two-axis T01-T03 review and live preflight

- Independent Standards review found no hard repository-rule violation. It
  noted judgement-only identity-helper duplication between the slim mutation
  envelope and rich metadata readback; their different public contracts make
  a shared refactor unnecessary for these tickets.
- Independent Spec review identified one accepted T01 fix: metadata readback
  currently coerces a missing/malformed `isVirtualCopy` SDK value to `false`,
  which could misreport uncertain identity as a Master. T01 closure is held
  until a red/green fail-closed test and minimal implementation are complete.
- The review's T03 collection-placement concern is not a missing backend
  behavior. ADR 0006 requires `create_virtual_copy` to exclude placement;
  existing `add_to_collection` is the separate operation, and PhotoAgent T07
  owns retaining/reporting the Copy if that later operation partially fails.
- Fresh read-only T04 preflight found `LIGHTROOM_PROCESS=absent` and no
  listener or established connection on ports 58763/58764. No live operation
  was attempted; T04 remains blocked on Lightroom/plugin availability after
  the reviewed T01 fix is integrated.

## 2026-08-28 - T01 identity review fix

- TDD red: added a public `HandlerMetadata.getPhotoMetadata` regression for
  missing (`nil`) and malformed (`"false"`) `isVirtualCopy` metadata. The
  prepared non-official Lua 5.4.6 runner failed as expected with 11 passing
  and 1 failing test because the current `PhotoIdentity.identityFields`
  coerced the uncertain value to `is_virtual_copy=false` instead of failing
  closed.
- Minimal implementation: `PhotoIdentity.identityFields` now requires the
  SDK `isVirtualCopy` readback to be a Boolean and raises a fail-closed
  uncertainty error for missing or malformed values; valid Boolean values are
  preserved unchanged. Existing metadata fixtures now state their intended
  Master status explicitly.
- Targeted Lua green: the prepared non-official Lua 5.4.6 runner executed
  `plugin/spec/HandlerMetadata_spec.lua` with 12 passed and 0 failed. This is
  mock/spec evidence, not live Lightroom validation.
- Official Lua verification attempt `mise run lua:test --
  plugin/spec/HandlerMetadata_spec.lua` failed before process creation because
  `mise` is not available on PATH; the prepared fallback runner above is used
  instead. `selene` is likewise unavailable on PATH.
- Lua syntax check with prepared Lua 5.4.6 `luac -p` passed for
  `PhotoIdentity.lua` and `HandlerMetadata_spec.lua`.
- Server full test `npm.cmd test -- --runInBand` passed: 15 suites and 172
  tests.
- Server TypeScript check `npm.cmd run check` passed source and test
  configurations.
- Server lint `npm.cmd run lint` passed with no ESLint diagnostics.
- Server production build `npm.cmd run build` passed.
- Pre-commit `git diff --check` passed; Git emitted only expected LF-to-CRLF
  normalization warnings. Status showed only the three owned files:
  `PhotoIdentity.lua`, `HandlerMetadata_spec.lua`, and `WORKLOG.md`.
- Main-agent staged-diff review found the change minimal and limited to the
  public metadata identity seam. Independent follow-up Standards review passed
  with no hard violation or smell finding; independent Spec review passed with
  no missing requirement, scope creep, or incorrect behavior.
- Post-commit main-agent verification passed: the prepared Lua runner reported
  12/12 targeted metadata behavior tests, `luac -p` parsed both changed Lua
  files, server Jest reported 15 suites / 172 tests, TypeScript check, ESLint,
  production build, range `git diff --check`, and clean status all passed.

## 2026-08-28 - remote publication authorization boundary

- A normal non-force push of `codex/roadmap-integration` was rejected before
  process creation by the external-action reviewer because explicit approval
  to transmit the complete branch payload to GitHub was required. No workaround
  or alternate transport was attempted.
- Read-only GitHub ref verification returned HTTP 404 for the intended branch
  in both repositories, confirming neither integration branch was published.
  Issues #2-#4 remain open and no completion comment was posted.
- T04 remains independently blocked in the current environment by absent
  Lightroom/plugin sockets. The next remote actions require explicit branch
  push authorization; the next live acceptance action requires Lightroom
  Classic plus a non-critical catalog photo.
- Initial scoped `git add` failed before staging because the shared worktree
  metadata denied creation of
  `D:/photo/lightroom-mcp-john/.git/worktrees/lightroom-mcp-roadmap-integration/index.lock`
  (`Permission denied`); no commit was created and no unrelated path was
  touched.

## 2026-08-28 - T04 live retry remains blocked at Lightroom startup

- Re-read the workspace instructions, the PhotoAgent and Lightroom MCP
  integration work logs, the T04 GitHub issue, and the current v0.1 dependency
  frontier before acting. T04 remains the mandatory live boundary before
  PhotoAgent T07; T07 is still natively blocked by T04 and T06.
- Read-only GitHub issue #5 confirmed the exact live evidence contract:
  Workflow Copy creation and identity, response-loss reconciliation, selection
  restoration, failure handling, unchanged Master Develop State, unchanged
  source hash/timestamp and sidecar state, plus a Lightroom-rendered result and
  explicit unverified boundaries.
- Initial preflight again found no Lightroom process and no connections or
  listeners on ports 58763/58764. The first sandboxed GitHub issue read failed
  on denied network socket access; its approved read-only retry succeeded.
- The `computer-use` initialization failed before any UI action with
  `Importing module "node:process" is not allowed in node_repl`. No stale
  screenshot coordinate, accessibility index, or UI input was used.
- The first narrow installed-path probe command had a PowerShell empty-pipe
  parser error and changed nothing. Its corrected rerun found the existing
  executable at `C:\Program Files\Adobe\Adobe Lightroom Classic\Lightroom.exe`.
- Launched that existing Lightroom executable once through the approved GUI
  boundary. Subsequent read-only checks found three responding Lightroom
  processes but zero main windows and zero MCP sockets. Adobe Crash Processor
  was also present. No Lightroom catalog, photo, plug-in, preset, or source file
  was selected or changed.
- Two bounded wait commands returned without usable output, so neither is
  counted as verification. Explicit follow-up readback reported
  `ProcessCount=3`, `WindowCount=0`, and `SocketCount=0`.
- Targeted log inspection found no current launch or plug-in entry. The
  existing `Documents\LrClassicLogs\LightroomMCP.log` ends at 2026-08-26 and
  therefore cannot establish connectivity for this run. The targeted
  `Get-CimInstance Win32_Process` query failed with access denied and changed
  nothing.
- Decision: T04 cannot be honestly executed while Lightroom exposes no usable
  window and the plug-in exposes no sockets. T07 is not started because doing
  so would bypass its explicit P0 dependency. No code, test, catalog, Develop
  State, photo, sidecar, render, GitHub issue, branch, or remote state changed.

### 2026-08-28 post-reboot continuation

- After the user rebooted and asked to continue, read-only preflight reported
  zero Lightroom processes, zero windows, and zero sockets. Both integration
  worktrees retained their prior state: PhotoAgent was clean and this worktree
  had only the preceding append-only WORKLOG entry.
- The MCP log showed that the previous launch had reached plug-in bootstrap at
  22:16:32, then shut down at 22:16:53 without processing any request. This
  supersedes the earlier lack-of-current-log observation but does not establish
  a successful catalog or photo operation.
- Relaunched the existing Lightroom executable once after the reboot. The user
  supplied a screenshot showing Lightroom repairing `Lightroom Catalog-v13-5`;
  no Cancel action or other UI input was sent.
- Repeated bounded read-only monitoring found one responding Lightroom process,
  zero main windows, zero MCP sockets, and no newer plug-in log entry through
  22:23:15. Two wait commands yielded before their final output; explicit
  session polling completed them and confirmed the same state.
- T04 remains paused until Lightroom finishes catalog repair and exposes a
  usable main window and plug-in sockets. No code, catalog command, photo
  selection, Workflow Copy, Develop mutation, render, sidecar write, GitHub
  write, staging, or commit occurred in this continuation.

## 2026-08-28 - Lightroom catalog-repair incident isolation

- Stopped roadmap implementation and used the systematic debugging workflow
  after the user reported that the repair dialog made no progress and suspected
  an agent-caused Lightroom change. No feature work continued during triage.
- Targeted preference-file inspection failed with Windows access denied and
  changed nothing. A narrow search of the known catalog roots located the
  active catalog at
  `C:\Users\John\Pictures\Lightroom\Lightroom Catalog-v13-5.lrcat`; no
  catalog was found under the shallow `E:\Lr` root inspection.
- Artifact readback found the main `.lrcat` at 7,258,112 bytes with last write
  22:16:54, no `.lock`, WAL, SHM, repair, or temporary artifact beside it, and
  a Lightroom-created 22:16 backup ZIP. The 22:16, 8/25, and 8/24 backup ZIPs
  were inspected read-only; they contain both `.lrcat` and `.lrcat-data`.
- Python SQLite read-only immutable-mode `PRAGMA quick_check` and full
  `PRAGMA integrity_check` both returned `ok` for the original catalog before
  any process termination. This checks the SQLite catalog, not Adobe's separate
  `.lrcat-data` store.
- Process sampling showed the original repair process nearly idle: CPU advanced
  only about 0.02 seconds over ten seconds, the catalog timestamp did not move,
  and no plug-in socket or new MCP log entry appeared. Windows Application log
  inspection returned no matching Lightroom hang/error event.
- Escalated read-only `Win32_Process` inspection identified two independent
  Lightroom launches: PID 18420 from the agent's approved `Start-Process` call
  at 22:19 and PID 6336 from Explorer at 22:29. The non-escalated process-parent
  query and `tasklist /v` attempts had failed with access denied and changed
  nothing.
- Ended only the later, idle PID 6336 first. Source catalog hash, size, and
  timestamp remained unchanged; PID 18420 did not recover. After the original
  catalog remained unwritten and idle for more than 20 minutes, created a
  non-overwriting safety snapshot at
  `D:\photo\_agent_workspace\lightroom\catalog-recovery\20260828-2240-pre-stuck-restart`
  and then ended PID 18420.
- Safety snapshot verification passed: source and copy `.lrcat` SHA-256 are
  `234D17440CCD1ED8726EC62E5FB42E280C4F796C58A3565454B5A25713F7E645`,
  both are 7,258,112 bytes, and the `.lrcat-data` trees match by relative path,
  size, file count, and aggregate bytes. The snapshot also preserves the MCP
  log. A Luna worker independently repeated this read-only verification.
- After PID 18420 termination, the original catalog hash, size, and timestamp
  were unchanged; read-only quick/full SQLite integrity checks remained `ok`
  and there were no residual lock/WAL/SHM/repair files.
- Relaunching the original catalog by explicit full path reproduced the same
  no-main-window/no-socket state. PID 2756 was ended only after its catalog
  hash/size/timestamp remained unchanged; the same values remained unchanged
  after termination.
- Extracted the Lightroom-created 22:16 backup into the new isolated test path
  `D:\photo\_agent_workspace\lightroom\catalog-recovery\20260828-2216-backup-open-test`.
  The extracted `.lrcat` is 7,319,552 bytes, SHA-256
  `4B3C1F6F0D1126B9994155383CFBA012F8CF334F32CA48BE451F7DA0A421856A`,
  and passed read-only quick/full SQLite integrity checks.
- Opening only that backup copy produced substantial initialization work in
  the isolated directory: Lightroom created its lock/WAL/SHM, Helper, Previews,
  and Sync artifacts and used up to about 5.7 GB private memory. It later
  became low-activity without a usable plug-in socket. Two test-only Lightroom
  processes were ended after bounded observation; each termination left the
  original catalog hash, size, and timestamp unchanged. The generated backup
  test copy and its artifacts were retained for evidence; nothing was deleted.
- Adobe's current official troubleshooting guidance was checked. It recommends
  an Alt-launch catalog picker and a brand-new empty catalog to distinguish a
  catalog problem from an application/startup problem, followed by backup
  restore or application/GPU troubleshooting based on that result. The next
  required step is the user-visible Alt-launch empty-catalog test because the
  available Computer Use runtime fails before input with the recorded
  `node:process` restriction.
- Current boundary: zero Lightroom processes remain; the original catalog and
  photos were not overwritten, replaced, moved, renamed, or deleted. T04 and
  PhotoAgent T07 remain paused until Lightroom can open a catalog normally.
- Created the empty, non-catalog destination
  `D:\photo\_agent_workspace\lightroom\catalog-recovery\blank-startup-test`
  for the user-visible Alt-launch `Create a New Catalog` isolation step. The
  directory contained zero items at creation; no catalog was created
  automatically.

## 2026-08-29 - live MCP recovery and T04 version-boundary check

- The user supplied a current Lightroom MCP status screenshot reporting
  `Running: true`, both sockets connected, request port 58763, response port
  58764, and no startup error. A live read-only `get_selected_photos` call then
  succeeded, establishing usable MCP connectivity in this Codex task.
- The selected catalog item is `D:\star\1\star_去星背景_缩星.tif` (photo id
  `1010116`). It has not been designated as the non-critical T04 test photo, so
  no metadata capture, Workflow Copy creation, Develop mutation, render, or
  catalog write was attempted.
- Windows `Get-NetTCPConnection` returned no matching connection even though the
  MCP read succeeded. The screenshot log path
  `E:\Users\John\Documents\LrClassicLogs\LightroomMCP.log` was not present at
  that exact path, so neither check is counted against the direct MCP proof.
- Runtime tool inspection found no `create_virtual_copy` operation. Targeted
  source comparison confirmed the operation exists in this integration
  worktree's `server/src/tool-contracts.ts` and plugin dispatch, but not in the
  configured `D:\photo\lightroom-mcp-john` checkout. The configured active
  backend is therefore an older contract and cannot execute T04.
- A narrow default Plug-ins/Modules path check found no copied plug-in bundle;
  no broad filesystem scan followed. No plug-in, server config, catalog, photo,
  source, sidecar, preview, branch, issue, or remote state changed.
- `git diff --check` passed after this record with only the normal LF-to-CRLF
  warning; status showed only this intended append-only `WORKLOG.md` change.

## 2026-08-29 - authorized integration backend switch prepared

- The user designated `DSC_5343.NEF` as the non-critical T04 target and
  authorized switching to this integration build. Live search found exactly one
  catalog match at `E:\Lr\2026\2026-07-25\DSC_5343.NEF` (id `976310`).
  Read-only metadata/develop capture succeeded; no identity-safe mutation was
  attempted through the old contract.
- A delegated narrow inventory confirmed this branch is `codex/roadmap-integration`
  at `d56bc26`; integration `node_modules`, dist, `HandlerVirtualCopy.lua`,
  `PhotoIdentity.lua`, `create_virtual_copy` contract, and plugin dispatch are
  present. The dirty configured checkout was preserved without merge, reset,
  copy, or overwrite.
- Official Codex config reference confirms trusted project overrides and stdio
  MCP `command`/`args`. Parsed user/project configs both pointed to the old dist;
  project scope correctly owned `default_permissions="photo-lightroom"` and
  the matching permission profile.
- The first PowerShell backup command failed at parse time on an empty pipeline
  and changed nothing. The corrected command created non-overwriting backups
  `C:\Users\John\.codex\config.toml.backup-20260829-014936-297` and
  `D:\photo\.codex\config.toml.backup-20260829-014936-297`; source/backup size
  and SHA-256 matched for both.
- The first project-config patch temporarily appended a second `args` key. It
  was detected before any restart/process use and immediately corrected by
  deleting the old key. Real TOML parsing then passed for both configs and an
  exact line diff showed only the intended project Lightroom path replacement;
  the user config hash remained unchanged and permission scope did not drift.
- Fresh automated verification on this integration server passed: `npm.cmd test
  -- --runInBand` reported 15 suites / 172 tests; `npm.cmd run check`,
  `npm.cmd run lint`, and `npm.cmd run build` completed with exit code 0.
- Recent Codex SQLite log inspection found no current fatal permission/config
  precedence error. Several exploratory log queries failed before useful output
  because of PowerShell/Python quoting or console encoding; corrected read-only
  queries succeeded and changed no config or project file.
- Final `git diff --check` passed with only the normal LF-to-CRLF warning;
  status showed only the pre-existing/current append-only `WORKLOG.md` change.
  The required remaining boundary is manual Plug-in Manager load/reload/start of
  this worktree's `plugin\LightroomMCP.lrplugin`, followed by a full Codex
  restart. No catalog mutation, Workflow Copy, render, source/sidecar change,
  plugin installation, GitHub write, push, or issue closure occurred.

## 2026-08-29 - integration plug-in start-stop race diagnosed

- The user manually loaded the integration plug-in and supplied its current
  Plug-in Manager panel. The panel rendered at 22:53:07 with stale initial
  `Running: false` / zero-attempt state while auto-start remained enabled.
- Current `LightroomMCP.log` proves the integration plug-in then started
  normally at 22:53:08: token write, both 58763/58764 binds, bootstrap ready,
  and both MCP sockets connected all succeeded without startup error.
- At 22:53:16 the log records the explicit normal lifecycle message
  `Stopping LrSocket servers`, followed by clean socket closure and task
  cleanup. No exception, bind failure, stale restart, or catalog operation
  preceded it.
- Targeted source readback explains the apparent contradiction: the status text
  and Start/Stop button title are fixed when the panel renders, but the button
  action branches on live `pluginState.running`. Clicking the still-labelled
  Start button after auto-start completed therefore invoked `stopServer()`.
- Current verification found Lightroom still running, no listeners on
  58763/58764, no live Lightroom MCP tools in this Codex task, and both
  integration worktrees otherwise clean before this log append. No photo,
  catalog, sidecar, preview, configuration, source, issue, or remote state was
  changed by the diagnosis.
- Verification commands: targeted `rg` plus source/log readback completed and
  found the exact start/stop branches; the combined command returned exit 1
  only because its final listener filter produced no row. The earlier combined
  process/port/log/status command completed with exit 0.

## 2026-08-29 - Codex tool-registration startup race isolated

- The user restarted/continued after manually starting the integration bridge.
  Current plug-in evidence shows a successful start at 23:03:34, both sockets
  connected by 23:03:36, and no later explicit Stop or plug-in exception.
- This Codex thread began before that successful plug-in start. Codex's stdio
  server connected only near the configured 60-second startup boundary; its
  first heartbeat then exceeded the 10-second dispatcher wait and logged
  `Plugin response timeout`, followed by a late `Response for unknown id`.
- Runtime tool enumeration and a direct read-only lookup both confirmed
  `mcp__lightroom__search_photos` / `create_virtual_copy` are not callable in
  this already-initialized model turn. No raw-TCP or guessed-schema mutation was
  attempted as a workaround.
- `PluginInfoProvider loaded` at 23:03:50 establishes that Plug-in Manager was
  opened while the bridge was connected. The first heartbeat timeout followed;
  the clean retry condition is therefore to close this modal panel completely,
  keep Lightroom on its normal catalog UI with the bridge already running, and
  then restart Codex so tool discovery begins against a ready plug-in.
- The first combined skill/config/SQLite command failed at PowerShell parse time
  and changed nothing. Corrected separate read-only commands passed; project
  config still points exactly to the integration dist with a 60-second startup
  timeout. No photo, catalog, sidecar, preview, config, source, issue, or remote
  state changed.
- Final `git diff --check` passed with only the normal LF-to-CRLF warning;
  status showed only this append-only `WORKLOG.md` update.

## 2026-08-29 - new Lightroom process lacks the integration plug-in

- After the next clean Codex reload, runtime enumeration succeeded and exposed
  the complete integration contract, including `create_virtual_copy`, stable
  UUID identity, Master/Virtual Copy relations, and path-rejecting photo IDs.
- The first live read-only `search_photos(filename="5343")` call failed with
  `Lightroom plugin not connected`; no catalog operation or mutation occurred.
- Lightroom process evidence shows a new application instance started at
  23:30:58, while `LightroomMCP.log` contains no `PluginInit`, bind, or socket
  event after the prior 23:03 session. Codex heartbeat logs likewise report a
  dropped request socket. The new Lightroom process therefore has not loaded
  and started the integration plug-in.
- Codex tool discovery is now complete and must not be restarted again. The
  remaining manual boundary is to load/reload the integration bundle in this
  Lightroom process, click Start exactly once, close Plug-in Manager, and leave
  both applications running. Master/source/catalog state remains untouched.

## 2026-08-29 - live identity readback proves old plug-in path is still active

- The bridge became callable and a live search again found exactly one
  `DSC_5343.NEF` at catalog id `976310`. The subsequent read-only metadata call
  returned the expected RAW/develop baseline but omitted every required new
  identity field: `uuid`, `catalog_id`, `is_virtual_copy`, `master_uuid`, and
  `virtual_copies`.
- Targeted integration-source inspection confirms this branch's
  `HandlerMetadata.lua` calls `PhotoIdentity.enrich`, which emits those fields.
  The response therefore cannot be counted as the integration identity
  contract, and `create_virtual_copy` was not called.
- The bridge log shows the old stale-panel start/stop race once more at
  23:41:02-23:41:05, followed by a successful manual start and stable sockets at
  23:41:17-23:41:18; search and metadata requests both completed afterward.
- The first sandboxed Lightroom Preferences search failed with access denied.
  An approved read-only retry succeeded and proved the registered/selected
  plug-in path is the old installed copy at
  `C:\Users\John\AppData\Roaming\Adobe\Lightroom\Modules\LightroomMCP.lrplugin`,
  not this integration worktree bundle.
- Required manual boundary: unregister the old path in Plug-in Manager, Add the
  exact integration bundle, let auto-start run without pressing the stale
  Start/Stop control, close the manager, and keep Codex/Lightroom running. No
  photo, catalog, sidecar, preview, configuration, or source changed.

## 2026-08-29 - old standard Modules plug-in cannot be removed in-app

- The user reported that Lightroom Plug-in Manager would not remove the old
  plug-in. Read-only inspection confirms it is a normal directory in Lightroom's
  standard per-user `AppData\Roaming\Adobe\Lightroom\Modules` location; reading
  its `Info.lua` was denied by the current sandbox, while the integration
  `Info.lua` remained readable and identifies `com.lightroom.mcp` v0.10.0.
- Current Adobe Lightroom Classic documentation confirms plug-ins in the
  Windows per-user Modules folder are automatically loaded and can be enabled
  or disabled in Plug-in Manager, but cannot be removed there. The disabled
  Remove control is therefore expected, not a Lightroom error.
- Because the old and integration bundles share the same toolkit identifier,
  the safe manual switch is to quit Lightroom, move the old bundle out of
  Modules to a retained backup, copy the integration bundle into the canonical
  Modules path, then reopen Lightroom and let it auto-start. No automated
  install, overwrite, delete, catalog change, or photo mutation was performed.

## 2026-08-29 - integration identity passed, duplicate plug-ins destabilized sockets

- Live `get_photo_metadata` for Master id `976310` returned the integration-only
  identity contract: UUID `5C9ABCF7-2CE5-4B6E-B55B-CD0315D8B784`, matching
  Master UUID, `is_virtual_copy=false`, and zero Virtual Copies. This proves the
  new plug-in loaded successfully despite the old entry remaining visible.
- Pre-mutation source evidence for `DSC_5343.NEF` recorded SHA-256
  `E8BD9B1F59D5D0DFC431674E28BA981B548640BC32FBEAF8D569B6F4760E418A`,
  size 19126784 bytes, last-write UTC `2026-07-25 07:57:02`, and no adjacent
  XMP sidecar.
- The first `create_virtual_copy` attempt used fixed operation id
  `t04-976310-20260829-v1` but returned transport-level `plugin not connected`.
  The Lightroom log contains no matching create request, so no catalog mutation
  reached the plug-in and the same operation id remains the only safe retry.
- Log evidence at 23:51:22-23:51:26 shows two server startups followed by
  `Auth failed (token mismatch)`, consistent with old and new bundles sharing
  the same toolkit identifier and running concurrently. T04 remains blocked on
  retaining only one active bundle; no photo, sidecar, Develop, or catalog
  mutation is counted.

## 2026-08-29 - old auto-loaded bundle archived reversibly

- After the user closed Lightroom, process verification returned
  `LIGHTROOM_PROCESS=absent` before any filesystem change.
- The exact old auto-loaded bundle
  `C:\Users\John\AppData\Roaming\Adobe\Lightroom\Modules\LightroomMCP.lrplugin`
  was moved, not deleted, to
  `D:\photo\_agent_workspace\archives\lightroom-plugins\LightroomMCP-old-20260829-235453.lrplugin`.
  The non-overwriting backup contains the same 18 files; the old Modules path
  no longer exists.
- Old `Info.lua` SHA-256 was
  `602233A6211B0B938BE1EE59A730FB457C812A8CEF850F903167CFF5B146929C` and
  old `PluginInit.lua` SHA-256 was
  `B617C503EF5E51B4984FA71619CE82DE4A684C9347427FB85D7D841D2C1E0479`.
  The retained integration bundle still exists with different hashes
  `7AAC2BD1B3CB2AE2F69517108039CFC3CE600621FD146F72507BB688FF5C346C`
  and `80D61D4CD418155CE49FA2120A832F75071EFC4DB3257E1839E100C33C449067`.
- Verification command completed successfully with source absent, backup
  present, equal file counts, and new bundle present. Lightroom restart and a
  live read-only request remain pending; no catalog or photo mutation occurred.
- `git diff --check` passed with only the pre-existing LF-to-CRLF warning;
  `git status --short` reports only this append-only `WORKLOG.md` modification.

## 2026-08-30 - single-bundle restart is stable but server not started

- After the user reopened Lightroom, process id `3828` was live with start time
  23:56:47. The log contains no new duplicate bootstrap or token-mismatch event
  after this launch, confirming the archived old Modules bundle did not reload.
- No new integration socket startup appeared, and live read-only
  `get_photo_metadata(976310)` returned `Lightroom plugin not connected`.
  `create_virtual_copy` was not called; fixed operation id
  `t04-976310-20260829-v1` remains pending and no catalog/photo mutation occurred.
- Manual boundary: select the integration bundle in Plug-in Manager, click
  Start Server exactly once, close the manager, and leave Lightroom running.

## 2026-08-30 - T04 live create and reconciliation core passed

- One integration server remained connected after the final manual start. Live
  read-only metadata for Master `976310` returned UUID
  `5C9ABCF7-2CE5-4B6E-B55B-CD0315D8B784`, `is_virtual_copy=false`, and zero
  existing Virtual Copies.
- Immediately before mutation, `DSC_5343.NEF` still had SHA-256
  `E8BD9B1F59D5D0DFC431674E28BA981B548640BC32FBEAF8D569B6F4760E418A`,
  size 19126784, last-write UTC `2026-07-25T07:57:02.8200000Z`, and no adjacent
  XMP sidecar.
- `create_virtual_copy` with the retained fixed operation id
  `t04-976310-20260829-v1` returned `result=created`, copy catalog id `1011125`,
  copy UUID `D36AFFEC-A7BC-4530-9DE5-10FFBAD415D8`, and verified selection
  restoration `status=restored`.
- Master/copy readback proved one exact sibling, copy-to-Master UUID/id linkage,
  `is_virtual_copy=true` only on the copy, and identical exposed Develop state.
  Repeating the same operation id returned `result=reconciled` for the same copy
  with no second creation; final Master readback still reports exactly one copy.
- Post-reconciliation source verification matched the same hash, size, creation
  and last-write timestamps, and absent-XMP state. No Master Develop setting was
  changed. Remaining T04 ticket clauses must be checked before marking the live
  gate complete.

## 2026-08-30 - T04 live gate completed locally

- Sandboxed `gh issue view 5` failed because GitHub network access was denied;
  the approved read-only retry succeeded and confirmed the open ticket's exact
  three acceptance clauses were unchanged.
- Live failure handling used Master `976310` with a deliberately incorrect
  expected UUID and distinct operation id
  `t04-976310-20260830-wrong-uuid-v1`. The plug-in rejected it with
  `Source UUID mismatch` before mutation. Follow-up Master readback still showed
  exactly one Virtual Copy, and selected-photo readback returned the restored
  pre-operation photo `976305`.
- Exported Workflow Copy `1011125` through Lightroom as one 2048-wide quality-90
  JPEG into the newly created, initially empty directory
  `D:\photo\_agent_workspace\lightroom\verification\t04-live-dsc-5343-20260830-0006`.
  The output `DSC_5343.jpg` is 608915 bytes with SHA-256
  `69EB4B4331CA5C5203CFFF0D4B391AF11C6813522FEC831E4A9E1FC2B4F604D8`.
  Direct image inspection confirmed a valid, nonblank Lightroom render of the
  expected squirrel photo; this is transport/basic-integrity evidence, not a
  creative-style acceptance claim.
- Final Master readback preserved UUID, `is_virtual_copy=false`, the complete
  exposed baseline Develop values, and one exact sibling. Final RAW evidence
  again matched SHA-256
  `E8BD9B1F59D5D0DFC431674E28BA981B548640BC32FBEAF8D569B6F4760E418A`,
  size 19126784, both timestamps, and absent XMP. The stable plug-in log records
  create, reconciliation, rejected UUID mismatch, selection readback, export,
  and final metadata without a new token mismatch or disconnect.
- Local T04 acceptance is complete for creation, identity, response-loss-style
  fixed-id reconciliation, selection restoration, fail-closed error handling,
  unchanged Master/source/sidecar state, and Lightroom-rendered output. A real
  dropped-response transport fault was not injected; the fixed-id second call
  proves the required reconciliation path. GitHub issue/branch publication and
  human creative QA remain explicitly unverified and were not changed.

## 2026-08-30 - authorized GitHub branch publication

- User explicitly authorized pushing the current version to GitHub. A normal,
  non-force push created `origin/codex/roadmap-integration` and configured the
  local integration branch to track it.
- The push included the locally committed T01-T04 integration and live T04
  acceptance record. No merge, issue closure/update, milestone change, pull
  request creation, or push to `upstream` occurred.

## 2026-08-30 - read-only Workflow Copy reconciliation capability

- Added `reconcile_virtual_copy` to the integration contract and dispatch. It
  scans the catalog by the exact operation marker, validates the expected Master
  and Copy/Master relationship, and returns one reconciled Copy or
  `REVIEW_REQUIRED` without changing selection or calling
  `createVirtualCopies`.
- Reused the existing strict identity/marker checks in `HandlerVirtualCopy`;
  `PhotoIdentity.lua` was inspected as the metadata identity source and was not
  changed. Server contract tests and Lua tests for no-write/no-create behavior
  were added. Verification is pending.
- `server\npm.cmd run check` passed after the read-only reconciliation contract
  and dispatch changes.

## 2026-08-30 - read-only Workflow Copy reconciliation targeted verification

- `server\npm.cmd test -- --runInBand tests/list-tools-handler.test.ts` passed:
  1 suite / 66 tests. The new `reconcile_virtual_copy` contract is present,
  read-only, catalog-scoped, automatically retry-safe, and shares the strict
  Workflow Copy output schema.
- First full `server\npm.cmd test -- --runInBand` run exposed one stale
  baseline assertion in `server/tests/server.test.ts`: it expected the old
  19-tool surface while the new contract correctly advertises 20 tools. The
  other 14 suites passed (174 tests); this was recorded as a verification
  failure before the assertion was updated.
- After updating that expected tool count, full `server\npm.cmd test --
  --runInBand` passed: 15 suites / 175 tests.
- Integration server verification also passed: `server\npm.cmd run check`,
  `server\npm.cmd run lint`, `server\npm.cmd run build`, and
  `git diff d1be8fe --check` (all exit 0).
- Official Lua attempt `mise run lua:test --
  plugin/spec/HandlerVirtualCopy_spec.lua` was blocked before execution:
  `mise` is not installed on PATH. The prepared fallback runner was also
  unavailable because no `lua`, `luac`, `selene`, or `luacheck` executable is
  installed on PATH; no Lua pass is claimed for this continuation.
- Updated the integration README tool count from 19 to 20 and documented the
  new read-only `reconcile_virtual_copy` endpoint and its pending live
  Lightroom acceptance boundary.
- Final post-edit rerun passed: full `server\npm.cmd test -- --runInBand`
  remained 15 suites / 175 tests; server check, lint, build, and
  `git diff d1be8fe --check` all returned exit 0.
- The first full Lua fallback sweep with the new endpoint ran 12 spec files
  successfully but exposed 17 failures in the pre-existing Search/Selection
  fixtures: strict `PhotoIdentity` now correctly rejects omitted
  `isVirtualCopy` status. The failure was retained as evidence; no production
  guard was weakened.
- Updated only those stale Search/Selection fixture records to explicitly
  represent Master photos (`isVirtualCopy = false`). The intentional missing
  and malformed identity cases in `HandlerMetadata_spec.lua` remain unchanged.
- Final Lua verification with the prepared Lua 5.4.6 runner passed all 14
  plugin spec files / 155 behavior tests, each executed in a separate process.
  `luac.exe -p` parsed all 32 plugin and spec Lua files, and Selene 0.31.0
  reported 0 errors, 0 warnings, and 0 parse errors.

## 2026-08-30 - T08 final safety invariant and dual-axis review

- Static integration invariant check passed: the
  `reconcileVirtualCopy` handler segment contains no
  `createVirtualCopies`, `withWriteAccessDo`, selection, or write calls, and
  the `reconcile_virtual_copy` contract is explicitly read-only and catalog
  scoped.
- Standards review against fixed base
  `d1be8fed5c14e6a400a1fcf93da9caea9c73d60e`, the repository instructions,
  and the existing plugin/server conventions passed with no P1/P2 findings.
  The configured `D:\photo\lightroom-mcp-john` checkout was not modified.
- Spec review against the T08 handoff and issue #13 acceptance criteria
  passed: the catalog-wide operation-marker query validates the expected
  Master and Copy relationship, returns one reconciled Copy or
  `REVIEW_REQUIRED`, and never changes selection or creates a Copy. Contract,
  dispatch, Lua behavior, and no-write regression coverage are aligned.
- The official `mise` command remains unavailable in this environment; the
  prepared Lua 5.4.6 runner, `luac.exe`, and Selene provided the recorded
  automated/spec verification. No live Lightroom or human visual acceptance
  is claimed.
- Final post-review `git diff d1be8fed5c14e6a400a1fcf93da9caea9c73d60e
  --check` exited 0. Git emitted only the known LF-to-CRLF working-copy
  normalization warnings; no whitespace errors were reported.

## 2026-08-30 - T08 publication commit permission boundary

- The first Lightroom MCP T08 commit attempt failed before creating a commit:
  Git could not create the shared-worktree index lock at
  `D:\photo\lightroom-mcp-john\.git\worktrees\lightroom-mcp-roadmap-integration\index.lock`
  (`Permission denied`). Read-only ACL inspection showed the integration
  worktree index is physically under the configured checkout. No source file,
  configured checkout state, or branch ref was changed by the failed attempt.
- A second attempt with a worktree-local temporary index avoided the index-lock
  path but failed before staging because the shared repository object database
  also denied writes (`insufficient permission for adding an object`). The
  temporary index was removed; no commit or source/configured-checkout change
  resulted.
- The first `gh pr create` attempt omitted `--repo`; GitHub CLI resolved the
  `upstream` repository (`Automaat/lightroom-mcp`) and failed with blank
  head/base refs and `No commits between main and codex/roadmap-integration`.
  Explicit read-only ref checks confirmed the intended `origin` repository
  `John-owo/lightroom-mcp` has `main` at `19431c06ddf7273cb83f6b1e7dd72bcf5fac254a`
  and the T08 branch at `8ac3e0e2b2aed059f5a94cb3a165fface42a014e`.

## 2026-08-30 - T08 PR baseline checkout blocker

- PR #12 remote checks exposed a pre-existing branch-history blocker outside
  the T08 allowlist: Windows checkout failed with `unable to create symlink
  AGENTS.md: Filename too long`, and the Lua lint setup failed while `mise`
  tried to stat the same long symlink target. Ubuntu/macOS, Busted, CodeQL,
  and version consistency passed.
- `origin/main` stores `AGENTS.md` as the portable symlink target
  `CLAUDE.md`; the integration branch had the 623-character guidance text as
  its symlink target. Restored only that target to `CLAUDE.md` so the branch
  can be checked out on Windows. This is a separate CI-baseline repair, not a
  T08 implementation change; no configured checkout was touched.
