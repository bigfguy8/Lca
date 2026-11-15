<#
lca v4 — Windows installer (public, MIT)

One-line form (from GitHub):
  iwr -UseBasicParsing https://raw.githubusercontent.com/<YOU>/lca/main/install.ps1 | iex

Or:  powershell -File install.ps1

What it does:
  1. Copies the project to %USERPROFILE%\.lca
  2. Re-signs the core checksum for this install
  3. Dots lca.cmd onto PATH (via a .cmd shim in %USERPROFILE%\.local\bin)
  4. Builds llama.cpp if cmake+clang+git are present (optional)
  5. Sanity-checks with `lca --doctor`
#>
param([string]$InstallDir = (Join-Path $HOME ".lca"))

$ErrorActionPreference = "Stop"
$Src = $PSScriptRoot
if (-not (Test-Path (Join-Path $Src "bin"))) {
  $Src = (Get-Location).Path
}
foreach ($d in @("bin","core","src","skills")) {
  if (-not (Test-Path (Join-Path $Src $d))) {
    Write-Error "install.ps1: cannot find project layout ($d) in $Src. Run from the lca/ dir or set LCA_SRC."
    exit 1
  }
}

# 1. copy
if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
New-Item -ItemType Directory -Path $InstallDir | Out-Null
Copy-Item -Path (Join-Path $Src "*") -Destination $InstallDir -Recurse

# 2. re-sign the core checksum for this install
$core = Join-Path $InstallDir "core\lca_core"
$sum  = (Get-FileHash $core -Algorithm SHA256).Hash.ToLower()
Set-Content -Path (Join-Path $InstallDir "core\lca_core.sha256") -Value "$sum  lca_core"

# 3. PATH shim (lca.cmd in %USERPROFILE%\.local\bin)
$binDir = Join-Path $HOME ".local\bin"
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
$shim = Join-Path $binDir "lca.cmd"
Set-Content $shim "@echo off`r`n powershell -NoProfile -ExecutionPolicy Bypass -File `"$($InstallDir)\bin\lca.ps1`" %*"
# add to PATH (user)
$currentPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($currentPath -notlike "*$binDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$currentPath;$binDir", "User")
  Write-Host "  added $binDir to user PATH (open a new CMD/PowerShell to use 'lca')"
}

# 4. optional llama.cpp build
$cli = Join-Path $InstallDir "llama.cpp\build\bin\llama-cli.exe"
if (-not (Test-Path $cli)) {
  $hasDeps = @("git","cmake","clang","g++") -eq @((Get-Command $_ -ErrorAction SilentlyContinue))
  if (($hasDeps | Where-Object { $_ -eq $null }).Count -eq 0) {
    Write-Host "install.ps1: building llama.cpp (needs ~1GB disk)…"
    Push-Location $InstallDir
    & git clone --depth 1 https://github.com/ggml-org/llama.cpp
    & cmake -B build -G "MinGW Makefiles"
    & cmake --build build --config Release -j4
    Pop-Location
  } else {
    Write-Host "install.ps1: llama.cpp not built. Install git+cmake+clang (mingw), then re-run, or put a GGUF + llama-cli on PATH."
  }
}

# 5. sanity
& (Join-Path $InstallDir "bin\lca.ps1") --doctor 2>&1 | Out-Host
Write-Host "✓ lca v4 installed to $InstallDir"
Write-Host "  Run: lca `"build a todo app`"   (or: lca.cmd `"prompt`")
