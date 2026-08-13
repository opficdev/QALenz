# QALenz Agent Workflows

## Purpose

This document defines role order and completion conditions for repeatable QALenz work.

Use `.agents/roles.md` for role permissions and output formats.

## Main-agent protocol

1. Read `AGENTS.md` and every routed document for the current task.
2. Compare the user request with the current repository state.
3. Create a Task Packet with required roles, model assignment, exact `task_name`, and execution permissions.
4. Keep `Primary` roles with the active main agent.
5. Create each required `Lightweight` role as a connected side task through its exact configured `task_name`.
6. Apply changes only through the assigned writing role after required preflight results pass.
7. Reuse the existing agent with `followup_task` for later work in the same role.
8. Integrate every delegated result, inspect the final diff and all not-run checks, and report only evidence-backed results.

## Universal stop conditions

- A user decision would change the implementation scope.
- App or Simulator execution is required but not permitted.
- Simulator reset or data deletion is required but has not been separately requested and approved for the resolved target.
- QALenz implementation would overlap XcodeBuildMCP responsibility.
- Progress requires placing app-specific conditions in shared implementation.
- Sensitive-information exposure cannot be mitigated through redaction or output scoping.
- A required tool or runtime is not available in the actual environment.
- A required `Lightweight` custom agent TOML or its pinned `gpt-5.3-codex-spark` model cannot be selected.

## Architecture, review, and verification completion gate

Apply this gate to every workflow that includes an Architecture Watcher final review, Code Reviewer, or Verification Runner.

- Do not complete the workflow when the Architecture Watcher final review returns `Block`. Return required changes to the assigned writing role, then repeat final architecture review and downstream review and verification after modification.
- Do not complete the workflow when the Architecture Watcher final review returns `Needs Owner Decision`. Stop until the user decides, then repeat final architecture review and downstream review and verification required by the workflow.
- Do not complete the workflow when the Code Reviewer returns `Block` or `Needs Follow-up`. Return required changes to the assigned writing role, then restart at the earliest final review required by the workflow and repeat all downstream review and verification after modification.
- Do not complete the workflow when the Verification Runner returns `Fail`. Return failure notes to the assigned writing role, then restart at the earliest final review required by the workflow and repeat all downstream review and verification after modification.
- `Not Run` does not block completion when the workflow permits the omitted check and its reason is recorded.

## Workflow selection

| Task | Workflow |
| --- | --- |
| General implementation | Scoped implementation |
| Component ownership or dependency-direction change | Architecture-sensitive implementation |
| README, configuration examples, or AI instructions | Documentation-only change |
| Scenario, execution matrix, or verdict-rule change | QA contract change |
| QA that uses an app or Simulator | QA execution |
| Review-feedback changes | Review follow-up |
| AGENTS, role, workflow, rule, or custom-agent configuration | AI workflow maintenance |

Selection rules:

- Select workflows based on the responsibility or contract being changed, not only the file type.
- When multiple workflows match, use the workflow with the strictest role and stop-condition requirements as the primary workflow, then add any roles and verification requirements from the other matching workflows.
- Use Documentation-only change only when the document does not change architecture, QA contracts, execution permissions, or product behavior.
- Review follow-up controls feedback scope but does not replace the workflow required by the accepted change.

## Scoped implementation

Role order:

1. Planner (`Primary`)
2. Implementer (`Primary`)
3. Code Reviewer (`code_reviewer`, `Lightweight`)
4. Verification Runner (`verification_runner`, `Lightweight`)

Completion conditions:

- Changed files match the Task Packet scope.
- Existing tool capabilities are not reimplemented.
- Relevant tests or verification evidence exist.
- Not-run checks and reasons are recorded.

## Architecture-sensitive implementation

Role order:

1. Planner (`Primary`)
2. Architecture Watcher preflight (`architecture_watcher`, `Lightweight`)
3. Implementer (`Primary`)
4. Architecture Watcher final review (`architecture_watcher`, `Lightweight`)
5. Code Reviewer (`code_reviewer`, `Lightweight`)
6. Verification Runner (`verification_runner`, `Lightweight`)

Stop before implementation when the Architecture Watcher returns `Block` or `Needs Owner Decision`.

Completion conditions:

- The owning component and dependency direction are explicit.
- XcodeBuildMCP boundaries remain intact.
- CLI and Skill share the same orchestration contract.
- Project-specific conditions remain isolated in configuration and scenarios.

## Documentation-only change

Role order:

1. Planner (`Primary`)
2. Documentation Writer (`documentation_writer`, `Lightweight`)
3. Code Reviewer (`code_reviewer`, `Lightweight`)
4. Verification Runner (`verification_runner`, `Lightweight`)

Required checks:

- Content is grounded in actual files and behavior.
- Referenced links and paths exist.
- Markdown structure and whitespace are valid.
- The document makes no out-of-scope product or execution promises.

For documentation-only changes, record source builds as not run instead of running them.

## QA contract change

Role order:

1. Planner (`Primary`)
2. Architecture Watcher preflight (`architecture_watcher`, `Lightweight`)
3. Implementer (`Primary`)
4. Architecture Watcher final review (`architecture_watcher`, `Lightweight`)
5. Code Reviewer (`code_reviewer`, `Lightweight`)
6. Verification Runner (`verification_runner`, `Lightweight`)

Stop before implementation when the Architecture Watcher returns `Block` or `Needs Owner Decision`.

Required checks:

- Input contracts for scenarios and execution matrices.
- Setup and cleanup contracts for test data and app launch state.
- Evidence paths and sensitive-information redaction.
- Separation among passed, verification-failed, and execution-error states.
- Priority of deterministic verdict rules over AI-assisted analysis.

## QA execution

Role order:

1. Planner (`Primary`) confirms execution scope and permission.
2. Verification Runner (`verification_runner`, `Lightweight`) confirms tools and targets.
3. Run only the approved scenario.
4. Collect evidence and statuses.
5. Report verdict evidence and unresolved items.

Confirm before execution:

- Target project, scheme, device, OS, language, and display mode.
- Explicit permission in the current request to run the app and Simulator.
- Test-data setup and cleanup, including creation, modification, reset, and deletion of app-local or external data, with explicit permission for each required side effect.
- Result output path.

Do not expand execution to unrequested devices, OS versions, scenarios, or data changes.

## Review follow-up

Role order:

1. GitHub/CI Analyst (`github_ci_analyst`, `Lightweight`) inspects current review state.
2. Planner (`Primary`) defines the accepted change scope.
3. Implementer (`Primary`) applies only selected changes.
4. Code Reviewer (`code_reviewer`, `Lightweight`) reviews the final diff.
5. Verification Runner (`verification_runner`, `Lightweight`) performs related checks.

Validate review feedback against current code and contracts before accepting it. Exclude unrelated cleanup.

## AI workflow maintenance

Use for `AGENTS.md`, `.agents/roles.md`, `.agents/workflows.md`, `.agents/rules/`, or `.codex/agents/*.toml` changes.

Role order:

1. Planner (`Primary`)
2. Implementer (`Primary`)
3. Code Reviewer (`code_reviewer`, `Lightweight`)
4. Verification Runner (`verification_runner`, `Lightweight`)

Required checks:

```sh
git diff --check -- AGENTS.md .agents .codex/agents
rg -n "gpt-5\\.6-terra|gpt-5\\.3-codex-spark|Lightweight|task_name" AGENTS.md .agents .codex/agents
```

Do not modify QALenz source, tests, manifests, CI, or public documentation as part of this workflow unless the user separately requests it.

## Parallel dispatch guide

Use only connected side tasks created through the exact configured `task_name`.

Parallelize only read-only roles without unfinished dependencies:

- GitHub/CI Analyst and Planner while a live issue or PR is being scoped.
- Architecture Watcher and Code Reviewer only after the final diff is stable and their review scopes do not overlap.
- Documentation Writer and Verification Runner after the diff is stable.

Do not parallelize two editing roles over the same file, an Implementer with Code Reviewer before the diff is complete, or Verification Runner before relevant files are saved.
