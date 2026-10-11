# Writing the script: from problem to tested tool

How [`scripts/move_folders.ps1`](../scripts/move_folders.ps1) was thought
out and written, in the order it really happened, including what went wrong.

## Contents

- [1. The problem](#1-the-problem)
- [2. What could go wrong (before writing any code)](#2-what-could-go-wrong-before-writing-any-code)
- [3. Rules that follow from the risks](#3-rules-that-follow-from-the-risks)
- [4. The shape: check, confirm, act, verify](#4-the-shape-check-confirm-act-verify)
- [5. Walk-through, section by section](#5-walk-through-section-by-section)
- [6. Testing it](#6-testing-it)
- [7. Running it for real](#7-running-it-for-real)
- [8. The venv](#8-the-venv)
- [9. Version 1 vs version 2](#9-version-1-vs-version-2)
- [10. The process, as a checklist](#10-the-process-as-a-checklist)
- [Exercises](#exercises)
- [References](#references)

## 1. The problem

A projects folder had grown messy. The plan was four moves:

```text
Project_A/        -> Group_1/Project_A/      (git repo)
Private_Data/     -> Group_1/Private_Data/   (personal data, NOT a repo, never in git)
Project_B/        -> Group_2/Project_B/      (git repo with a Python .venv)
Old_Guide/        -> New_Guide/              (git repo, renamed)
```

The obvious tool, `mv` in Git Bash, failed straight away:

```text
$ mv Project_A Group_1/
mv: cannot move 'Project_A' to 'Group_1/Project_A': Permission denied
```

On Windows, **a folder can't be renamed while any program has a handle
open inside it**. VS Code watches every folder in the workspace for changes,
and OneDrive syncs it. The move had to happen with the editor closed, so the
assistant couldn't do it from inside the editor. It had to be **a script the
owner runs**, which raised the bar: the script would run unattended, on real
data, with nobody watching for odd output.

## 2. What could go wrong (before writing any code)

Listing the failure modes first is the most important step. Code written
before this list tends to handle the happy path only.

| # | Failure | Damage |
| --- | --- | --- |
| F1 | a folder is locked, and the move half-works | **two partial copies**; which one is real? |
| F2 | a repo has uncommitted work | work is mixed into a confusing state, or lost if someone "cleans up" |
| F3 | the destination already exists | overwritten or merged data |
| F4 | the script stops halfway through the list | some moves done, some not: an unclear state |
| F5 | a path in the list is wrong (`..\..`, `C:\`) | files moved **outside** the projects folder |
| F6 | it's run twice | the second run errors, or does something odd |
| F7 | the move "worked" but the repo is broken | discovered weeks later |
| F8 | a Python venv stops working | its programs point at the old path |
| F9 | the person running it didn't mean to | the wrong folders moved |

## 3. Rules that follow from the risks

Each rule exists because of a row above:

| Rule | Guards against | How |
| --- | --- | --- |
| **never copy + delete; rename only** | F1 | `Move-Item` on the same volume is a single rename by the file system: it **fully happens or doesn't happen** (atomic) |
| refuse while lockers run | F1 | `Get-Process -Name Code` |
| refuse dirty repos | F2 | `git status --porcelain` must print nothing |
| never overwrite | F3 | stop if the destination exists |
| **check everything before acting** | F4 | phase 1 validates the whole list; one problem means *zero* moves |
| paths must stay inside the root | F5 | `Resolve-Inside` (a **trust boundary**) |
| skip what's already done | F6 | source gone + destination present = "already done" (**idempotent**) |
| verify after each move | F7 | same remote, still clean |
| say what needs fixing | F8 | print the venv repair commands |
| show the plan, ask, default "no" | F9 | `Read-Host`, anything except `yes` cancels |

Two principles sit under all of this:

- **Fail closed**: when unsure, stop and change nothing. Every error path
  calls `Stop-Script`, which exits *before* anything moves.
- **Fail early**: all the checks that can fail happen first, while stopping
  is still free.

## 4. The shape: check, confirm, act, verify

```text
          +------------------+   any problem   +-------------------------+
 list --> | 1. CHECK all     | --------------> | stop, nothing changed   |
          +------------------+                 +-------------------------+
                   | plan (objects)
                   v
          +------------------+   not "yes"     +-------------------------+
          | 2. SHOW + ASK    | --------------> | cancel, nothing changed |
          +------------------+                 +-------------------------+
                   v
          +------------------+
          | 3. MOVE one by   |  each: one rename, then git status + remote check
          |    one, VERIFY   |
          +------------------+
                   v
             summary + exit code (0 ok, 1 refused, 2 moved with warnings)
```

This is the pattern behind `terraform plan` / `apply`, database migrations
with a dry run, and package managers that print "the following packages
will be installed". The **plan** is plain data (a list of
`[pscustomobject]`s), built by code that changes nothing. Only phase 3
touches the disk. That split is a small version of **functional core,
imperative shell**: decide first (pure), then act (side effects) in one
small place.

Exit codes follow the Unix convention (0 = success) so another script or a
test can check the result without reading the text.

## 5. Walk-through, section by section

### The header and `param()`

```powershell
param(
    [string]$Root = $PSScriptRoot,
    [hashtable[]]$Moves = @( @{ From = 'Old_Name'; To = 'New_Name' }, ... ),
    [string[]]$LockingApps = @('Code'),
    [switch]$Yes
)
```

- The first version had the folder list and `Code` **hard-coded**. Making
  them parameters with defaults costs nothing for the normal run and lets
  the tests point the script at a throwaway folder (**dependency
  injection**, the simple kind: pass in what you depend on).
- `$PSScriptRoot` is the folder the script file is in, so by default the
  paths are relative to where the script sits, not to wherever the shell
  happened to be.
- `[switch]$Yes` is a flag (present = true). It skips the prompts so tests
  can run without a person.

### `$ErrorActionPreference = 'Stop'`

By default PowerShell prints an error and **carries on** with the next
line. `Stop` turns cmdlet errors into exceptions that end the script. It's
the PowerShell equivalent of `set -e` in Bash. It does **not** cover
external programs like `git` in Windows PowerShell 5.1, so those are checked
by hand (next section).

### `Stop-Script`, `Resolve-Inside`, `Get-GitLine`

- `Stop-Script` is the single exit for every refusal: red message, pause if
  a person is watching, `exit 1`. One function means one consistent rule.
- `Resolve-Inside` is the **trust boundary**. The move list is input, so it
  is checked like input: it must be relative, and after resolving `..` with
  `[IO.Path]::GetFullPath` it must still start with `root\`. The trailing
  `\` matters: without it, a root of `C:\Projects` would accept
  `C:\Projects-evil`.
- `Get-GitLine` runs git and checks `$LASTEXITCODE`, because a failing git
  doesn't throw (see [PS1_VS_BAT.md §4](PS1_VS_BAT.md#4-what-powershell-costs)).
  It deliberately does **not** use `2>&1`. In 5.1 with `Stop`, a redirected
  stderr line throws a `RemoteException` even when git succeeded. That was
  verified on this machine before it was written down.

### Phase 1: check

For each move: resolve both paths; work out "already done", "missing" or
"both exist"; refuse moving a folder into itself; and, if it has a `.git`
folder, require git, a clean `status`, and remember `git remote -v`. The
result is a **plan**: one object per move still to do.

Repos are detected (`Test-Path .git`) rather than declared. Version 1 had a
`Repo = $true` flag per move, which can be set wrong; detection can't.

### Phase 2: show and ask

The plan is printed, then `Read-Host 'Type yes to move'`. Typing exactly
`yes` is required; Enter, `y` or anything else cancels. The default is the
safe answer.

### Phase 3: move and verify

```powershell
New-Item -ItemType Directory -Force -Path (Split-Path $p.ToPath -Parent) | Out-Null
Move-Item -LiteralPath $p.FromPath -Destination $p.ToPath
```

- `New-Item -Force` creates the parent group folder if it's missing (and is
  harmless if it exists). `| Out-Null` discards the object it returns.
- `-LiteralPath` means `[` `]` `*` `?` in a folder name are just
  characters, not wildcards.
- Then `git status` and `git remote -v` again: the same answers as before
  prove the repo came through intact.

## 6. Testing it

Three layers, cheapest first:

1. **Parse check.** PowerShell's own parser reads the file and reports
   syntax errors without running anything:
   `[System.Management.Automation.Language.Parser]::ParseFile(...)`.
   `python main.py check` does this for every `.ps1`.
2. **Behaviour tests.** [`tests/test_move_folders.ps1`](../tests/test_move_folders.ps1)
   builds a throwaway folder with real git repos and runs the script in 17
   checks: moves work, the repo stays clean with the same remote, a second
   run is harmless, one dirty repo stops *every* move, no overwriting,
   `..`, absolute paths, the root itself and "into itself" are refused, and
   a running "locking app" blocks it. (The test uses its own PowerShell
   process as the locking app, so it needs no editor.)
3. **Mutation test: do the tests actually catch bugs?** The root check was
   switched off on purpose, then the tests were run. Three failed, which is
   good: the tests bite. The script was then restored and compared byte for
   byte.

### Found live: the mutation escaped

With the root check off, the broken script did what it was told and moved a
test folder to `%TEMP%\escaped`, **outside the test sandbox**. It was empty
and was removed, but it showed a flaw in the test: an escape test needs
somewhere safe to escape *to*. Fix: the test root now sits inside a second
test-owned folder (`move-folders-test-<guid>\root`), and `finally` deletes
the outer one. Re-running the mutation left nothing in `%TEMP%`. Lesson:
**when you test a safety check, assume it's broken and contain the
damage.**

## 7. Running it for real

The owner closed VS Code, ran version 1, and reopened. Afterwards every
repo was checked:

| Check | Result |
| --- | --- |
| old paths gone, new paths present | yes, all four |
| `git status` | nothing to commit, in every repo |
| `git log -1` | the same commit as before the move |
| `git remote -v` | the same GitHub URLs |

Git needed **no** commands at all: a repo is just a folder with `.git`
inside, and nothing in `.git` stores its own location.

## 8. The venv

One thing did break, as predicted (F8). A Python virtual environment's
launchers (`pip.exe`, `yt-dlp.exe`, …) contain the **absolute path** of the
venv's `python.exe`; Python's docs call venvs "inherently non-portable".
After the move they exited with code 1 and printed nothing.

Version 1 tried to rebuild it automatically with
`python -m venv --clear .venv`, but the launchers were still broken
afterwards. Re-running that command by hand showed why: **Access is
denied**, because `--clear` deletes the venv folder's contents and the
reopened editor was locking it again. The repair that worked, done in place:

```text
python -m venv --upgrade .venv
    # rewrites pyvenv.cfg and the activate scripts for the new location
.venv\Scripts\python -m pip freeze --exclude-editable > freeze.txt
    # the exact versions installed now (minus the project's own editable install)
.venv\Scripts\python -m pip install --force-reinstall --no-deps -r freeze.txt
    # reinstall the same versions; this regenerates every launcher
```

Afterwards every launcher exited 0. `--no-deps` with a frozen list means
nothing is upgraded by surprise. Version 2 **prints** these commands
instead of running them. They need the network and can fail in ways a
person should see, so the script stays an offline tool that only renames.

## 9. Version 1 vs version 2

| | v1 (ran once, for real) | v2 (this repo) |
| --- | --- | --- |
| folder list | hard-coded | `-Moves` parameter |
| repo or not | declared per move | detected (`.git`) |
| validation | per move, **while moving** (could stop halfway) | **all first**, then act |
| path safety | none needed (fixed list) | `Resolve-Inside` trust boundary |
| confirmation | none | plan + "type yes" |
| git errors | unchecked | `$LASTEXITCODE` checked |
| venv | tried to rebuild (didn't work) | prints the repair |
| tests | parse check only | 17 behaviour tests + a mutation run |

Version 1 worked, but it was safe mostly because its list was fixed and
known to be valid. Version 2 is safe for *any* list, which is what a
reusable tool needs.

## 10. The process, as a checklist

1. Reproduce the problem by hand, and read the real error.
2. Write down the **failure modes** before any code.
3. Turn each into a **rule**, and each rule into a check.
4. Choose the shape: **check all → show → confirm → act → verify**.
5. Write the smallest script that does that. Name the gotchas in comments.
6. Make what it depends on into parameters, so it can be tested.
7. Test: parse → behaviour → **break it on purpose** and watch the tests fail.
8. Run it for real, then **verify independently** (`git status`, `log`, `remote`).
9. Write down what surprised you ("found live"), then fix the tool or the test.

## Exercises

1. Add a `-WhatIf`-style `-DryRun` switch that prints the plan and exits 0. Add a test for it.
2. Make the script refuse when the source and destination are on **different drives** (hint: `[IO.Path]::GetPathRoot`). Why does this matter for rule 1?
3. Remove the trailing `'\'` in `Resolve-Inside` and write a test with a sibling folder `root-evil` that catches it.
4. Change phase 3 so that, if one move throws, the script prints which moves were already done.

**Self-check:** why does checking every move *before* doing any make a
half-finished state impossible for refusals, but not for a power cut during
phase 3?

## References

### Official

- Microsoft Learn: [about_Preference_Variables ($ErrorActionPreference)](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_preference_variables) ✔, [about_Automatic_Variables ($PSScriptRoot, $LASTEXITCODE)](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_automatic_variables), [about_Functions_Advanced_Parameters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_functions_advanced_parameters)
- Microsoft Learn: [Move-Item](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/move-item), [Get-Process](https://learn.microsoft.com/powershell/module/microsoft.powershell.management/get-process), [Parser.ParseFile](https://learn.microsoft.com/dotnet/api/system.management.automation.language.parser.parsefile)
- .NET: [Path.GetFullPath](https://learn.microsoft.com/dotnet/api/system.io.path.getfullpath)
- Win32: [MoveFileEx](https://learn.microsoft.com/windows/win32/api/winbase/nf-winbase-movefileexa) (a same-volume move is a rename; across volumes it must copy)
- Python: [venv: "inherently non-portable"](https://docs.python.org/3/library/venv.html) ✔; pip: [pip freeze](https://pip.pypa.io/en/stable/cli/pip_freeze/), [pip install --force-reinstall](https://pip.pypa.io/en/stable/cli/pip_install/)
- Git: [git-status --porcelain](https://git-scm.com/docs/git-status)

### Other explanations

- OWASP: [Path traversal](https://owasp.org/www-community/attacks/Path_Traversal)
- Wikipedia: [Mutation testing](https://en.wikipedia.org/wiki/Mutation_testing)
- Gary Bernhardt: [Functional core, imperative shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)

### Further learning

- [Pester](https://pester.dev/docs/quick-start), the PowerShell test framework, for when plain test scripts get big
- Microsoft Learn: [Everything you wanted to know about exceptions](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-exceptions)
