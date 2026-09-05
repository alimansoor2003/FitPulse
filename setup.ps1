# FitPulse - one-time project setup.
#
# Generates the Android platform folder (which only the Flutter tool can
# create), installs packages, and runs the Drift code generator.
#
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# Safe to re-run: it never touches lib/, assets/ or pubspec.yaml.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

Write-Host ''
Write-Host '=== FitPulse setup ===' -ForegroundColor Cyan

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if ($null -eq $flutter) {
    Write-Host 'Flutter was not found on PATH.' -ForegroundColor Red
    Write-Host 'Install it first: https://docs.flutter.dev/get-started/install/windows'
    exit 1
}
Write-Host ("Using Flutter at " + $flutter.Source)

# --- 1. Android platform scaffolding -------------------------------------
$androidDir = Join-Path $root 'android'
if (Test-Path $androidDir) {
    Write-Host 'android/ already exists - skipping scaffolding.' -ForegroundColor DarkGray
}
else {
    $temp = Join-Path $env:TEMP ('fitpulse_scaffold_' + [guid]::NewGuid().ToString('N'))
    Write-Host 'Generating the Android project...'
    & flutter create --org com.alimansoor --project-name fitpulse --platforms android $temp | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }

    Copy-Item (Join-Path $temp 'android') $androidDir -Recurse
    foreach ($f in @('.metadata', '.gitignore')) {
        $src = Join-Path $temp $f
        $dst = Join-Path $root $f
        if ((Test-Path $src) -and -not (Test-Path $dst)) { Copy-Item $src $dst }
    }
    Remove-Item $temp -Recurse -Force

    # App name shown under the launcher icon.
    $manifest = Join-Path $androidDir 'app\src\main\AndroidManifest.xml'
    if (Test-Path $manifest) {
        (Get-Content $manifest -Raw) `
            -replace 'android:label="fitpulse"', 'android:label="FitPulse"' `
        | Out-File $manifest -Encoding utf8
    }
    Write-Host 'Android project created.' -ForegroundColor Green
}

# --- 2. Packages ----------------------------------------------------------
Write-Host 'Fetching packages...'
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }

# --- 3. Drift code generation --------------------------------------------
Write-Host 'Running the Drift code generator (this takes a minute)...'
& dart run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) { throw 'build_runner failed' }

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host 'Plug in a device (or start an emulator) and run:' -ForegroundColor Cyan
Write-Host '    flutter run'
Write-Host ''
