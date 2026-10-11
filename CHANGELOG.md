# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions: [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-11

### Added
- `scripts/move_folders.ps1` (version 2 of a script used for a real reorganisation): checks every move first, refuses while VS Code runs, refuses dirty repos, keeps paths inside the root, asks before acting, renames only, verifies repos, prints the venv repair.
- `tests/test_move_folders.ps1`: 17 checks in a throwaway folder; `main.py check` (parse, tests, security scan, links).
- Docs: PS1_VS_BAT (with live batch pitfalls), WRITING_THE_SCRIPT (the whole process, including what went wrong), POWERSHELL_CONCEPTS, SECURITY, LEARNING_PATH, GLOSSARY.
