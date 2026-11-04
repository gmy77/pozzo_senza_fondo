# tools/crea_pacchetto.ps1
# Scopo: costruire il pacchetto pronto da consegnare: esporta l'eseguibile, ci mette
#        accanto il LEGGIMI e i sorgenti completi, e fa lo zip.
# Uso:   powershell -ExecutionPolicy Bypass -File tools\crea_pacchetto.ps1
#        parametri opzionali: -Destinazione D:\ -SaltaEsportazione -SaltaProva
# Dipendenze: Godot 4.7 con i template di esportazione installati.

[CmdletBinding()]
param(
    [string]$Godot = "C:\SteamLIB\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe",
    [string]$Destinazione = "",
    [switch]$SaltaEsportazione,
    [switch]$SaltaProva
)

$ErrorActionPreference = "Stop"
$progetto = Split-Path -Parent $PSScriptRoot
Set-Location $progetto

$nome = "PozzoSenzaFondo"
$dist = Join-Path $progetto "dist"
$staging = Join-Path $dist $nome
$eseguibile = Join-Path $dist "$nome.exe"

Write-Host "Progetto: $progetto"

if (-not (Test-Path $Godot)) {
    throw "Godot non trovato in '$Godot'. Passalo con -Godot <percorso>."
}

# --- 1. Esportazione ---------------------------------------------------------
if (-not $SaltaEsportazione) {
    Write-Host "1/4 Esporto l'eseguibile..."
    New-Item -ItemType Directory -Force -Path $dist | Out-Null
    & $Godot --headless --path . --export-release "Windows Desktop" $eseguibile | Out-Null
    if (-not (Test-Path $eseguibile)) {
        throw "Esportazione fallita: $eseguibile non e' stato creato."
    }
} else {
    Write-Host "1/4 Esportazione saltata."
}
$megabyte = [math]::Round((Get-Item $eseguibile).Length / 1MB, 1)
Write-Host "    $nome.exe = $megabyte MB"

# --- 2. Il pacchetto si prova prima di spedirlo -------------------------------
if (-not $SaltaProva) {
    Write-Host "2/4 Eseguo i controlli dentro il pacchetto esportato..."
    # L'eseguibile esportato e' un'applicazione con interfaccia: non scrive su una
    # variabile di PowerShell. L'unico modo che funziona davvero e' redirigere su file.
    $log = Join-Path $dist "controlli.txt"
    $env:POZZO_SELFTEST = "1"
    & $eseguibile --headless 2>&1 | Out-File -FilePath $log -Encoding utf8
    Remove-Item Env:\POZZO_SELFTEST
    $riga = (Get-Content $log -ErrorAction SilentlyContinue) | Select-String "SELFTEST"
    Write-Host "    $riga"
    if (-not ("$riga" -match "SELFTEST OK")) {
        throw "Il pacchetto non passa i controlli: non lo spedisco. Vedi $log"
    }
} else {
    Write-Host "2/4 Controlli saltati."
}

# --- 3. Cartella da zippare ---------------------------------------------------
Write-Host "3/4 Preparo la cartella del pacchetto..."
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null

Copy-Item $eseguibile (Join-Path $staging "$nome.exe")
Copy-Item (Join-Path $progetto "LEGGIMI.txt") $staging
# Gli stessi due bat stanno anche accanto all'eseguibile: li' dentro trovano il gioco
# gia' esportato e lo lanciano senza cercare Godot. Chi non si fida di un .exe nudo
# trova comunque un "Gioca" su cui cliccare.
Copy-Item (Join-Path $progetto "Gioca.bat") $staging
Copy-Item (Join-Path $progetto "Prova.bat") $staging

# Sorgenti completi, senza la cache di Godot, senza git e senza i pacchetti vecchi.
$sorgenti = Join-Path $staging "sorgenti"
New-Item -ItemType Directory -Force -Path $sorgenti | Out-Null
$esclusi = @(".git", ".godot", "dist")
Get-ChildItem $progetto -Force | Where-Object { $esclusi -notcontains $_.Name } | ForEach-Object {
    Copy-Item $_.FullName -Destination $sorgenti -Recurse -Force
}

# --- 4. Zip -------------------------------------------------------------------
Write-Host "4/4 Creo lo zip..."
$data = Get-Date -Format "yyyyMMdd"
$zip = Join-Path $dist "$nome-$data.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $staging -DestinationPath $zip -CompressionLevel Optimal

if ($Destinazione -ne "") {
    if (-not (Test-Path $Destinazione)) {
        New-Item -ItemType Directory -Force -Path $Destinazione | Out-Null
    }
    Copy-Item $zip -Destination $Destinazione -Force
    Write-Host "    copia in $Destinazione"
}

$zipMb = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host "Pacchetto pronto: $zip ($zipMb MB)"
Write-Host "Dentro: $nome.exe (doppio clic), LEGGIMI.txt, sorgenti\"
