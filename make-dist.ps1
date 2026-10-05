# ============================================================
# make-dist.ps1 - Generate dist and dist-libre
#   dist/       main app (without NLLB)
#   dist-libre/ NLLB patch content only
# ============================================================

$proj  = "C:\Users\Cudny\Documents\cppfiles\ArknightsMusicPlayer"
$build = Join-Path $proj "build"
$dist  = Join-Path $proj "dist"
$distL = Join-Path $proj "dist-libre"

$ErrorActionPreference = "Stop"

# ============================================================
# 0. Preflight: kill busy processes + check server.js
# ============================================================
Write-Host "Checking running processes ..." -ForegroundColor Cyan

$busy = Get-Process -Name ArknightsMusicPlayer, node -ErrorAction SilentlyContinue
if ($busy) {
    Write-Host "  Found busy processes, terminating:" -ForegroundColor Yellow
    $busy | ForEach-Object {
        Write-Host ("    PID {0,-6} {1}" -f $_.Id, $_.ProcessName) -ForegroundColor Yellow
    }
    $busy | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $still = Get-Process -Name ArknightsMusicPlayer, node -ErrorAction SilentlyContinue
    if ($still) {
        Write-Host "  ERROR: cannot kill these processes, please close manually:" -ForegroundColor Red
        $still | Format-Table Id, ProcessName, Path -AutoSize
        exit 1
    }
    Write-Host "  All cleared." -ForegroundColor Green
} else {
    Write-Host "  No busy processes." -ForegroundColor Green
}

# Check ports 3000 / 9912
$ports = netstat -ano | Select-String ":3000\s|:9912\s"
if ($ports) {
    Write-Host "  WARN: ports 3000/9912 still in use, force killing:" -ForegroundColor Yellow
    foreach ($line in $ports) {
        Write-Host "    $line" -ForegroundColor Yellow
        $parts = ($line.ToString() -split '\s+') | Where-Object { $_ -ne '' }
        $procId = $parts[-1]
        if ($procId -match '^\d+$') {
            taskkill /F /T /PID $procId 2>$null | Out-Null
        }
    }
    Start-Sleep -Seconds 1
}

# Check server.js
$serverJs = Join-Path $proj "server\dist\server.js"
if (-not (Test-Path $serverJs)) {
    Write-Host ""
    Write-Host "ERROR: missing server\dist\server.js" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please build server first:" -ForegroundColor Yellow
    Write-Host "  cd $proj\server" -ForegroundColor Yellow
    Write-Host "  npm install" -ForegroundColor Yellow
    Write-Host "  npm run build" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
Write-Host "  server\dist\server.js OK" -ForegroundColor Green

# ============================================================
# 1. Clean old dist / dist-libre
# ============================================================
Write-Host "Cleaning old dist / dist-libre ..." -ForegroundColor Cyan

function Remove-DirForce {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $true }

    try {
        Remove-Item -Recurse -Force $Path -ErrorAction Stop
        return $true
    } catch {
        Write-Host "  standard removal failed, trying cmd rd ..." -ForegroundColor Yellow
    }

    cmd /c "rd /s /q `"$Path`"" 2>$null

    if (Test-Path $Path) {
        Write-Host "  resetting permissions ..." -ForegroundColor Yellow
        cmd /c "takeown /f `"$Path`" /r /d y >nul 2>&1" | Out-Null
        cmd /c "icacls `"$Path`" /grant %USERNAME%:F /t >nul 2>&1" | Out-Null
        cmd /c "rd /s /q `"$Path`"" 2>$null
    }

    if (Test-Path $Path) {
        Write-Host "  ERROR: cannot remove $Path" -ForegroundColor Red
        return $false
    }
    return $true
}

$ok1 = Remove-DirForce $dist
$ok2 = Remove-DirForce $distL

if (-not $ok1 -or -not $ok2) {
    Write-Host "Close the processes holding the files and retry." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $dist  -Force | Out-Null
New-Item -ItemType Directory -Path $distL -Force | Out-Null

# ============================================================
# 2. Main executable
# ============================================================
Write-Host "Copying main executable ..." -ForegroundColor Cyan
$mainExe = Join-Path $build "ArknightsMusicPlayer.exe"
if (-not (Test-Path $mainExe)) {
    Write-Host "ERROR: cannot find $mainExe, build the main app first." -ForegroundColor Red
    exit 1
}
Copy-Item $mainExe $dist

# ============================================================
# 3. ffmpeg
# ============================================================
$ffmpegSrc = Join-Path $build "ffmpeg.exe"
if (Test-Path $ffmpegSrc) {
    Write-Host "Copying ffmpeg.exe ..." -ForegroundColor Cyan
    Copy-Item $ffmpegSrc $dist
} else {
    Write-Host "WARN: ffmpeg.exe not found" -ForegroundColor Yellow
}

# ============================================================
# 4. server directory
# ============================================================
$serverSrc = Join-Path $proj "server"
$serverDst = Join-Path $dist "server"

if (Test-Path $serverSrc) {
    Write-Host "Copying server ..." -ForegroundColor Cyan
    Copy-Item -Recurse -Force $serverSrc $serverDst

    if (-not (Test-Path (Join-Path $serverDst "node.exe"))) {
        Write-Host "ERROR: missing server\node.exe" -ForegroundColor Red
    }
    if (-not (Test-Path (Join-Path $serverDst "dist\server.js"))) {
        Write-Host "ERROR: missing server\dist\server.js" -ForegroundColor Red
    }
} else {
    Write-Host "ERROR: server source directory not found" -ForegroundColor Red
}

# ============================================================
# 5. NLLB -> dist-libre
# ============================================================
$nllbSrc = Join-Path $proj "tools\nllb-server"
$nllbDst = Join-Path $distL "nllb-server"

if (Test-Path $nllbSrc) {
    Write-Host "Copying NLLB -> dist-libre ..." -ForegroundColor Cyan
    Copy-Item -Recurse -Force $nllbSrc $nllbDst

    $exePath  = Join-Path $nllbDst "nllb-server.exe"
    $modelDir = Join-Path $nllbDst "nllb-onnx"

    if (-not (Test-Path $exePath)) {
        Write-Host "ERROR: missing nllb-server.exe" -ForegroundColor Red
    }
    if (-not (Test-Path $modelDir)) {
        Write-Host "WARN: missing nllb-onnx model dir" -ForegroundColor Yellow
    }
} else {
    Write-Host "NOTE: tools\nllb-server not found, patch will be empty" -ForegroundColor Yellow
}

# ============================================================
# 6. README (ASCII only, here-string to avoid parser issues)
# ============================================================
Write-Host "Generating README.txt ..." -ForegroundColor Cyan

$readmeText = @'
================================================================
  Mass Music Player - Readme
================================================================

[Quick Start]
  Double-click ArknightsMusicPlayer.exe to launch.
  All dependencies are bundled, no install needed.

[Translation]
  Default backend: MyMemory, free, no config needed.

  Advanced backends:
    - DeepL:        500k chars/month free, needs API key
    - NLLB-200:     Fully offline AI, needs patch package

  To enable NLLB-200 offline AI translation, download and run:
    Mass_NLLB_Patch_1.2.1.exe
  It integrates automatically; the option appears in Settings.

[FAQ]
  Q: Playback stuck on loading?
  A: Wait 10-15 seconds, do not drag the progress bar.

  Q: Translation not working?
  A: Check network, or switch backend in Settings.

[Feedback]
  https://github.com/Cudny10D/Mass

================================================================
'@

$readmePath = Join-Path $dist "README.txt"
[System.IO.File]::WriteAllText($readmePath, $readmeText, [System.Text.Encoding]::UTF8)

# ============================================================
# 7. windeployqt
# ============================================================
Write-Host "Running windeployqt ..." -ForegroundColor Cyan
$windeployqt = "C:\Qt\6.11.2\mingw_64\bin\windeployqt.exe"

if (Test-Path $windeployqt) {
    $appExe = Join-Path $dist "ArknightsMusicPlayer.exe"
    $qmlDir = Join-Path $proj "qml"
    & $windeployqt --release --qmldir $qmlDir --no-translations $appExe | Out-Null
} else {
    Write-Host "ERROR: windeployqt not found at $windeployqt" -ForegroundColor Red
    exit 1
}

# ============================================================
# 8. Trim unused Qt styles
# ============================================================
Write-Host "Trimming unused Qt styles ..." -ForegroundColor Cyan

$styleDir = Join-Path $dist "qml\QtQuick\Controls"

Remove-Item -Recurse -Force (Join-Path $styleDir "Fusion")       -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $styleDir "Imagine")      -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $styleDir "Material")     -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $styleDir "Universal")    -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $styleDir "FluentWinUI3") -ErrorAction SilentlyContinue

Get-ChildItem $dist -Filter "Qt6QuickControls2Fusion*.dll"       -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $dist -Filter "Qt6QuickControls2Imagine*.dll"      -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $dist -Filter "Qt6QuickControls2Material*.dll"     -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $dist -Filter "Qt6QuickControls2Universal*.dll"    -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem $dist -Filter "Qt6QuickControls2FluentWinUI3*.dll" -ErrorAction SilentlyContinue | Remove-Item -Force

Remove-Item -Recurse -Force (Join-Path $dist "qmltooling") -ErrorAction SilentlyContinue

# ============================================================
# 9. Size report
# ============================================================
$distSize  = (Get-ChildItem -Recurse $dist  -File | Measure-Object -Property Length -Sum).Sum
$distLSize = (Get-ChildItem -Recurse $distL -File | Measure-Object -Property Length -Sum).Sum

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Done!" -ForegroundColor Green
Write-Host "Main dist: $dist" -ForegroundColor Green
Write-Host "  Size: $([Math]::Round($distSize / 1MB, 1)) MB" -ForegroundColor Green
Write-Host "Patch dir: $distL" -ForegroundColor Green
Write-Host "  Size: $([Math]::Round($distLSize / 1MB, 1)) MB" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# ============================================================
# 10. Integrity check
# ============================================================
Write-Host "Integrity check:" -ForegroundColor Cyan

$required = @(
    "ArknightsMusicPlayer.exe",
    "server\node.exe",
    "server\dist\server.js"
)

$optional = @(
    "ffmpeg.exe",
    "README.txt"
)

$allOk = $true

foreach ($f in $required) {
    $p = Join-Path $dist $f
    if (Test-Path $p) {
        Write-Host "  [req] OK      $f" -ForegroundColor Green
    } else {
        Write-Host "  [req] MISSING $f" -ForegroundColor Red
        $allOk = $false
    }
}

foreach ($f in $optional) {
    $p = Join-Path $dist $f
    if (Test-Path $p) {
        Write-Host "  [opt] OK      $f" -ForegroundColor Green
    } else {
        Write-Host "  [opt] SKIP    $f" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "NLLB patch content:" -ForegroundColor Cyan
$nllbExe   = Join-Path $distL "nllb-server\nllb-server.exe"
$nllbModel = Join-Path $distL "nllb-server\nllb-onnx"

if (Test-Path $nllbExe) {
    Write-Host "  [req] OK      nllb-server.exe" -ForegroundColor Green
} else {
    Write-Host "  [req] MISSING nllb-server.exe" -ForegroundColor Red
    $allOk = $false
}

if (Test-Path $nllbModel) {
    Write-Host "  [req] OK      nllb-onnx models" -ForegroundColor Green
} else {
    Write-Host "  [req] MISSING nllb-onnx models" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""

if ($allOk) {
    Write-Host "PACKAGING SUCCESSFUL" -ForegroundColor Green
} else {
    Write-Host "PACKAGING HAS ERRORS, see above" -ForegroundColor Red
    exit 1
}