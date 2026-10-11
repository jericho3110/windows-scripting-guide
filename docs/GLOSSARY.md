# Glossary

| Term | Meaning | Explained in |
| --- | --- | --- |
| atomic | happens completely or not at all; a same-volume rename is atomic | [WRITING_THE_SCRIPT.md §3](WRITING_THE_SCRIPT.md#3-rules-that-follow-from-the-risks) |
| BatBadBut | CVE-2024-24576: argument escaping for `.bat` files can't be made safe in general | [PS1_VS_BAT.md §2](PS1_VS_BAT.md#2-seen-live-three-batch-pitfalls) |
| cmdlet | a PowerShell command named `Verb-Noun` | [POWERSHELL_CONCEPTS.md §1](POWERSHELL_CONCEPTS.md#1-the-mental-model-objects-in-a-pipeline) |
| delayed expansion | cmd's `!VAR!`, evaluated at run time instead of read time | [PS1_VS_BAT.md §2](PS1_VS_BAT.md#2-seen-live-three-batch-pitfalls) |
| execution policy | PowerShell's rule for which scripts may run; defense in depth, not a security boundary | [PS1_VS_BAT.md §4](PS1_VS_BAT.md#4-what-powershell-costs) |
| exit code | a number a program returns: 0 = success | [WRITING_THE_SCRIPT.md §4](WRITING_THE_SCRIPT.md#4-the-shape-check-confirm-act-verify) |
| fail closed | when unsure, stop and change nothing | [WRITING_THE_SCRIPT.md §3](WRITING_THE_SCRIPT.md#3-rules-that-follow-from-the-risks) |
| functional core, imperative shell | decide in pure code, act in one small place | [WRITING_THE_SCRIPT.md §4](WRITING_THE_SCRIPT.md#4-the-shape-check-confirm-act-verify) |
| idempotent | running it again changes nothing more | [WRITING_THE_SCRIPT.md §3](WRITING_THE_SCRIPT.md#3-rules-that-follow-from-the-risks) |
| injection | data treated as part of a command | [PS1_VS_BAT.md §2](PS1_VS_BAT.md#2-seen-live-three-batch-pitfalls), [SECURITY.md](SECURITY.md#rce-every-way-code-could-run) |
| `-LiteralPath` | a path with no wildcards | [POWERSHELL_CONCEPTS.md §3](POWERSHELL_CONCEPTS.md#3-cmdlets) |
| mutation test | break the code on purpose to check that the tests notice | [WRITING_THE_SCRIPT.md §6](WRITING_THE_SCRIPT.md#6-testing-it) |
| path traversal | escaping a folder with `..` or an absolute path | [SECURITY.md](SECURITY.md#defenses) |
| splatting | `@args`: spread an array or hashtable as arguments | [POWERSHELL_CONCEPTS.md §2](POWERSHELL_CONCEPTS.md#2-language-features) |
| trust boundary | where input is checked before it's used | [WRITING_THE_SCRIPT.md §5](WRITING_THE_SCRIPT.md#5-walk-through-section-by-section) |
| venv | a Python virtual environment; not portable between paths | [WRITING_THE_SCRIPT.md §8](WRITING_THE_SCRIPT.md#8-the-venv) |

## References

### Official

- Microsoft Learn: [PowerShell glossary](https://learn.microsoft.com/powershell/scripting/learn/glossary)

### Further learning

- OWASP: [Attacks](https://owasp.org/www-community/attacks/)
