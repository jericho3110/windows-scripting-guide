# PowerShell concepts used in this repo

Every language feature, cmdlet and .NET class in
[`move_folders.ps1`](../scripts/move_folders.ps1) and
[`test_move_folders.ps1`](../tests/test_move_folders.ps1): what it is,
where it's used, why, and the gotcha. Python equivalents are given where
they help.

## Contents

- [1. The mental model: objects in a pipeline](#1-the-mental-model-objects-in-a-pipeline)
- [2. Language features](#2-language-features)
- [3. Cmdlets](#3-cmdlets)
- [4. .NET classes called directly](#4-net-classes-called-directly)
- [5. Running external programs (git)](#5-running-external-programs-git)
- [6. Memory and paradigm](#6-memory-and-paradigm)
- [7. Python side by side](#7-python-side-by-side)
- [Exercises](#exercises)
- [References](#references)

## 1. The mental model: objects in a pipeline

Bash and cmd pass **text** from one command to the next. PowerShell passes
**.NET objects**. `Get-Process -Name Code` returns `Process` objects with
`.Name`, `.Id`, `.StartTime` and so on, so there's nothing to parse.

Commands are **cmdlets** named `Verb-Noun` (`Move-Item`, `Test-Path`), with
a fixed list of approved verbs (`Get-Verb` lists them). Parameters start
with `-` and can be shortened if unambiguous, but scripts should spell them
out.

## 2. Language features

| Feature | Where | What / why | Gotcha |
| --- | --- | --- | --- |
| `<# … #>` comment-based help | top of the script | `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`; `Get-Help .\move_folders.ps1` shows it, like a Python docstring | must come first, or right before `param` |
| `param( … )` | script top | the script's parameters, with types and defaults, like a `def main(root=..., moves=...)` | only one `param` block, at the top |
| `[string]`, `[hashtable[]]`, `[string[]]` | `param` | type constraints: values are converted or rejected on the way in | `[string]$x = $null` becomes `''` |
| `[switch]` | `$Yes` | an on/off flag: `-Yes` present → `$true` | don't give it a default of `$true` |
| `$PSScriptRoot` | `$Root` default | the folder the running script is in (Python: `Path(__file__).parent`) | empty when code is pasted into a console |
| `@{ From = 'a'; To = 'b' }` | `$Moves` | a **hashtable** (Python `dict`) | keys aren't case-sensitive: `$m.from` works |
| `@( … )` | lists | array subexpression: always an array, even with 0 or 1 items | without it, one result is a scalar, not a 1-item array |
| `[pscustomobject]@{ … }` | the plan | a lightweight record (Python `SimpleNamespace` or a dataclass instance) | prints as a table; fields are fixed |
| `$plan += …` | phase 1 | appends by **copying** the array (arrays are fixed-size) | fine for 4 items; use `[System.Collections.Generic.List[object]]` for thousands |
| `function Name([type]$p) { }` | helpers | functions; called **without** parentheses or commas: `Get-GitLine $from @('status')` | `f(1, 2)` passes **one** array argument |
| `@GitArgs` (splatting) | `Get-GitLine` | spreads an array (or hashtable) as separate arguments, like Python `*args` / `**kwargs` | `$GitArgs` without `@` passes one array |
| `"text $var $($obj.Prop)"` | messages | string interpolation (Python f-strings); `$( )` for expressions | `"${Repo}:"` needs braces before `:` (else it's read as a drive like `C:`) |
| `'single quotes'` | literals | no interpolation, like a raw string | `''` inside means one `'` |
| `` `n `` | messages | newline (the backtick is the escape character, not `\`) | `\` is just a character, which is why Windows paths need no escaping |
| `-f` format operator | plan output | `"{0} -> {1}" -f $a, $b` (Python `str.format`) | |
| `$(if (…) { } else { })` | exit code | `if` used as an expression (5.1 has no ternary `?:`) | |
| `-eq -ne -like` | comparisons | comparison operators (`==` doesn't exist) | **case-insensitive** by default; `-ceq` is case-sensitive |
| `$script:failures++` | tests | **scope modifier**: write the script-level variable from inside a function | without `script:` the function changes a local copy |
| `exit N` | everywhere | ends the script with an exit code (`$LASTEXITCODE` for the caller) | inside a function, `exit` still ends the **whole script**; `return` only leaves the function |
| `try { } finally { }` | tests | cleanup that always runs (Python `try/finally`) | |
| `*> $null` | tests | redirect **all** output streams (success, error, warning, verbose, debug, information) to nothing | `Write-Host` is the information stream (6) since 5.0 |

## 3. Cmdlets

| Cmdlet | Where | Why this one |
| --- | --- | --- |
| `Test-Path -LiteralPath x [-PathType Container]` | existence checks | returns `$true`/`$false`; `-PathType Container` = "is a folder" |
| `Resolve-Path -LiteralPath` | root | canonical absolute path (`.ProviderPath` gives the plain file system path) |
| `Join-Path`, `Split-Path [-Parent] [-Leaf]` | paths | build and split paths without string slicing (Python `os.path.join` / `dirname` / `basename`) |
| `Get-Process -Name … -ErrorAction SilentlyContinue` | lock check | finds running programs by name; `SilentlyContinue` turns "not found" into "nothing returned" |
| `New-Item -ItemType Directory -Force` | phase 3 | makes the parent folder; `-Force` = no error if it exists (like `mkdir -p`) |
| `Move-Item -LiteralPath a -Destination b` | phase 3 | the move; a rename on the same volume |
| `Remove-Item -Recurse -Force` | test cleanup | only after checking the folder name is the test's own |
| `Set-Content` | tests | writes a small text file |
| `Write-Host -ForegroundColor` | messages | coloured text for a person; it is **not** pipeline output |
| `Read-Host` | confirm, pause | reads a line from the person |
| `Out-Null` | after `New-Item` | throws away output so it doesn't print |
| `Get-Command git` | phase 1 | "is git installed?" (Python `shutil.which`) |
| `Sort-Object -Unique` | lock message | distinct names |
| `ForEach-Object` | plan output | run a block for each pipeline item (`$_` is the current item) |

**Why `-LiteralPath` everywhere:** plain `-Path` treats `[`, `]`, `*`, `?`
as wildcards. A folder named `Notes [old]` would silently match nothing, or
the wrong thing.

## 4. .NET classes called directly

PowerShell can call any .NET type with `[Type]::Method()`:

| Call | Where | Why |
| --- | --- | --- |
| `[IO.Path]::IsPathRooted($p)` | `Resolve-Inside` | rejects `C:\x`, `\x` |
| `[IO.Path]::Combine` + `[IO.Path]::GetFullPath` | `Resolve-Inside` | collapses `..` **without touching the disk**, so a path can be judged before it exists |
| `$s.StartsWith(prefix, [StringComparison]::OrdinalIgnoreCase)` | `Resolve-Inside`, self-move | Windows paths are case-insensitive; ordinal = compare characters exactly, no culture rules |
| `[string]::IsNullOrWhiteSpace` | `Resolve-Inside` | empty `From`/`To` |
| `[IO.Path]::GetTempPath()`, `[guid]::NewGuid()` | tests | a unique throwaway folder name |
| `[System.Management.Automation.Language.Parser]::ParseFile` | `main.py check` | syntax check without running |

## 5. Running external programs (git)

```powershell
$out = & git -C $Repo @GitArgs
if ($LASTEXITCODE -ne 0) { ... }
```

- `&` is the **call operator**: run this command/program. Here it's
  optional, but it's required when the program name is in a variable or
  quoted.
- Arguments are passed as **separate values**, not as one string glued
  together, so a folder name with spaces or `&` stays one argument. No
  quoting, no injection, unlike building a cmd line.
- `$LASTEXITCODE` is the exit code of the last external program (Python
  `subprocess.run(...).returncode`).
- Output comes back as an **array of lines** (or `$null` if git printed
  nothing). `if ($out)` is false for empty output, which is what makes
  `if (git status --porcelain)` a "has changes?" test.

## 6. Memory and paradigm

- **Memory:** PowerShell runs on .NET, so memory is managed by the .NET
  **garbage collector**, as in Python (Python uses reference counting plus a
  cycle collector; .NET uses a tracing, generational GC). Nothing to free by
  hand. Objects live on the managed heap.
- **Paradigm:** the script is **procedural** (top-to-bottom phases plus
  small functions), with a pipeline style for one-liners. That fits a script
  that runs once, in order. Classes (`class Move { }`, PowerShell 5+) would
  add ceremony with no benefit at this size: YAGNI.

## 7. Python side by side

| PowerShell | Python |
| --- | --- |
| `Test-Path -LiteralPath $p` | `Path(p).exists()` |
| `Move-Item -LiteralPath a -Destination b` | `os.rename(a, b)` (not `shutil.move`, which may copy and delete) |
| `$ErrorActionPreference = 'Stop'` | the default: exceptions stop Python |
| `@{ a = 1 }` | `{"a": 1}` |
| `[pscustomobject]@{ a = 1 }` | `SimpleNamespace(a=1)` |
| `& git @args; $LASTEXITCODE` | `subprocess.run(["git", *args]).returncode` |
| `exit 1` | `sys.exit(1)` |

## Exercises

1. Run `$one = 'abc'; $one[0]` and then `$arr = @('abc'); $arr[0]`. Why do they differ, and why does `@( … )` around a command's output avoid this surprise?
2. Write `function Add($a, $b) { $a + $b }` and call it as `Add(1, 2)` and as `Add 1 2`. Explain the difference.
3. Make a folder `x [1]`, then compare `Test-Path 'x [1]'` and `Test-Path -LiteralPath 'x [1]'`.

**Self-check:** why does passing git arguments with `@GitArgs` avoid the
injection problem that `%NAME%` has in cmd?

## References

### Official

- Microsoft Learn: [about_Comment_Based_Help](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comment_based_help), [about_Hash_Tables](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_hash_tables), [about_Arrays](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_arrays), [about_Splatting](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_splatting), [about_Scopes](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_scopes), [about_Redirection](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_redirection), [about_Operators (call operator &)](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_operators), [about_Comparison_Operators](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_comparison_operators), [about_Quoting_Rules](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_quoting_rules), [Approved verbs](https://learn.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
- .NET: [Path class](https://learn.microsoft.com/dotnet/api/system.io.path), [Garbage collection fundamentals](https://learn.microsoft.com/dotnet/standard/garbage-collection/fundamentals)
- Python: [os.rename](https://docs.python.org/3/library/os.html#os.rename), [types.SimpleNamespace](https://docs.python.org/3/library/types.html#types.SimpleNamespace)

### Further learning

- Microsoft Learn: [Everything you wanted to know about hashtables](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-hashtable), [about arrays](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-arrays), [about PSCustomObject](https://learn.microsoft.com/powershell/scripting/learn/deep-dives/everything-about-pscustomobject)
- [Exercism PowerShell track](https://exercism.org/tracks/powershell)
