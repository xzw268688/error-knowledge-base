# Error Knowledge Base Skill - Install Script
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSCommandPath
$skillSrc = Join-Path $repoRoot "error-knowledge-base"
$skillDest = "$HOME\.claude\skills\error-knowledge-base"

if (-not (Test-Path $skillSrc)) {
    Write-Error "未找到 error-knowledge-base/ 目录"
    Write-Host "请在仓库根目录运行: powershell -NoProfile -ExecutionPolicy Bypass -File install.ps1"
    exit 1
}

if (Test-Path $skillDest) {
    if (-not $Force) {
        Write-Warning "已安装，使用 -Force 重新安装"
        exit 0
    }
    Remove-Item -Recurse -Force $skillDest
}

New-Item -ItemType Directory -Path "$HOME\.claude\skills" -Force | Out-Null
Copy-Item -Recurse -Force $skillSrc $skillDest

Write-Host "Installed to: $skillDest"
