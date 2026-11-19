@echo off
rem LAST SHIFT build: syntax-check every Luau file, run engine-free tests, build LastShift.rbxl.
rem Double-click this file, or run it from PowerShell / Command Prompt in the project folder.
setlocal
cd /d "%~dp0"

set "LUAU=tools-local\luau\luau.exe"
set "LUAU_COMPILE=tools-local\luau\luau-compile.exe"
set "ROJO=tools-local\rojo\rojo.exe"

if exist "%LUAU_COMPILE%" (
    echo [1/3] Syntax-checking Luau sources...
    for /r "src" %%F in (*.luau) do (
        "%LUAU_COMPILE%" --null "%%F" >nul || (echo Syntax error in %%F & goto :fail)
    )
    for /r "tests" %%F in (*.luau) do (
        "%LUAU_COMPILE%" --null "%%F" >nul || (echo Syntax error in %%F & goto :fail)
    )
) else (
    echo [1/3] Skipped: %LUAU_COMPILE% not found.
)

if exist "%LUAU%" (
    echo [2/3] Running data and damage tests...
    "%LUAU%" tests\run.luau || goto :fail
) else (
    echo [2/3] Skipped: %LUAU% not found.
)

if not exist "%ROJO%" (
    echo Rojo not found at %ROJO%. See README.md "Rebuild from source".
    goto :fail
)
echo [3/3] Building LastShift.rbxl...
"%ROJO%" build default.project.json -o LastShift.rbxl || goto :fail
"%ROJO%" sourcemap default.project.json -o sourcemap.json >nul 2>&1

echo.
echo BUILD OK. Open LastShift.rbxl in Roblox Studio and press F5.
pause
exit /b 0

:fail
echo.
echo BUILD FAILED - see the message above.
pause
exit /b 1
