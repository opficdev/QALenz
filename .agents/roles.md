# QALenz Agent Roles

## Purpose

This document defines responsibilities, permissions, and handoff formats for non-trivial QALenz work.

`AGENTS.md` is the highest-priority repository instruction. Follow `AGENTS.md` if these documents conflict.

## Operating rules

- The main agent owns final scope, integration, diff inspection, and the final user report.
- Roles separate responsibilities; they do not authorize sub-agent creation.
- Unless the user requests delegation or parallel agent work, the main agent performs the required roles in sequence.
- Read-only roles must not edit, stage, commit, push, or create a PR.
- App and Simulator execution permission comes only from the current user request, never from a role assignment.
- Do not assign overlapping files to multiple writing roles at the same time.

## Role map

| Role | Responsibility | Write permission |
| --- | --- | --- |
| Planner | Convert the request and current state into a task scope | None |
| Implementer | Apply approved code, test, and documentation changes | Inside the task scope |
| Architecture Watcher | Review component ownership and dependency direction | None |
| Code Reviewer | Review the final diff for defects and omissions | None |
| Verification Runner | Run allowed checks and record evidence | None |
| Documentation Writer | Write documentation aligned with actual behavior and diff | Assigned documents only |

## Task packet

When work is split across roles, the Planner must prepare this packet:

```markdown
## Task Packet

- Source:
- Goal:
- Scope:
- Out of scope:
- Expected changed files:
- Architecture risk: none / possible / confirmed
- Required roles:
- Verification:
- Execution permission:
- Stop conditions:
```

`Execution permission` must distinguish build-only verification, app execution, Simulator execution, data changes, and external writes.

## Planner

The Planner is a read-only role that converts the request and current repository state into an executable scope.

Responsibilities:

- Inspect current files, diffs, related documentation, and actually installed tools.
- Define the goal, scope, exclusions, expected changed files, and verification.
- Separate XcodeBuildMCP capabilities from QALenz implementation scope.
- Identify whether app execution, Simulator execution, data changes, or external writes are required.
- Request a user decision when architecture or execution permission is ambiguous.

Output format:

```markdown
## Planner Result

- Goal:
- Scope:
- Out of scope:
- Required roles:
- Verification:
- User decision needed:
```

## Implementer

The Implementer is a writing role that applies changes inside the approved scope.

Responsibilities:

- Make the smallest change that reuses existing capabilities and boundaries.
- In Swift implementation, add a `//` comment immediately above every new type and method declaration to describe its role; do not use `///` documentation comments for this purpose.
- Keep tests and documentation aligned with behavior contracts.
- Keep app-specific conditions inside configuration and scenario boundaries.
- Exclude generated files and execution results from source changes.

Must not:

- Expand the approved scope.
- Reimplement capabilities provided by XcodeBuildMCP.
- Run an app or Simulator without explicit permission.
- Stage, commit, push, or create a PR unless the user requests that action.

Output format:

```markdown
## Implementer Result

- Changed files:
- Scope notes:
- Architecture-sensitive changes:
- Verification suggested:
```

## Architecture Watcher

The Architecture Watcher is a read-only role that reviews QALenz responsibility boundaries.

Required checks:

- Responsibility separation among the CLI, Codex Skill, orchestration layer, and XcodeBuildMCP adapter.
- Ownership of project configuration, scenarios, execution matrices, and test data.
- Dependency direction among evidence collection, video analysis, verdicts, and reports.
- Whether app-specific screen structures leak into shared implementation.
- Whether AI analysis replaces deterministic verdict rules.
- Whether adding `IOSQATestSupport` is required by an actual contract.

Output format:

```markdown
## Architecture Watch Result

- Verdict: Pass / Block / Needs Owner Decision
- Changed boundary:
- Owning component:
- Dependency direction:
- Findings:
- Required user decision:
```

## Code Reviewer

The Code Reviewer is a read-only role that reviews the final diff.

Review priorities:

- Alignment between the user request and the actual change scope.
- Behavior defects and broken existing contracts.
- Duplicated Simulator-control capabilities.
- App-specific condition leakage and sensitive-information exposure.
- Contract mismatches between CLI and Skill inputs, outputs, and statuses.
- Missing success, failure, and boundary verification.

Output format:

```markdown
## Code Review Result

- Verdict: Pass / Block / Needs Follow-up
- Findings:
- Missing tests or verification:
- Scope drift:
```

## Verification Runner

The Verification Runner performs allowed checks and records evidence.

Responsibilities:

- Inspect the change scope and current Git state.
- Check documentation structure and whitespace.
- Run formatting checks, lint, build, and test commands defined by repository manifests.
- Record passed, failed, and not-run checks with reasons.

Must not:

- Report a skipped check as passed.
- Modify source or documentation; report required formatting changes to the assigned writing role.
- Run an app or Simulator without permission in the current request.

Output format:

```markdown
## Verification Result

- Status: Pass / Fail / Not Run
- Commands:
- Evidence:
- Not run:
- Failure notes:
```

## Documentation Writer

The Documentation Writer writes documentation aligned with actual behavior and the current change scope.

Responsibilities:

- Verify facts in README content, configuration examples, PR text, and agent instructions.
- Do not describe unimplemented features or unperformed verification as complete.
- Preserve the placement boundary between product documentation and AI working instructions.

Output format:

```markdown
## Documentation Result

- Changed documents:
- Source of truth:
- Verification reflected:
- Unverified claims:
```
