# QALenz General Agent Rules

## Working basis

- Check the user request, current files, and actually installed tools first.
- Use historical records only as context. Prefer the current repository when they conflict.
- Before working, inspect `git status --short`, related files, the current diff, and recent commits.
- Do not include cleanup, renaming, or structural changes outside the approved scope.
- Reuse existing behavior whenever possible.
- When refactoring existing logic, replace it only if the new approach produces exactly the same results and strictly improves time or space complexity.
- Keep behavior changes for approved features or bug fixes within the requested scope.

## Project basis

- QALenz is a reusable Simulator QA orchestrator for multiple iOS projects.
- Do not assume an implementation language before an approved decision or repository manifest exists.
- When installed-tool behavior differs from documentation, use the installed-tool behavior as the source of truth.
- Do not place app-specific screen structures or data in shared implementation.
- Isolate project differences in configuration, scenarios, execution matrices, and test-data setup.
- Do not add generated artifacts or QA results to tracked files in the target project.

## Change rules

- Assign only one writing role to a file at a time.
- Read-only roles must not leave changes to tracked files or change Git or GitHub state; allowed verification commands may create ignored or task-specific artifacts.
- Documentation changes must distinguish current behavior from approved future design and must not present unimplemented behavior as current.
- Do not leave unresolved placeholders in completed documents or present unverified commands or nonexistent paths as current interfaces; label approved future contracts explicitly.
- Get user approval before adding dependencies, performing external writes, or deleting data.

## Sensitive information

- Remove tokens, certificates, private keys, environment-variable values, and sensitive or production user data from output and results.
- Use controlled test data for screenshots, video, logs, and UI hierarchy; redact sensitive fields without removing evidence required for reproduction or verdicts.
- Do not copy complete raw logs into reports when they may contain sensitive information.
- Never use a user home directory or an entire repository as a broad deletion target.

## Documentation placement

- Keep `AGENTS.md` as the single entrypoint for AI working instructions.
- Keep roles and repeatable workflows under `.agents/`.
- Keep common rules in `.agents/rules/general.md`.
- Keep architecture rules in `.agents/rules/architecture.md`.
- Keep Git, PR, verification, and execution rules in `.agents/rules/project-workflows.md`.
- Do not mix AI working instructions with product documentation.
