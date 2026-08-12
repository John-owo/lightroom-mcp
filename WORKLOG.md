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
