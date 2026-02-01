#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Standalone installer for Wavelet Prosody Toolkit (Windows/macOS/Linux)
    GLOBAL USER-LEVEL INSTALLATION

.DESCRIPTION
    This installs the toolkit to your user Python environment so it's
    available from any project directory.

.PARAMETER InstallDir
    Installation directory. Defaults to $HOME\wavelet_prosody_toolkit

.EXAMPLE
    .\install_toolkit_standalone.ps1
    .\install_toolkit_standalone.ps1 -InstallDir "C:\Tools\wavelet_prosody_toolkit"
#>

param(
    [string]$InstallDir = "$HOME\wavelet_prosody_toolkit"
)

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Wavelet Prosody Toolkit - Global Install" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Installing to: $InstallDir"

# Create parent directory if needed
$parentDir = Split-Path -Parent $InstallDir
if (-Not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

# Install dependencies
Write-Host ""
Write-Host "Installing dependencies (PyWavelets, scipy, numpy, matplotlib, PyQt6)..." -ForegroundColor Yellow
python -m pip install --upgrade pip --user
python -m pip install --upgrade PyWavelets scipy numpy matplotlib PyQt6 --user

# Clone repository
if (-Not (Test-Path $InstallDir)) {
    Write-Host ""
    Write-Host "Cloning wavelet_prosody_toolkit from GitHub..." -ForegroundColor Yellow
    git clone https://github.com/asuni/wavelet_prosody_toolkit.git $InstallDir
} else {
    Write-Host ""
    Write-Host "Directory already exists: $InstallDir" -ForegroundColor Yellow
    Write-Host "Pulling latest changes..."
    Push-Location $InstallDir
    git pull
    Pop-Location
}

# Install toolkit in editable mode (user-level)
Write-Host ""
Write-Host "Installing toolkit globally (user-level, editable mode)..." -ForegroundColor Yellow
python -m pip install --user -e $InstallDir

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The toolkit is now installed and available from any Python project."
Write-Host "Toolkit source code location: $InstallDir"
Write-Host ""
Write-Host "To use the GUI from any directory:" -ForegroundColor Cyan
Write-Host "  python -m wavelet_prosody_toolkit.wavelet_gui"
Write-Host ""
Write-Host "Or run the GUI script directly:" -ForegroundColor Cyan
Write-Host "  python $InstallDir\wavelet_prosody_toolkit\wavelet_gui.py"
Write-Host ""
Write-Host "To use in Python scripts:" -ForegroundColor Cyan
Write-Host "  import wavelet_prosody_toolkit"
Write-Host ""
Write-Host "To update the toolkit in the future:" -ForegroundColor Cyan
Write-Host "  cd $InstallDir"
Write-Host "  git pull"
Write-Host ""
