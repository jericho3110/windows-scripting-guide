# Windows Scripting Guide

How a small, safe PowerShell script was designed, written, tested and run,
and why it's PowerShell and not a `.bat` file. The script moves and renames
folders, git repos included, without ever leaving a half-moved mess.

## Contents

- [Quick start](#quick-start)
- [What the script guarantees](#what-the-script-guarantees)
- [Layout](#layout)
- [Tests and checks](#tests-and-checks)
- [Documentation](#documentation)

## Quick start

1. Copy [`scripts/move_folders.ps1`](scripts/move_folders.ps1) into the folder whose subfolders you want to reorganise.
2. Edit the `$Moves` list at the top (`From` and `To` are relative to that folder).
3. Close VS Code (and anything else with those folders open).
4. Run it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\move_folders.ps1
```

| Flag | Meaning |
| --- | --- |
| `-NoProfile` | don't load your PowerShell profile: a clean, predictable start |
| `-ExecutionPolicy Bypass` | allow this script to run, **for this one process only**; nothing is saved |
| `-File` | run this script file, then exit with its exit code |

It prints the plan and asks you to type `yes`. Exit codes: `0` done, `1`
refused or cancelled (nothing changed), `2` moved but with warnings.

## What the script guarantees

- **all checks before any move**: one problem means nothing moves
- refuses while VS Code runs, refuses dirty repos, never overwrites
- paths can't leave the folder (`..` and absolute paths are refused)
- each move is one rename: all or nothing, never copy + delete
- repos checked afterwards (still clean, same remote); running twice is harmless

Why each rule exists: [docs/WRITING_THE_SCRIPT.md](docs/WRITING_THE_SCRIPT.md).

## Layout

```text
scripts/move_folders.ps1      the tool
tests/test_move_folders.ps1   17 behaviour tests in a throwaway folder
main.py                       the check gate: python main.py check
docs/                         the guides below
```

## Tests and checks

```powershell
python main.py check
```

Runs, in order: PowerShell's parser on every `.ps1` (syntax only, nothing
executed), the 17 tests, the `devtools scan` security sweep (secrets,
personal data, dangerous patterns like `Invoke-Expression`) and a link
check. Each step passes or fails by its **exit code**. `devtools` comes
from the author's `mr-factory-workspace` repo; without it those two steps
show `SKIPPED`.

Tests alone: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_move_folders.ps1`

Requirements: Windows with Windows PowerShell 5.1 (built in) and git.

## Documentation

| Doc | What's in it |
| --- | --- |
| [docs/PS1_VS_BAT.md](docs/PS1_VS_BAT.md) | **why PowerShell, not batch**: three batch pitfalls seen live, BatBadBut, side-by-side code, what PowerShell costs |
| [docs/WRITING_THE_SCRIPT.md](docs/WRITING_THE_SCRIPT.md) | **the process**: problem → failure modes → rules → shape → code walk-through → tests → real run → the venv repair |
| [docs/POWERSHELL_CONCEPTS.md](docs/POWERSHELL_CONCEPTS.md) | every language feature, cmdlet and .NET call used, with Python equivalents |
| [docs/SECURITY.md](docs/SECURITY.md) | threat model, defenses ↔ tests, every RCE path, accepted risks |
| [docs/LEARNING_PATH.md](docs/LEARNING_PATH.md) | a reading order with exercises |
| [docs/GLOSSARY.md](docs/GLOSSARY.md) | terms in one table |
| [CHANGELOG.md](CHANGELOG.md) | versions |

Related: [command-line-field-guide](https://github.com/jericho3110/command-line-field-guide)
(Git, regex and shell, including moving repos).

## License

[MIT](LICENSE)
