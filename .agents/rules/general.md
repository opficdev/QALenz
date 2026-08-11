# QALenz General Agent Rules

## Working basis

- Check the user request, current files, and actually installed tools first.
- Use historical records only as context. Prefer the current repository when they conflict.
- Before working, inspect `git status --short`, related files, the current diff, and recent commits.
- Do not include cleanup, renaming, or structural changes outside the approved scope.
- Reuse existing behavior whenever possible.
- Change logic only when the replacement produces exactly the same result and strictly improves time or space complexity.

## Project basis

- QALenz is a reusable Simulator QA orchestrator for multiple iOS projects.
- Do not assume an implementation language before an approved decision or repository manifest exists.
- When installed-tool behavior differs from documentation, use the installed-tool behavior as the source of truth.
- Do not place app-specific screen structures or data in shared implementation.
- Isolate project differences in configuration, scenarios, execution matrices, and test-data setup.
- Do not add generated artifacts or QA results to tracked files in the target project.

## Change rules

- Assign only one writing role to a file at a time.
- Read-only roles must not change files, Git state, or GitHub state.
- Documentation changes must describe only the document's actual responsibility and current behavior.
- Do not write placeholders, unverified commands, or nonexistent paths.
- Get user approval before adding dependencies, performing external writes, or deleting data.

## Sensitive information

- Remove tokens, certificates, private keys, environment-variable values, and user data from output and results.
- Do not copy complete raw logs into reports when they may contain sensitive information.
- Never use a user home directory or an entire repository as a broad deletion target.

## Documentation placement

- Keep `AGENTS.md` as the single entrypoint for AI working instructions.
- Keep roles and repeatable workflows under `.agents/`.
- Keep common rules in `.agents/rules/general.md`.
- Keep architecture rules in `.agents/rules/architecture.md`.
- Keep Git, PR, verification, and execution rules in `.agents/rules/project-workflows.md`.
- Do not mix AI working instructions with product documentation.
