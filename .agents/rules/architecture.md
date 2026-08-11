# QALenz Architecture Rules

## Purpose

This document defines QALenz component responsibilities and dependency direction.

Before architecture work, inspect `README.md`, current manifests, related source and tests, and actually installed XcodeBuildMCP capabilities.

## High-level flow

```text
Codex Skill or CLI
    -> QA orchestration layer
        -> Project configuration and scenarios
        -> Execution matrices and app launch state
        -> XcodeBuildMCP adapter
        -> Evidence collection
        -> Video and image analysis
        -> Verdict generation
        -> Report generation

IOSQATestSupport
    -> Used only when shared test contracts are required
```

## Responsibility boundaries

### Codex Skill

- Map natural-language requests to scenarios and execution matrices.
- Do not implement QA capabilities directly.
- Summarize targets and side effects before execution.
- Use the same orchestration layer as the CLI.

### CLI

- Provide commands, options, output formats, and exit statuses.
- Support both human-readable summaries and JSON or JSONL output.
- Distinguish passed, verification-failed, and execution-error states.
- Do not implement Simulator-control capabilities directly.

### QA orchestration layer

- Discover projects and scenarios.
- Manage execution matrices and step order.
- Invoke contracts for app launch state and test-data setup.
- Coordinate XcodeBuildMCP calls.
- Connect evidence, verdicts, and reports.
- Serve both the CLI and Codex Skill.

### XcodeBuildMCP adapter

- Encapsulate the call contract of the installed XcodeBuildMCP version.
- Delegate build, test, app execution, UI interaction, screenshots, video, logs, and debugging.
- Normalize tool-specific responses into QALenz execution results.
- Do not add controllers that duplicate existing tool capabilities.

### Project configuration and scenarios

- Define projects, workspaces, schemes, and scenario steps.
- Define device, OS, display-mode, and language matrices.
- Define contracts for test-data setup and app launch state.
- Keep app-specific elements and data inside that project's scenarios.

### Evidence and verdicts

- Associate screenshots, video, logs, UI hierarchy, and execution metadata with a run identifier.
- Evaluate color, region, and timing rules first.
- Use baseline-image differences and frame-change metrics as subsequent evidence.
- Use AI-assisted analysis only for ambiguous results.
- Never create a passing status from AI output alone.

### Reports

- Aggregate targets, step results, verdict evidence, evidence paths, and errors.
- Keep human-readable and machine-readable outputs consistent.
- Include only redacted evidence.

### IOSQATestSupport

- Add Swift Testing contract helpers or shared XCUITest helpers only when required.
- Do not include capabilities that belong in the Skill or orchestration layer.
- Do not place app-specific screen structures or data in the shared package.

## Dependency direction

- The CLI and Skill depend on the QA orchestration layer.
- The orchestration layer depends on configuration contracts, execution adapters, and evidence, verdict, and report contracts.
- XcodeBuildMCP details remain isolated inside its adapter.
- Verdict rules must be testable independently from the UI execution mechanism.
- Reports depend on normalized QALenz results, not raw tool responses.
- Project scenarios must not cause shared implementation to depend on app-specific screen structures.

## Testing boundaries

- Use Swift Testing for parsing, execution matrices, verdict rules, reports, and configuration validation that require no screen interaction.
- Use XCUITest or XcodeBuildMCP UI automation for real navigation and interaction.
- Keep video and image analysis independently testable with stored evidence.
- Unit tests must run without launching an app or Simulator.

## Language decision boundary

- Do not assume an implementation language before creating a manifest.
- Compare a Swift executable, TypeScript, and a thin shell orchestration layer by installation convenience, XcodeBuildMCP integration, video processing, and single-executable feasibility.
- Preserve CLI contracts and component responsibilities after selecting a language.

## Decision stop conditions

- QALenz implementation overlaps existing XcodeBuildMCP capabilities.
- There is no evidence that an app-specific requirement belongs in a shared contract.
- The need for `IOSQATestSupport` cannot be explained by a test contract.
- AI analysis replaces deterministic verdict rules.
- Execution side effects and data cleanup ownership are undefined.

Stop and request a user decision instead of implementing by assumption when any condition applies.
