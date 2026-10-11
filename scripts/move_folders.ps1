<#
.SYNOPSIS
  Move or rename folders (git repos included) safely on Windows.

.DESCRIPTION
  Edit the -Moves default below, close every editor, then run:

    powershell -NoProfile -ExecutionPolicy Bypass -File move_folders.ps1

  Safe by design (docs/WRITING_THE_SCRIPT.md explains each rule):
    - checks EVERY move before doing ANY of them
    - refuses while a program that locks folders (VS Code) is running
    - refuses to move a git repo with uncommitted changes
    - paths must stay inside -Root (no "..", no absolute paths)
    - shows the plan and asks before changing anything (default: no)
    - each move is ONE rename: it fully happens or not at all (never copy + delete)
    - checks each repo afterwards (still clean, same remote)
    - moves already done are skipped, so running it twice is harmless

.EXAMPLE
  .\move_folders.ps1 -Root C:\Projects -Moves @(@{ From = 'Old'; To = 'Archive\Old' })
#>
param(
    [string]$Root = $PSScriptRoot,         # From/To paths are relative to this folder
    [hashtable[]]$Moves = @(
        @{ From = 'Old_Name';     To = 'New_Name' },
        @{ From = 'Some_Project'; To = 'Group\Some_Project' }
    ),
    [string[]]$LockingApps = @('Code'),   # process names that hold folders open
    [switch]$Yes                           # no prompts (for tests and automation)
)

$ErrorActionPreference = 'Stop'

function Stop-Script([string]$Message) {
    Write-Host $Message -ForegroundColor Red
    if (-not $Yes) { Read-Host 'Nothing was changed. Press Enter to exit' | Out-Null }
    exit 1
}

function Resolve-Inside([string]$Relative) {
    # Trust boundary: a path from the move list must not escape the root.
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) {
        Stop-Script "Not a relative path: '$Relative'"
    }
    $full = [IO.Path]::GetFullPath([IO.Path]::Combine($rootFull, $Relative))
    if (-not $full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Script "Path leaves the root folder: '$Relative'"
    }
    return $full
}

function Get-GitLine([string]$Repo, [string[]]$GitArgs) {
    # No 2>&1: in PowerShell 5.1 with 'Stop', a redirected stderr line (even a warning) throws.
    $out = & git -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) { Stop-Script "git $GitArgs failed in $Repo (message above)" }
    return ($out -join "`n")
}

# ---- 1. check everything first ----------------------------------------------
if (-not (Test-Path -LiteralPath $Root -PathType Container)) { Stop-Script "Root folder not found: $Root" }
$rootFull = (Resolve-Path -LiteralPath $Root).ProviderPath.TrimEnd('\')

$running = Get-Process -Name $LockingApps -ErrorAction SilentlyContinue
if ($running) { Stop-Script "Close these first (they lock folders): $(($running.Name | Sort-Object -Unique) -join ', ')" }

$plan = @()
foreach ($m in $Moves) {
    $from = Resolve-Inside $m.From
    $to = Resolve-Inside $m.To
    $fromExists = Test-Path -LiteralPath $from
    $toExists = Test-Path -LiteralPath $to
    if (-not $fromExists -and $toExists) { Write-Host "already done: $($m.To)" -ForegroundColor DarkGray; continue }
    if (-not $fromExists) { Stop-Script "Missing: $($m.From) (and $($m.To) does not exist either)" }
    if ($toExists) { Stop-Script "Both $($m.From) and $($m.To) exist: nothing is overwritten" }
    if ($to.StartsWith($from + '\', [StringComparison]::OrdinalIgnoreCase)) { Stop-Script "Can't move $($m.From) into itself" }

    $isRepo = Test-Path -LiteralPath (Join-Path $from '.git')
    $remote = $null
    if ($isRepo) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Stop-Script 'git is not installed, but a repo needs moving' }
        if (Get-GitLine $from @('status', '--porcelain')) { Stop-Script "$($m.From) has uncommitted changes: commit them first" }
        $remote = Get-GitLine $from @('remote', '-v')
    }
    $plan += [pscustomobject]@{ From = $m.From; To = $m.To; FromPath = $from; ToPath = $to; IsRepo = $isRepo; Remote = $remote }
}

if (-not $plan) { Write-Host 'Nothing to do.' -ForegroundColor Green; exit 0 }

# ---- 2. show the plan, ask (default no) -------------------------------------
Write-Host "`nPlanned moves inside ${rootFull}:"
$plan | ForEach-Object { Write-Host ("  {0} -> {1}{2}" -f $_.From, $_.To, $(if ($_.IsRepo) { '   (git repo)' } else { '' })) }
if (-not $Yes) {
    $answer = Read-Host "`nType yes to move"
    if ($answer -ne 'yes') { Write-Host 'Cancelled. Nothing was changed.'; exit 1 }
}

# ---- 3. move, one rename each, then verify ----------------------------------
$warnings = 0
foreach ($p in $plan) {
    New-Item -ItemType Directory -Force -Path (Split-Path $p.ToPath -Parent) | Out-Null
    Move-Item -LiteralPath $p.FromPath -Destination $p.ToPath   # same volume: a rename, all or nothing
    Write-Host "moved: $($p.From) -> $($p.To)" -ForegroundColor Green
    if ($p.IsRepo) {
        if (Get-GitLine $p.ToPath @('status', '--porcelain')) { Write-Host "  WARNING: $($p.To) shows changes after the move" -ForegroundColor Yellow; $warnings++ }
        if ((Get-GitLine $p.ToPath @('remote', '-v')) -ne $p.Remote) { Write-Host "  WARNING: $($p.To) remotes changed" -ForegroundColor Yellow; $warnings++ }
    }
    if (Test-Path -LiteralPath (Join-Path $p.ToPath '.venv')) {
        # A venv's launchers (pip.exe...) hold its old absolute path; the fix needs the network, so it's left to you.
        Write-Host "  NOTE: $($p.To)\.venv needs repair (docs/WRITING_THE_SCRIPT.md, 'The venv'):" -ForegroundColor Yellow
        Write-Host '    python -m venv --upgrade .venv'
        Write-Host '    .venv\Scripts\python -m pip freeze --exclude-editable > freeze.txt'
        Write-Host '    .venv\Scripts\python -m pip install --force-reinstall --no-deps -r freeze.txt'
    }
}

Write-Host "`nDone: $($plan.Count) moved, $warnings warning(s)." -ForegroundColor Cyan
if (-not $Yes) { Read-Host 'Press Enter to close' | Out-Null }
exit $(if ($warnings) { 2 } else { 0 })
