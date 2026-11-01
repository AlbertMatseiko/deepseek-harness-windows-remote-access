# DeepSeek Harness on Windows

A short installation and baseline configuration guide. The DSH version is pinned to `0.2.1-rc.5` (developer preview).

## 1. Dependencies

```powershell
npm install -g pnpm@latest
```

```powershell
npm install -g @deepseek-ai/dsh@0.2.1-rc.5
```

```powershell
winget install --id Microsoft.PowerShell --source winget
```

Verify:

```powershell
dsh --version
```

Expected: `0.2.1-rc.5`.

## 2. First launch

```powershell
dsh web
```

Open `http://127.0.0.1:3080`.

Go to **Settings → Models → DeepSeek** and paste your API key from [platform.deepseek.com](https://platform.deepseek.com/). The key is stored write-only in `%USERPROFILE%\.dsh\.credentials.yaml`.

Models:

- `deepseek-flash` — the default for coding, agents, and vision; cheaper and faster;
- `deepseek-v4-pro` — an alternative for knowledge-heavy and long-context tasks.

Choose a workspace (**Choose workspace**). For the first run, use **Permissions: workspace-write + ask**.

## 3. Skills and AGENTS.md

DSH discovers `SKILL.md` files in:

- `<project>/.dsh/skills`;
- `<project>/.agents/skills`;
- `%USERPROFILE%\.dsh\skills`;
- `%USERPROFILE%\.agents\skills`.

Project skills override user skills with the same name.

`AGENTS.md` in the workspace root defines agent rules: language, plan-first behavior, the no-secrets rule, PowerShell 7, and so on. See the root `AGENTS.md` in this repository for an example.

## 4. Useful plugins (optional)

Install one at a time and pin versions:

```powershell
dsh plugin --profile web add dsh-better-sidebar@0.28.2
```

```powershell
dsh plugin --profile web add dsh-context
```

```powershell
dsh plugin --profile web add dsh-remote@0.8.67
```

`dsh-better-sidebar` requires DSH 0.2.1-rc.1+; check `dsh-context` after installation; `dsh-remote` is for SSH projects (see that plugin's own documentation).

### Office skills

```powershell
dsh plugin --profile web add @deepseek-ai/dsh-skill-office@0.2.1-rc.5
```

If pnpm blocks the native build:

```powershell
dsh plugin --profile web approve-builds koffi
```

Then repeat the installation. The package does not declare `dsh.bundle`, so mount it in `cordis.patch.yml`:

```yaml
- insert:
    - id: skill-office
      name: "@deepseek-ai/dsh-skill-office"
```

A complete example patch is in [examples/cordis.patch.yml](../examples/cordis.patch.yml).

### TUI

```powershell
dsh plugin --profile dsh-tui add @deepseek-harness-tui/dsh-tui@0.18.0
```

```powershell
dsh --profile dsh-tui
```

### VS Code

The `DSH Sidebar` extension (lixxx1) is installed from the Marketplace. It starts its own managed runtime; do not keep a second DSH on the same profile. If the extension cannot connect to an existing instance, use **Start Managed Runtime** or restart DSH.

## 5. Long-term memory (optional)

Memorix is an MCP server, not a DSH plugin:

```powershell
npm install -g memorix@1.3.0
```

Add the MCP block to `%USERPROFILE%\.dsh\profiles\web\cordis.patch.yml` (see `examples/cordis.patch.yml`). After restarting DSH, test a write/read across a new session.

## 6. Next: remote control

After the baseline:

- [README.md](../README.md) — `/latest` scripts and Tailscale Serve;
- [PHONE-LXBOX.md](PHONE-LXBOX.md) — phone setup;
- [SECURITY.md](SECURITY.md) — passwords and secrets.
