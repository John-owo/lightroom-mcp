# Lightroom MCP agent instructions

Read `CLAUDE.md` and `WORKLOG.md` before inspecting or changing code.

- Use targeted `rg` queries and files named in `WORKLOG.md`; do not recursively
  scan the repository unless a narrower query cannot answer the question.
- Append every material update and every verification command (pass or fail) to
  `WORKLOG.md`.
- Never claim live Lightroom connectivity, UI behavior, visual QA, plugin
  installation, or public release unless it was actually verified in the current
  task.
- Preserve unrelated working-tree changes and follow all architecture and test
  rules in `CLAUDE.md`.
