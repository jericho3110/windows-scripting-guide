# Why `.ps1` and not `.bat`?

A `.bat` file is run by **cmd.exe**, the Windows shell inherited from
MS-DOS. A `.ps1` file is run by **PowerShell**. Both can move folders. For
the folder move this repo is about, PowerShell won on every point that
matters for **not losing data**.

## Contents

- [1. The short answer](#1-the-short-answer)
- [2. Seen live: three batch pitfalls](#2-seen-live-three-batch-pitfalls)
- [3. Side by side](#3-side-by-side)
- [4. What PowerShell costs](#4-what-powershell-costs)
- [5. When a .bat is still the right choice](#5-when-a-bat-is-still-the-right-choice)
- [6. Other options](#6-other-options)
- [References](#references)

## 1. The short answer

| Need | cmd (`.bat`) | PowerShell (`.ps1`) |
| --- | --- | --- |
| stop on the first error | no such switch; you check `ERRORLEVEL` after every line | `$ErrorActionPreference = 'Stop'` once, then `try`/`catch`/`finally` |
| variables | text, expanded **when the line is read** (`%X%`), so loops need `setlocal EnableDelayedExpansion` and `!X!` | real variables, evaluated when the line runs |
| data with `& | < > ^ %` in it | becomes **part of the command** (injection) | stays data |
| paths | quoting by hand | `-LiteralPath`, `Join-Path`, `[IO.Path]` |
| "is VS Code running?" | parse `tasklist` text | `Get-Process -Name Code`, which returns objects |
| lists and records | none (only text) | arrays, hashtables, objects |
| functions with parameters | `call :label` plus `%1` | `function`, `param()`, types, defaults |
| tests | hard | ordinary scripts (`tests/`), or the Pester framework |

In one sentence: **cmd treats everything as text to paste into the next
command; PowerShell passes values.** Text pasting is where both the bugs and
the security holes come from.

## 2. Seen live: three batch pitfalls

This was run on this PC (`cmd /c demo.bat`), Windows 11:

```bat
@echo off
set COUNT=0
for %%f in (a b c) do (
  set /a COUNT+=1
  echo inside loop: %COUNT%
)
echo after loop: %COUNT%
set NAME=Tom ^& Jerry
echo name is %NAME%
move no_such_folder_xyz elsewhere >nul 2>&1
echo move exit: %ERRORLEVEL%
```

Real output:

```text
inside loop: 0
inside loop: 0
inside loop: 0
after loop: 3
name is Tom
'Jerry' is not recognized as an internal or external command,
operable program or batch file.
move exit: 1
```

1. **`0, 0, 0`, then `3`.** cmd reads the whole `( … )` block and replaces
   `%COUNT%` *once, before running it*. The fix (`setlocal
   EnableDelayedExpansion` and `!COUNT!`) is a second syntax with its own
   rules: a `!` in a file name then disappears.
2. **`'Jerry' is not recognized`.** The *value* of a variable contained
   `&`, and cmd ran the part after it as a new command. If a folder name
   came from a list, a file or a user, that is **command injection**. Here
   it ran a harmless missing program; it could have run `del`.
3. **The failed `move` didn't stop the script.** It set `ERRORLEVEL` to 1
   and carried on. Every later line would run against a half-finished state
   unless you write `if errorlevel 1 exit /b 1` after each command (and
   `if errorlevel 1` means "1 **or more**", another trap).

The same three in PowerShell:

```powershell
$count = 0
foreach ($f in 'a', 'b', 'c') { $count++; "inside loop: $count" }   # 1, 2, 3
$name = 'Tom & Jerry'; "name is $name"                                # name is Tom & Jerry
$ErrorActionPreference = 'Stop'
Move-Item -LiteralPath no_such_folder_xyz -Destination elsewhere      # throws; the script stops here
```

### The famous case: BatBadBut (CVE-2024-24576)

In April 2024 the Rust project rated a bug **critical**: a Rust program that
ran a `.bat` file with untrusted arguments could be made to run arbitrary
commands, because cmd.exe splits arguments by its own rules. The advisory
says: *"Due to the complexity of cmd.exe, we didn't identify a solution that
would correctly escape arguments in all cases."* The same class of bug was
found in several other languages' standard libraries at the time. If the
experts can't escape cmd reliably, a folder-moving script shouldn't try.

## 3. Side by side

One move, with the checks the real script needs: stop if the destination
exists, stop if the move fails.

```bat
@echo off
setlocal
if exist "Group\Proj" (echo destination exists & exit /b 1)
if not exist "Group" mkdir "Group"
if errorlevel 1 exit /b 1
move "Proj" "Group\Proj" >nul
if errorlevel 1 (echo move failed & exit /b 1)
git -C "Group\Proj" status --porcelain > "%TEMP%\st.txt"
for %%A in ("%TEMP%\st.txt") do if %%~zA GTR 0 echo WARNING: changes after move
```

```powershell
$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath 'Group\Proj') { throw 'destination exists' }
New-Item -ItemType Directory -Force -Path 'Group' | Out-Null
Move-Item -LiteralPath 'Proj' -Destination 'Group\Proj'
if (git -C 'Group\Proj' status --porcelain) { Write-Warning 'changes after move' }
```

The batch version needs a temp file and the `%%~zA` "file size" modifier just
to ask "did git print anything?". In PowerShell the output of `git` *is* a
value you can test.

## 4. What PowerShell costs

Nothing is free. The costs, and what this repo does about each:

| Cost | Detail | What we do |
| --- | --- | --- |
| **execution policy** | double-clicking a `.ps1` opens it in Notepad instead of running it, and with no policy set Windows clients use `Restricted` (no scripts) | run it as `powershell -ExecutionPolicy Bypass -File …`: **Bypass for that one process only**, nothing saved. (This PC already has `CurrentUser = RemoteSigned`.) The policy is not a security wall: Microsoft calls it "defense in depth", not a "security boundary" |
| **two PowerShells** | Windows PowerShell **5.1** (`powershell.exe`, built into Windows, no longer gets new features) and PowerShell **7** (`pwsh.exe`, cross-platform, installed separately) behave differently in places | the script targets 5.1, since every Windows PC has it, and avoids 7-only syntax (`&&`, `??`, ternary) |
| **5.1 stderr gotcha** | with `$ErrorActionPreference = 'Stop'`, `git … 2>&1` **throws** as soon as git writes anything to stderr, even a warning. Verified here: `THREW: RemoteException`. PowerShell 7.2+ changed this | `Get-GitLine` doesn't redirect stderr; it checks `$LASTEXITCODE` instead |
| **native exit codes** | a failing `git` does **not** stop a 5.1 script, even with `Stop`; only cmdlets do (7.4 added `$PSNativeCommandUseErrorActionPreference`) | `Get-GitLine` checks `$LASTEXITCODE` after every git call |
| startup time | ~0.3–1 s vs instant for cmd | irrelevant for a one-off move |
| verbosity | `Move-Item -LiteralPath` vs `move` | it's readable, and `-LiteralPath` is safer (no wildcards: `[` and `]` are literal) |

## 5. When a .bat is still the right choice

- A **one-line launcher**, e.g. `run.bat` containing
  `powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0move_folders.ps1"`
  so it can be double-clicked. (`%~dp0` = "the folder this .bat is in".)
- Very old or locked-down machines where PowerShell is disabled.
- Tiny scripts with no variables, no loops and no untrusted data.

## 6. Other options

| Tool | Good at | Why not here |
| --- | --- | --- |
| **Python** (`shutil.move`, `pathlib`) | cross-platform, the language these projects use | `shutil.move` **copies and then deletes** when a rename fails (e.g. across drives), which is exactly the failure mode we wanted to avoid; needs Python installed |
| **Git Bash** (`mv`) | familiar Unix commands | it's what failed first ("Permission denied"); it's an emulation layer over Windows |
| **PowerShell 7** | modern, fixes the stderr gotcha | not installed by default |

Rule of thumb: **cmd for launching, PowerShell for Windows system work,
Python for programs.**

## References

### Official

- Microsoft Learn: [about_Execution_Policies](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_execution_policies) ✔ ("isn't a security boundary, it's defense in depth"; Restricted when undefined on clients; Process scope)
- Microsoft Learn: [about_Preference_Variables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_preference_variables) ✔ (7.2 stderr redirection change; `$PSNativeCommandUseErrorActionPreference`)
- Microsoft Learn: [Differences between Windows PowerShell 5.1 and PowerShell 7](https://learn.microsoft.com/powershell/scripting/whats-new/differences-from-windows-powershell)
- Microsoft Learn: [setlocal](https://learn.microsoft.com/windows-server/administration/windows-commands/setlocal) (delayed expansion), [if](https://learn.microsoft.com/windows-server/administration/windows-commands/if) (`errorlevel` means "or greater"), [move](https://learn.microsoft.com/windows-server/administration/windows-commands/move)
- Rust security advisory: [CVE-2024-24576 / GHSA-q455-m56c-85mh](https://github.com/rust-lang/rust/security/advisories/GHSA-q455-m56c-85mh) ✔
- Python: [shutil.move](https://docs.python.org/3/library/shutil.html#shutil.move) (falls back to copy then remove)

### Other explanations

- Flatt Security: [BatBadBut: You can't securely execute commands on Windows](https://flatt.tech/research/posts/batbadbut-you-cant-securely-execute-commands-on-windows/)
- SS64: [cmd delayed expansion](https://ss64.com/nt/delayedexpansion.html)

### Further learning

- Microsoft Learn: [PowerShell 101](https://learn.microsoft.com/powershell/scripting/learn/ps101/00-introduction)
- Don Jones & Jeffery Hicks, *Learn PowerShell in a Month of Lunches* (Manning)
- [Exercism PowerShell track](https://exercism.org/tracks/powershell)
