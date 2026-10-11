"""Front door: python main.py check   (parse check, tests, security scan, links)"""

import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PS = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass"]

# Parse every .ps1 with PowerShell's own parser: syntax errors, nothing executed.
PARSE = (
    "$bad = 0; Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object { "
    "$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$e); "
    "if ($e) { $bad++; $e | ForEach-Object { Write-Host \"$($_.Extent.File):$($_.Extent.StartLineNumber) $($_.Message)\" } } "
    "else { Write-Host \"parsed: $($_.Name)\" } }; exit $bad"
)

STEPS = (
    ("parse", PS + ["-Command", PARSE]),
    ("tests", PS + ["-File", str(ROOT / "tests" / "test_move_folders.ps1")]),
    ("security", ["devtools", "scan"]),
    ("links", ["devtools", "links", "--offline"]),
)


def check() -> int:
    results = {}
    for name, cmd in STEPS:
        if not shutil.which(cmd[0]):
            print(f"== {name}: SKIPPED ({cmd[0]} not on PATH)")
            continue
        print(f"== {name}")
        results[name] = subprocess.run(cmd, cwd=ROOT, check=False).returncode == 0  # the exit code is the answer
    print("\n" + "  ".join(f"{n}:{'ok' if ok else 'FAIL'}" for n, ok in results.items()))
    return 0 if results and all(results.values()) else 1


if __name__ == "__main__":
    if sys.argv[1:] != ["check"]:
        sys.exit(__doc__)
    sys.exit(check())
