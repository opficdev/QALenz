# QALenz Agent Workflows

## Purpose

This document defines role order and completion conditions for repeatable QALenz work.

Use `.agents/roles.md` for role permissions and output formats.

## Main-agent protocol

1. Read `AGENTS.md` and every routed document for the current task.
2. Compare the user request with the current repository state.
3. Determine required roles and execution permissions.
4. Apply changes only through the assigned writing role.
5. Perform read-only review and allowed verification.
6. Inspect the final diff and all not-run checks.
7. Report only evidence-backed results to the user.

## Universal stop conditions

- A user decision would change the implementation scope.
- App or Simulator execution is required but not permitted.
- Simulator reset or data deletion is required but has not been separately requested and approved for the resolved target.
- QALenz implementation would overlap XcodeBuildMCP responsibility.
- Progress requires placing app-specific conditions in shared implementation.
- Sensitive-information exposure cannot be mitigated through redaction or output scoping.
- A required tool or runtime is not available in the actual environment.

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

Selection rules:

- Select workflows based on the responsibility or contract being changed, not only the file type.
- When multiple workflows match, use the workflow with the strictest role and stop-condition requirements as the primary workflow, then add any roles and verification requirements from the other matching workflows.
- Use Documentation-only change only when the document does not change architecture, QA contracts, execution permissions, or product behavior.
- Review follow-up controls feedback scope but does not replace the workflow required by the accepted change.

## Scoped implementation

Role order:

1. Planner
2. Implementer
3. Code Reviewer
4. Verification Runner

Completion conditions:

- Changed files match the Task Packet scope.
- Existing tool capabilities are not reimplemented.
- Relevant tests or verification evidence exist.
- Not-run checks and reasons are recorded.

## Architecture-sensitive implementation

Role order:

1. Planner
2. Architecture Watcher preflight
3. Implementer
4. Architecture Watcher final review
5. Code Reviewer
6. Verification Runner

Stop before implementation when the Architecture Watcher returns `Block` or `Needs Owner Decision`.

Completion conditions:

- The owning component and dependency direction are explicit.
- XcodeBuildMCP boundaries remain intact.
- CLI and Skill share the same orchestration contract.
- Project-specific conditions remain isolated in configuration and scenarios.

## Documentation-only change

Role order:

1. Planner
2. Documentation Writer
3. Code Reviewer
4. Verification Runner

Required checks:

- Content is grounded in actual files and behavior.
- Referenced links and paths exist.
- Markdown structure and whitespace are valid.
- The document makes no out-of-scope product or execution promises.

For documentation-only changes, record source builds as not run instead of running them.

## QA contract change

Role order:

1. Planner
2. Architecture Watcher preflight
3. Implementer
4. Architecture Watcher final review
5. Code Reviewer
6. Verification Runner

Stop before implementation when the Architecture Watcher returns `Block` or `Needs Owner Decision`.

Required checks:

- Input contracts for scenarios and execution matrices.
- Setup and cleanup contracts for test data and app launch state.
- Evidence paths and sensitive-information redaction.
- Separation among passed, verification-failed, and execution-error states.
- Priority of deterministic verdict rules over AI-assisted analysis.

## QA execution

Role order:

1. Planner confirms execution scope and permission.
2. Verification Runner confirms tools and targets.
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

1. Inspect the Code Reviewer result or current review feedback.
2. Planner defines the accepted change scope.
3. Implementer applies only selected changes.
4. Code Reviewer reviews the final diff.
5. Verification Runner performs related checks.

Validate review feedback against current code and contracts before accepting it. Exclude unrelated cleanup.
