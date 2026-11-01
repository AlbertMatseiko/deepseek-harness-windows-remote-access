# AGENTS.md

Rules for agents working with this repository.

## Language and style

- Reply in English unless the user asks for another language.
- Be concise. For non-trivial changes, propose a plan first.
- Reference files as `path:line`.

## Security

- Never commit secrets: `scripts/config.ps1`, `latest-auth.json`, `latest-url.txt`, `.credentials.yaml`, keys, subscriptions, auth keys.
- Do not publish real tailnet names, email addresses, device serial numbers, or personal paths.
- In documentation use placeholders only: `<pc>.<tailnet>.ts.net`, `%USERPROFILE%`, `$env:LOCALAPPDATA`.
- Ask before deleting files, running `git push`, or changing system settings.
- Do not use `danger-full-access` for DSH tasks.

## Tools

- Shell: PowerShell 7 (`pwsh -NoProfile ...`), not cmd.exe.
- Search: `rg`.
- DSH: `dsh plugin --profile web ...`; pin plugin versions.
- Script validation: `pwsh -NoProfile -Command` with `Parser::ParseFile`.

## Repository

- This is a user-case guide, not a research plan.
- `local/` is local-only and never committed.
- `docs/` is user-facing documentation; do not add personal data there.
