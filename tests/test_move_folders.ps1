# Tests for scripts/move_folders.ps1, in a throwaway folder (created here, deleted in finally).
#   powershell -NoProfile -ExecutionPolicy Bypass -File tests\test_move_folders.ps1
# Exit code: 0 = all passed, 1 = a failure.

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..\scripts\move_folders.ps1'
$noLock = @('no-such-process-for-tests')
$failures = 0

function Check([bool]$Condition, [string]$Name) {
    if ($Condition) { Write-Host "ok   $Name" -ForegroundColor Green }
    else { Write-Host "FAIL $Name" -ForegroundColor Red; $script:failures++ }
}

function New-Repo([string]$Path) {
    New-Item -ItemType Directory -Path $Path | Out-Null
    git -C $Path init --quiet
    Set-Content -LiteralPath (Join-Path $Path 'a.txt') -Value 'hello'
    git -C $Path add a.txt
    git -C $Path -c user.name=test -c user.email=test@example.com commit --quiet -m init
    git -C $Path remote add origin https://example.com/test/repo.git
}

function Invoke-Move([string]$Root, [hashtable[]]$Moves, [string[]]$Lock = $noLock) {
    & $script -Root $Root -Moves $Moves -LockingApps $Lock -Yes *> $null   # hide the script's messages
    return $LASTEXITCODE
}

# The root sits INSIDE a test-owned folder, so even a broken script that escapes the root
# only lands in a folder this test deletes (found live: a mutation run escaped into %TEMP%).
$outer = Join-Path ([IO.Path]::GetTempPath()) ("move-folders-test-" + [guid]::NewGuid())
$sandbox = Join-Path $outer 'root'
New-Item -ItemType Directory -Path $sandbox | Out-Null
try {
    # 1. rename + move into a new parent; repo stays clean with the same remote
    New-Repo (Join-Path $sandbox 'Proj')
    New-Item -ItemType Directory -Path (Join-Path $sandbox 'Data') | Out-Null
    $moves = @(@{ From = 'Proj'; To = 'Group\Proj' }, @{ From = 'Data'; To = 'Data_Renamed' })
    $code = Invoke-Move $sandbox $moves
    $moved = Join-Path $sandbox 'Group\Proj'
    Check ($code -eq 0) 'moves succeed (exit 0)'
    Check ((Test-Path "$moved\a.txt") -and -not (Test-Path "$sandbox\Proj")) 'repo moved, old path gone'
    Check (-not (git -C $moved status --porcelain)) 'repo still clean'
    Check ((git -C $moved remote get-url origin) -eq 'https://example.com/test/repo.git') 'same remote'
    Check (Test-Path "$sandbox\Data_Renamed") 'plain folder renamed'

    # 2. idempotent: the same list again does nothing and succeeds
    Check ((Invoke-Move $sandbox $moves) -eq 0) 'second run is harmless (exit 0)'

    # 3. one bad move stops ALL moves (checked before acting)
    New-Repo (Join-Path $sandbox 'Dirty')
    Set-Content -LiteralPath "$sandbox\Dirty\a.txt" -Value 'changed'
    New-Item -ItemType Directory -Path "$sandbox\Fine" | Out-Null
    $code = Invoke-Move $sandbox @(@{ From = 'Fine'; To = 'Fine2' }, @{ From = 'Dirty'; To = 'Dirty2' })
    Check ($code -eq 1) 'uncommitted changes refused (exit 1)'
    Check ((Test-Path "$sandbox\Fine") -and -not (Test-Path "$sandbox\Fine2")) 'the good move did not happen either'

    # 4. never overwrite
    New-Item -ItemType Directory -Path "$sandbox\Taken" | Out-Null
    Check ((Invoke-Move $sandbox @(@{ From = 'Fine'; To = 'Taken' })) -eq 1) 'existing destination refused'
    Check (Test-Path "$sandbox\Fine") 'source untouched'

    # 5. trust boundary: paths can't leave the root
    Check ((Invoke-Move $sandbox @(@{ From = 'Fine'; To = '..\escaped' })) -eq 1) '".." destination refused'
    Check ((Invoke-Move $sandbox @(@{ From = 'Fine'; To = 'C:\escaped' })) -eq 1) 'absolute destination refused'
    Check ((Invoke-Move $sandbox @(@{ From = '.'; To = 'Whole' })) -eq 1) 'moving the root itself refused'
    Check ((Invoke-Move $sandbox @(@{ From = 'Fine'; To = 'Fine\Inside' })) -eq 1) 'moving into itself refused'
    Check (-not (Test-Path (Join-Path $outer 'escaped'))) 'nothing written outside the root'

    # 6. a locking program is running (this very PowerShell counts)
    Check ((Invoke-Move $sandbox @(@{ From = 'Fine'; To = 'Fine3' }) @('powershell', 'pwsh')) -eq 1) 'refuses while a locking app runs'
    Check (Test-Path "$sandbox\Fine") 'nothing moved while locked'
}
finally {
    # Delete only what this test made.
    if ((Split-Path $outer -Leaf) -like 'move-folders-test-*') { Remove-Item -LiteralPath $outer -Recurse -Force }
}

if ($failures) { Write-Host "$failures failed" -ForegroundColor Red; exit 1 }
Write-Host 'all passed' -ForegroundColor Green
exit 0
