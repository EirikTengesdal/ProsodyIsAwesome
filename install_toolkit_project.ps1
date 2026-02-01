#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Per-project installer for Wavelet Prosody Toolkit (Windows/macOS/Linux)
    VIRTUAL ENVIRONMENT VERSION

.DESCRIPTION
    This creates a project-specific installation with isolated dependencies.
    Use this if you need different versions of the toolkit for different projects.

.EXAMPLE
    Run from your project directory:
    .\install_toolkit_project.ps1
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Installing toolkit for project in: $here"

Set-Location $here

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Wavelet Prosody Toolkit - Per-Project Install" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# Create virtual environment
if (-Not (Test-Path ".venv")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv .venv
} else {
    Write-Host ".venv already exists; skipping creation" -ForegroundColor Yellow
}

# Use the venv's python executable
$venvPython = Join-Path $here ".venv\Scripts\python.exe"
$venvPip = Join-Path $here ".venv\Scripts\pip.exe"

if (-Not (Test-Path $venvPython)) {
    Write-Host "Error: Virtual environment creation failed" -ForegroundColor Red
    exit 1
}

Write-Host "Upgrading pip..." -ForegroundColor Yellow
& $venvPip install --upgrade pip

Write-Host "Installing dependencies (PyWavelets, scipy, numpy, matplotlib, PyQt6)..." -ForegroundColor Yellow
& $venvPip install --upgrade PyWavelets scipy numpy matplotlib PyQt6

# Clone toolkit to local vendor directory
if (-Not (Test-Path "vendor")) {
    New-Item -ItemType Directory -Path "vendor" | Out-Null
}

$toolkitDir = Join-Path $here "vendor\wavelet_prosody_toolkit"
if (-Not (Test-Path $toolkitDir)) {
    Write-Host ""
    Write-Host "Cloning wavelet_prosody_toolkit into vendor/..." -ForegroundColor Yellow
    git clone https://github.com/asuni/wavelet_prosody_toolkit.git $toolkitDir
} else {
    Write-Host ""
    Write-Host "Toolkit already exists in vendor/" -ForegroundColor Yellow
    Write-Host "Pulling latest changes..."
    Push-Location $toolkitDir
    git pull
    Pop-Location
}

Write-Host ""
Write-Host "Installing toolkit into project venv (editable mode)..." -ForegroundColor Yellow
& $venvPip install -e $toolkitDir

Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
Write-Host "The toolkit is installed in this project's virtual environment."
Write-Host "Toolkit location: $toolkitDir"
Write-Host ""
Write-Host "To activate the environment and run the GUI:" -ForegroundColor Cyan
Write-Host "  cd $here"
Write-Host "  .\.venv\Scripts\Activate.ps1"
Write-Host "  python -m wavelet_prosody_toolkit.wavelet_gui"
Write-Host ""
Write-Host "Or run directly without activation:" -ForegroundColor Cyan
Write-Host "  $venvPython -m wavelet_prosody_toolkit.wavelet_gui"
Write-Host ""
Write-Host "To use in Python scripts (with venv activated):" -ForegroundColor Cyan
Write-Host "  import wavelet_prosody_toolkit"
Write-Host ""
