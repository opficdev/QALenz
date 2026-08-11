# QALenz Agent Instructions

## Scope

- These instructions apply to the entire repository.
- Read every routed document that matches the current task. Routes are cumulative.

## Required routing

| Task | Required document |
| --- | --- |
| Every task | `.agents/rules/general.md` |
| Non-trivial design, implementation, review, or verification | `.agents/roles.md` |
| Repeatable role-based work | `.agents/workflows.md` |
| Component ownership, dependency direction, XcodeBuildMCP boundaries, CLI, Skill, scenarios, or verdict design | `.agents/rules/architecture.md` |
| Git, PR, review, verification, build, app execution, or Simulator execution | `.agents/rules/project-workflows.md` |

## Routing rules

- Treat `AGENTS.md` as the repository instruction entrypoint and routing source.
- Read all task-matching documents before planning, editing, reviewing, or verifying.
- Before architecture work, also read `README.md`, the current manifests, and the relevant source and tests.
- For role-based work, follow the permissions and output formats in `.agents/roles.md`.
- Use `.agents/workflows.md` when the task matches a defined repeatable workflow.
- A role definition does not authorize sub-agent use.
- Use sub-agents only when the user explicitly requests delegation or parallel agent work.
- If repository instructions conflict with external records, follow the current repository instructions.

## Code Review Rules

Write all code review findings and summaries in Korean. Keep implementation names, file paths, commands, API names, branch names, and commit hashes in their original form.

### Preserve the XcodeBuildMCP boundary

- Flag changes that directly implement Simulator control, build or test execution, UI automation, screenshot or video capture, log collection, or debugging capabilities already provided by the supported XcodeBuildMCP contract.
  Safe path: delegate those operations through the XcodeBuildMCP adapter and keep QALenz responsible for orchestration, response normalization, evidence analysis, verdicts, and reports. Adapter code that translates requests and responses is allowed.

### Keep project-specific behavior out of shared runtime code

- Flag shared runtime code that hard-codes an app's scheme, element identifiers, navigation structure, screen content, or test data.
  Safe path: place app-specific values and steps in project-owned configuration, scenarios, or test-data providers. Project-specific examples and fixtures are allowed when they do not affect shared runtime behavior.

### Keep deterministic verdicts authoritative

- Flag any path where AI output alone can produce a passing result, override a deterministic failure, or hide missing evidence.
  Safe path: evaluate color, region, timing, baseline-image, and frame-change rules first; use AI only as supplemental analysis for ambiguous results, and preserve an unresolved or failed status when deterministic evidence does not support a pass.
