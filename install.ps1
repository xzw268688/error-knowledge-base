param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSCommandPath
$skillSrc = Join-Path $repoRoot "error-knowledge-base"
$skillDest = "$HOME\.claude\skills\error-knowledge-base"

if (-not (Test-Path $skillSrc)) {
    Write-Error "error-knowledge-base/ directory not found."
    Write-Host "Run from the repository root: powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1"
    exit 1
}

if (Test-Path $skillDest) {
    if (-not $Force) {
        Write-Warning "Already installed. Use -Force to reinstall."
        exit 0
    }
    Remove-Item -Recurse -Force $skillDest
}

New-Item -ItemType Directory -Path "$HOME\.claude\skills" -Force | Out-Null
Copy-Item -Recurse -Force $skillSrc $skillDest

Write-Host "Installed to: $skillDest"

# Append the standing convention to the user-level CLAUDE.md (idempotent).
# This is what makes the skill ask to record automatically in every session,
# instead of requiring the user to type /error-knowledge-base by hand.
# The convention text lives in convention.md so this script stays ASCII-only
# (Windows PowerShell 5.1 misreads UTF-8-without-BOM scripts).
$globalMd = "$HOME\.claude\CLAUDE.md"
$conventionSrc = Join-Path $repoRoot "convention.md"
$marker = "<!-- error-knowledge-base:convention -->"

$existing = if (Test-Path $globalMd) { Get-Content $globalMd -Raw -Encoding UTF8 } else { "" }

if ($null -eq $existing) { $existing = "" }

if ($existing -notlike "*$marker*") {
    if (-not (Test-Path $conventionSrc)) {
        Write-Warning "convention.md not found; skipping global convention."
    } else {
        New-Item -ItemType Directory -Path "$HOME\.claude" -Force | Out-Null
        $block = (Get-Content $conventionSrc -Raw -Encoding UTF8).TrimEnd()

        $combined = if ($existing.Trim().Length -gt 0) {
            $existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $block + [Environment]::NewLine
        } else {
            $block + [Environment]::NewLine
        }

        # Write without BOM: some tools treat a leading BOM as part of the first line.
        [System.IO.File]::WriteAllText($globalMd, $combined, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Convention added to: $globalMd"
    }
} else {
    Write-Host "Convention already present in: $globalMd"
}