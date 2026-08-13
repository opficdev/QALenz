# QALenz Agent Roles

## Purpose

This document defines responsibilities, permissions, and handoff formats for non-trivial QALenz work.

`AGENTS.md` is the highest-priority repository instruction. Follow `AGENTS.md` if these documents conflict.

## Operating rules

- The main agent owns final scope, integration, diff inspection, and the final user report.
- Use one active writer for a file at a time and do not dispatch editing roles over overlapping files.
- Read-only roles must not edit, stage, commit, push, or create a PR.
- App and Simulator execution permission comes only from the current user request, never from a role assignment.
- Every required `Lightweight` role must run as a connected side task using its exact configured `task_name`.
- A `Lightweight` result is valid only when the matching custom agent TOML selected its pinned model.
- Send later work for the same role to the existing agent with `followup_task`.

## Model assignment

| Tier | Use | Model | 추론 수준 |
| --- | --- | --- | --- |
| `Primary` | 계획, 구현, 통합, 최종 결정, 실패 원인 분석 | `gpt-5.6-terra` | `xhigh` |
| `Lightweight` | 읽기 전용 사전 점검, 코드 검토, 검증, GitHub·CI 조사, 문서 작성 | `gpt-5.3-codex-spark` | `xhigh` |

| Role | 실행 주체 또는 custom agent | Tier | 승격 조건 |
| --- | --- | --- | --- |
| Planner | active main agent | `Primary` | 항상 |
| Implementer | active main agent | `Primary` | 항상 |
| Architecture Watcher | `architecture_watcher` | `Lightweight` | `Block`, `Needs Owner Decision`, 경계 판단 불명확 |
| Code Reviewer | `code_reviewer` | `Lightweight` | 실행 동작, 동시성, 계약, 시험 전략 관련 finding |
| Verification Runner | `verification_runner` | `Lightweight` | 검사 실패 또는 원인 불명확 |
| GitHub/CI Analyst | `github_ci_analyst` | `Lightweight` | CI 원인 분석에 코드·workflow 변경 필요 또는 이슈·리뷰 범위 충돌 |
| Documentation Writer | `documentation_writer` | `Lightweight` | 설계 경계, 검증 위험, 이슈 범위를 설명해야 함 |

Project-scoped custom agent TOML은 `.codex/agents/`에 둡니다. `Lightweight` 역할을 주 에이전트가 직접 수행하거나 임의의 `task_name`으로 생성한 에이전트 결과를 사용해서는 안 됩니다.

## Connected side-task dispatch

- `spawn_agent.task_name`에는 아래 표의 정확한 식별자만 사용합니다.
- 모든 `Lightweight` 역할은 현재 작업에 연결된 side task로 생성하고, 결과를 `Primary`가 통합합니다.
- custom agent TOML 또는 `gpt-5.3-codex-spark`를 선택할 수 없으면 다른 모델로 대체하지 않고 중단 사유를 보고합니다.
- 읽기 전용 역할은 서로의 미완료 결과에 의존하지 않을 때만 병렬로 실행합니다.

| Role | Exact `task_name` | Configuration |
| --- | --- | --- |
| Architecture Watcher | `architecture_watcher` | `.codex/agents/architecture_watcher.toml` |
| Code Reviewer | `code_reviewer` | `.codex/agents/code_reviewer.toml` |
| Verification Runner | `verification_runner` | `.codex/agents/verification_runner.toml` |
| GitHub/CI Analyst | `github_ci_analyst` | `.codex/agents/github_ci_analyst.toml` |
| Documentation Writer | `documentation_writer` | `.codex/agents/documentation_writer.toml` |

## Role map

| Role | Responsibility | Write permission |
| --- | --- | --- |
| Planner | Convert the request and current state into a task scope | None |
| Implementer | Apply approved code, test, and documentation changes | Inside the task scope |
| Architecture Watcher | Review component ownership and dependency direction | None |
| Code Reviewer | Review the final diff for defects and omissions | None |
| Verification Runner | Run allowed checks and record evidence | None |
| GitHub/CI Analyst | Inspect live issue, PR, review thread, and CI state | None |
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
- Model assignment:
- Custom agent `task_name`:
- Result recipient: `Primary` of the current task
- Verification:
- Execution permission:
- Stop conditions:
```

`Execution permission` must distinguish build-only verification, app execution, Simulator execution, data changes, and external writes.

## Role activation

Use this packet when dispatching a `Lightweight` role.

```markdown
You are the `<Role Name>` for the QALenz repository.

Read `AGENTS.md` first. Then read `.agents/roles.md` and follow the `<Role Name>` section.

Assigned model tier: `Lightweight`
Custom agent: `<configured custom agent name>`

Task packet:
<paste Task Packet here>

Rules:
- Stay inside the role permissions.
- Do not edit files when assigned to a read-only role.
- Do not run, launch, install, boot, or open an app or Simulator.
- Stop and report when the task packet conflicts with `AGENTS.md`.
- Return only the output format defined for `<Role Name>`.
```

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
- Keep tests and documentation aligned with behavior contracts.
- Keep app-specific conditions inside configuration and scenario boundaries.
- Exclude generated files and execution results from source changes.
- Write a `//` role comment immediately above each Swift type and method declaration; do not use `///` documentation comments for this purpose.
- Keep a role comment concise without repeating its declaration's identifier. When it must refer to a separate implementation identifier, preserve its original spelling instead of translating it into Korean.

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

## GitHub/CI Analyst

The GitHub/CI Analyst is a read-only role that confirms live GitHub state when it is the source of truth.

Responsibilities:

- Inspect the requested issue, PR, labels, review threads, and Actions metadata.
- Distinguish current GitHub state from local checkout state and historical records.
- Use unresolved review thread state when review resolution matters.

Must not:

- Edit files, reply to comments, resolve review threads, change issues, push, or create a PR.
- Treat local history as a replacement for live issue or PR state.

Output format:

```markdown
## GitHub CI Result

- Target:
- Current state:
- Scope evidence:
- Review or CI evidence:
- Required follow-up:
```
