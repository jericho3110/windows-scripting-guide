# Security

## Contents

- [Threat model](#threat-model)
- [Defenses](#defenses)
- [RCE: every way code could run](#rce-every-way-code-could-run)
- [Review table](#review-table)
- [Publishing this repo](#publishing-this-repo)
- [Accepted risks](#accepted-risks)
- [References](#references)

## Threat model

`move_folders.ps1` runs **as you**, with your file permissions, on your
own folders. Nobody else gives it input over a network. The realistic dangers
are **mistakes** (a wrong path in the list, a locked folder, a dirty repo)
and **a tampered script**: someone hands you a modified copy.

| Asset | Threat |
| --- | --- |
| your folders and repos | moved outside the root, overwritten, half-moved, uncommitted work lost |
| this public repo | personal data (names, paths, user name, emails) leaking into files or history |

## Defenses

| Defense | Code | Test |
| --- | --- | --- |
| paths must stay inside the root (no `..`, no absolute) | `Resolve-Inside` | `".." destination refused`, `absolute destination refused`, `nothing written outside the root` |
| the root itself and "into itself" refused | `Resolve-Inside` (needs `root\` prefix), self-move check | `moving the root itself refused`, `moving into itself refused` |
| never overwrite | destination-exists check | `existing destination refused`, `source untouched` |
| dirty repos refused; all checks before any move | phase 1 | `uncommitted changes refused`, `the good move did not happen either` |
| no copy + delete | `Move-Item` rename only | `moves succeed`, `repo moved, old path gone` |
| default is "no" | `Read-Host`, exactly `yes` | manual |
| git failures stop the script | `Get-GitLine` checks `$LASTEXITCODE` | manual (break a repo's `.git/config`) |
| tests can't damage real data | test root inside a test-owned `%TEMP%` folder; delete only `move-folders-test-*` | `nothing written outside the root` under a mutation run |

## RCE: every way code could run

| Path | Status |
| --- | --- |
| `Invoke-Expression` / `iex`, `[scriptblock]::Create`, `.DownloadString` | **not used**; the `devtools scan` pattern sweep fails the check gate if one appears |
| building a command line from strings (cmd style) | **not done**; git gets arguments as separate values (`@GitArgs`), so a folder named `x & del *` is just a name |
| `cmd /c`, `Start-Process` with folder names | not used |
| the move list running code | it's data: hashtables of strings; nothing in it is executed |
| a malicious repo's git config (`core.fsmonitor`, hooks) running when git is called | `git status` can run `core.fsmonitor`, which is a real git behaviour. Only move **your own** repos. Git's `safe.directory` check refuses repos owned by another user |
| a tampered copy of this script | read a script before running it; `-ExecutionPolicy Bypass` is per process, and the execution policy is not a security boundary anyway |
| `main.py` | runs fixed commands (`powershell`, `devtools`) with argument lists, no shell, no user input |

## Review table

| Finding | Fix | Test |
| --- | --- | --- |
| v1 could stop halfway through the list (checked while moving) | v2 checks everything first | `the good move did not happen either` |
| v1 ignored git exit codes | `Get-GitLine` | (manual) |
| `2>&1` with `Stop` throws on git warnings in 5.1 (verified: `RemoteException`) | no stderr redirect | (verified once by hand; see [PS1_VS_BAT.md](PS1_VS_BAT.md)) |
| a mutation run escaped into `%TEMP%` | test root nested in a test-owned folder | mutation run leaves `%TEMP%` clean |
| a moved venv's launchers point at the old path | print the repair, don't auto-run it | manual |

## Publishing this repo

Before the first public push:

- the example and docs use **made-up folder names** (`Project_A`,
  `Group_1`); the real folders this script moved aren't named
- no user name, home path or email in files (`devtools scan` checks this)
- `git log` holds only this repo's own commits (a fresh repo, no imported history)
- LICENSE (MIT); GitHub private vulnerability reporting, Dependabot alerts
  and secret-scanning push protection turned on

## Accepted risks

- **Power cut during phase 3**: moves already done stay done, the rest don't
  happen; each single move is still all-or-nothing. Running again finishes
  the job (moves already done are skipped).
- **Junctions/symlinks inside the root** that point to another drive would
  make a "move" a copy and delete. Not handled: these folders don't use them.
- **OneDrive** may still be syncing; the rename is local and OneDrive then
  syncs it as a move.

## References

### Official

- Microsoft Learn: [about_Execution_Policies](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies) ✔, [PowerShell security features](https://learn.microsoft.com/powershell/scripting/security/security-features)
- Git: [git-config core.fsmonitor and safe.directory](https://git-scm.com/docs/git-config)
- OWASP: [Path traversal](https://owasp.org/www-community/attacks/Path_Traversal), [Command injection](https://owasp.org/www-community/attacks/Command_Injection)
- GitHub Docs: [Private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/working-with-repository-security-advisories/configuring-private-vulnerability-reporting-for-a-repository), [Push protection](https://docs.github.com/en/code-security/secret-scanning/introduction/about-push-protection)

### Further learning

- Microsoft Learn: [Avoid using Invoke-Expression](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/avoid-using-invoke-expression)
