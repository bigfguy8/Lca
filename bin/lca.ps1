<#
lca v5 — Windows launcher (public, MIT)

Works from PowerShell directly, and from CMD via bin\lca.cmd (a thin wrapper).
Mirrors the Unix launcher (bin/lca.sh): integrity-gates the closed core,
detects GPU (CUDA/NVidia first, then CPU), hands off to the core.

Usage (PowerShell):
  pwsh -File lca.ps1 "build a todo app"
Usage (CMD):
  lca.cmd "build a todo app"

The closed core (core\lca_core) is a POSIX sh script. On Windows it runs under
Git-Bash / WSL / MSYS2, which the launcher auto-detects. If you only have native
PowerShell, lca.ps1 still performs the integrity gate + GPU detect and prints a
clear "install Git-Bash to run the core" message with the exact command.
#>
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

$ErrorActionPreference = "Stop"

# ---- 1. locate the project -------------------------------------------
if ($env:LCA_HOME) { $LcaHome = $env:LCA_HOME }
elseif (Test-Path (Join-Path $PSScriptRoot "..\core")) {
  $LcaHome = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else { $LcaHome = Join-Path $HOME ".lca" }
if (-not (Test-Path $LcaHome)) { Write-Error "lca: project not found (set LCA_HOME)"; exit 1 }

$Core   = Join-Path $LcaHome "core\lca_core"
$Sum    = Join-Path $LcaHome "core\lca_core.sha256"
if (-not (Test-Path $Core)) { Write-Error "lca: core missing: $Core (run install.ps1)"; exit 1 }
if (-not (Test-Path $Sum))  { Write-Error "lca: checksum missing: $Sum"; exit 1 }

# ---- 2. integrity gate (SHA256, matches the Unix gate) ---------------
$actual   = (Get-FileHash $Core -Algorithm SHA256).Hash.ToLower()
$expected = (Get-Content $Sum | Select-Object -First 1).Split('\s+')[0]
if ($actual -ne $expected) {
  Write-Error "lca: CORE INTEGRITY CHECK FAILED`n  expected: $expected`n  actual:   $actual`n  rebuild: bash core\build_core.sh"
  exit 2
}

# ---- 3. GPU-first detection (CUDA first on Windows) ------------------
$Gpu = "cpu"
if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) { $Gpu = "cuda" }
elseif (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{0D3C0542-2E2D-47E9-B462-5DCE8F1C24C5}") {
  $Gpu = "vulkan"   # Vulkan driver present
}
$env:LCA_GPU = $Gpu
$env:LCA_CORE_HOME = $LcaHome

# ---- 4. find a POSIX shell to run the closed core --------------------
$bash = $null
foreach ($cand in @("bash","git-bash","/usr/bin/bash","C:\Program Files\Git\bin\bash.exe")) {
  if (Get-Command $cand -ErrorAction SilentlyContinue) { $bash = $cand; break }
}
if (-not $bash) {
  Write-Host "lca: core is POSIX sh. Install Git for Windows (provides bash), then re-run:"
  Write-Host "  $bash `"$Core`" $($Args -join ' ')"
  exit 1
}

# ---- 5. hand off ------------------------------------------------------
& $bash $Core $Args
