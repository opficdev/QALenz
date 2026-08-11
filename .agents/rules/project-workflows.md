# QALenz Project Workflow Rules

## Sources of truth

- Treat `AGENTS.md` and routed `.agents/` documents as repository instructions.
- Treat `README.md`, manifests, source, tests, and `.github/pull_request_template.md` as sources of actual behavior.
- Prefer the current repository when it conflicts with external records.

## Before working

- Inspect current changes with `git status --short`.
- Read related files and recent commits.
- Preserve existing changes that are outside the user request.
- Identify expected changed files and verification commands.
- Distinguish writes to the app, Simulator, data, Git, and GitHub.

## Build and execution

- Build-only verification is allowed.
- Do not run, launch, install, boot, or open an app or Simulator unless the user explicitly requests it in the current turn.
- Do not substitute a build-and-run command for build-only verification.
- Treat `ios-qa` command semantics as future design until the CLI is implemented and available in the actual environment; do not invoke `ios-qa` before then.
- After the CLI is implemented and available, keep `ios-qa doctor`, `discover`, `list`, `inspect`, and `report` read-only; they must not run an app or Simulator or install tools.
- After the CLI is implemented and available, treat an explicit user request to execute `ios-qa run` as permission to run the app and Simulator only for the specified scenario.
- Never reset a Simulator, delete data, or delete a device without a separate request and approval.
- Do not expand execution to unrequested devices, OS versions, languages, or display modes.

## Verification

- For documentation changes, verify file presence, links and paths, Markdown structure, and whitespace.
- For implementation changes, use format, lint, build, and test commands defined by current manifests and scripts.
- Report real Simulator QA separately from stored-evidence analysis.
- Classify every check as passed, failed, or not run.
- Record every not-run check and its reason.
- Do not use an existing result as evidence unless it was rerun against the current source.

## Generated artifacts and results

- Do not modify the target project from its default state.
- Store QA results in a user-selected output path or a task-specific temporary directory.
- Do not stage screenshots, video, logs, UI hierarchy, or reports with source changes.
- Do not attach raw logs containing credentials or user data to documentation or PRs.
- Before cleaning artifacts, resolve the exact target path and prefer recoverable operations.

## Git

- Stage only files related to the current task.
- Start commit messages with a prefix such as `feat`, `fix`, `refactor`, `chore`, `test`, or `docs`.
- Write commit-message descriptions in Korean noun-phrase form.
- Do not write a commit-message body.
- Commit, push, or change branches only when the user explicitly requests that action.
- Before committing, inspect the staged diff and whitespace errors.
- After committing, verify the commit hash and working-tree state.

## Pull requests and review

- Read `.github/pull_request_template.md` before drafting a PR.
- Write PR content in Korean noun-phrase form based on the actual branch diff and verification results.
- Do not mark unperformed builds, tests, app execution, or Simulator QA as complete.
- Validate review feedback against current source, tests, and contracts before accepting it.
- Apply only selected fixes and exclude unrelated cleanup.
- Create a PR, add comments, update review threads, or change issues only when the user explicitly requests that action.

## Documentation alignment

- Write user-facing explanations in Korean.
- Review related documentation when public commands, configuration formats, scenario contracts, or result formats change.
- Do not update public documentation for internal changes that leave documented behavior unchanged.
- Keep AI working instructions in `AGENTS.md` and `.agents/`.
