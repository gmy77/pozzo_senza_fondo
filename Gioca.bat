@echo off
rem ============================================================
rem  Il Pozzo Senza Fondo - avvio facile
rem  Doppio clic e parte. Nessun comando da ricordare.
rem
rem  1) Se accanto a questo file c'e' il gioco gia' esportato, parte quello.
rem  2) Altrimenti cerca Godot 4.7 e apre il progetto sorgente.
rem  Se Godot sta in un posto strano, scrivi il percorso completo
rem  dell'eseguibile dentro un file di testo chiamato  godot.txt
rem  nella stessa cartella di questo file.
rem ============================================================
setlocal
title Il Pozzo Senza Fondo
cd /d "%~dp0"

if exist "%~dp0PozzoSenzaFondo.exe" (
    start "" "%~dp0PozzoSenzaFondo.exe"
    exit /b 0
)

set "GODOT="

rem --- percorso scritto a mano dall'utente ---
if exist "godot.txt" (
    set /p GODOT=<godot.txt
)
if defined GODOT if not exist "%GODOT%" set "GODOT="

rem --- posti dove Godot si trova di solito ---
if not defined GODOT call :prova "C:\SteamLIB\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not defined GODOT call :prova "C:\Program Files\Godot\godot.exe"
if not defined GODOT call :prova "%LOCALAPPDATA%\Programs\Godot\godot.exe"
if not defined GODOT call :prova "%USERPROFILE%\scoop\apps\godot\current\godot.exe"
if not defined GODOT call :prova "%USERPROFILE%\scoop\shims\godot.exe"

rem --- ultimo tentativo: nel PATH ---
if not defined GODOT (
    for /f "delims=" %%G in ('where godot 2^>nul') do (
        if not defined GODOT set "GODOT=%%G"
    )
)

if not defined GODOT (
    echo.
    echo  Non trovo Godot 4.7 su questo computer.
    echo.
    echo  Due strade:
    echo    - scarica Godot da  https://godotengine.org/download  e riprova;
    echo    - oppure crea un file  godot.txt  qui accanto con dentro
    echo      il percorso completo di godot.exe, su una riga sola.
    echo.
    pause
    exit /b 1
)

rem --- primo avvio: Godot deve indicizzare il progetto, se no non trova le classi ---
if not exist ".godot" (
    echo  Primo avvio: preparo il progetto, un momento...
    "%GODOT%" --headless --path . --import >nul 2>&1
)

echo  Avvio Il Pozzo Senza Fondo...
"%GODOT%" --path .
set "USCITA=%ERRORLEVEL%"
if not "%USCITA%"=="0" (
    echo.
    echo  Il gioco si e' chiuso con codice %USCITA%.
    pause
)
exit /b %USCITA%

:prova
if exist %1 set "GODOT=%~1"
goto :eof
