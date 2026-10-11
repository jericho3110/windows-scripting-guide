# Learning path

Read in this order. Each stage has an exercise and a self-check question.

| Stage | Read | Concepts | Exercise | Self-check |
| --- | --- | --- | --- | --- |
| 1. Why not batch | [PS1_VS_BAT.md](PS1_VS_BAT.md) §1–2 | text vs objects, parse-time expansion, injection | run the demo from §2 yourself (save it as `demo.bat`, run `cmd /c demo.bat`) | why did `Jerry` run as a command? |
| 2. The costs | [PS1_VS_BAT.md](PS1_VS_BAT.md) §4–6 | execution policy, 5.1 vs 7, native exit codes | run `Get-ExecutionPolicy -List` and explain each row | is the execution policy a security boundary? |
| 3. Think before code | [WRITING_THE_SCRIPT.md](WRITING_THE_SCRIPT.md) §1–4 | failure modes, fail closed, check→confirm→act→verify, idempotency | list five failure modes for a "delete old log files" script | what makes running the move script twice harmless? |
| 4. The code | [the script](../scripts/move_folders.ps1) with [POWERSHELL_CONCEPTS.md](POWERSHELL_CONCEPTS.md) | `param`, hashtables, splatting, scopes, `-LiteralPath`, `$LASTEXITCODE` | `Get-Help .\scripts\move_folders.ps1 -Full` | why does `Get-GitLine` not use `2>&1`? |
| 5. Tests | [WRITING_THE_SCRIPT.md](WRITING_THE_SCRIPT.md) §6, [the tests](../tests/test_move_folders.ps1) | sandboxed tests, mutation testing | break one check in the script, run the tests, restore it | why is the test root nested inside another folder? |
| 6. Real life | [WRITING_THE_SCRIPT.md](WRITING_THE_SCRIPT.md) §7–10, [SECURITY.md](SECURITY.md) | verification, venv portability, threat model | do exercise 1 or 2 from WRITING_THE_SCRIPT.md | which risk is accepted, and why? |

## References

### Official

- Microsoft Learn: [PowerShell 101](https://learn.microsoft.com/powershell/scripting/learn/ps101/00-introduction), [Get-Help](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/get-help)

### Further learning

- [Exercism PowerShell track](https://exercism.org/tracks/powershell)
- [Pester quick start](https://pester.dev/docs/quick-start)
