@echo off
REM lca v5 — CMD wrapper (public, MIT). Calls the PowerShell launcher.
REM Usage:  lca.cmd "build a todo app"
REM Requires PowerShell 5+ (preinstalled on Windows 10/11).

setlocal
REM Reconstruct the original arguments (preserving spaces inside quoted args)
set "ARGS="
:parse
if "%~1"=="" goto run
if defined ARGS (set "ARGS=%ARGS% %~1") else (set "ARGS=%~1")
shift
goto parse
:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0lca.ps1" %ARGS%
endlocal
