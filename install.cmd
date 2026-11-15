@echo off
REM lca v5 — one-line Windows installer for CMD.
REM   curl -O https://raw.githubusercontent.com/bigfguy8/Lca/main/install.cmd
REM   install.cmd
REM (or just: powershell -ExecutionPolicy Bypass -i (irm .../install.ps1))
echo Installing lca v5...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
endlocal
