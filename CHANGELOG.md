# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions: [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-10-11

### Fixed
- `WRITING_THE_SCRIPT.md` §8 said `python -m venv --upgrade` rewrites the activate scripts. It doesn't (`venv/__init__.py` skips `setup_scripts` when upgrading); found on a second real move. The section now says so and gives the fix.
- The venv repair hint printed by `move_folders.ps1` now uses `pip freeze --all`: without it pip itself is left out and `pip.exe` stays broken.

## [0.1.0] - 2026-10-11

### Added
- `scripts/move_folders.ps1` (version 2 of a script used for a real reorganisation): checks every move first, refuses while VS Code runs, refuses dirty repos, keeps paths inside the root, asks before acting, renames only, verifies repos, prints the venv repair.
- `tests/test_move_folders.ps1`: 17 checks in a throwaway folder; `main.py check` (parse, tests, security scan, links).
- Docs: PS1_VS_BAT (with live batch pitfalls), WRITING_THE_SCRIPT (the whole process, including what went wrong), POWERSHELL_CONCEPTS, SECURITY, LEARNING_PATH, GLOSSARY.
