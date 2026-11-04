@echo off
rem ============================================================
rem  Il Pozzo Senza Fondo - autodiagnosi
rem  Lancia i 74 controlli automatici senza aprire finestre.
rem  Deve finire con:  SELFTEST OK (fallimenti: 0)
rem ============================================================
setlocal
title Il Pozzo Senza Fondo - controlli
cd /d "%~dp0"

set "POZZO_SELFTEST=1"

if exist "%~dp0PozzoSenzaFondo.exe" (
    "%~dp0PozzoSenzaFondo.exe" --headless
    echo.
    pause
    exit /b 0
)

set "GODOT="
if exist "godot.txt" set /p GODOT=<godot.txt
if defined GODOT if not exist "%GODOT%" set "GODOT="
if not defined GODOT if exist "C:\SteamLIB\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" set "GODOT=C:\SteamLIB\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not defined GODOT (
    for /f "delims=" %%G in ('where godot 2^>nul') do (
        if not defined GODOT set "GODOT=%%G"
    )
)
if not defined GODOT (
    echo  Non trovo Godot. Leggi le istruzioni dentro Gioca.bat.
    pause
    exit /b 1
)

rem --quit-after e' solo una rete di sicurezza: il selftest si chiude da solo quando
rem ha finito. Va tenuto largo, perche' conta iterazioni del motore, non secondi.
"%GODOT%" --headless --path . --quit-after 20000
echo.
pause
