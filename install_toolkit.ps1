#!/usr/bin/env pwsh
<#
PowerShell installer for the Wavelet Prosody Toolkit demo.

It will:
- create a virtual environment `.venv` inside this folder
- upgrade pip
- install Python dependencies
- clone the toolkit repo to `vendor/wavelet_prosody_toolkit`
- pip install the toolkit in editable mode

Run this script from the `abstract_toolkit_demo` directory.
#>

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "Installer running in: $here"

if (-Not (Test-Path -Path (Join-Path $here '.venv')) ) {
    Write-Host "Creating virtual environment..."
    python -m venv .venv
} else {
    Write-Host ".venv already exists; skipping venv creation"
}

# Use the venv's python executable to avoid activation issues in scripts
$venvPython = Join-Path $here '.venv\Scripts\python.exe'
if (-Not (Test-Path $venvPython)) {
    Write-Host "Warning: venv python not found at $venvPython - falling back to system python"
    $venvPython = "python"
}

Write-Host "Upgrading pip inside venv..."
& $venvPython -m pip install --upgrade pip

Write-Host "Installing core Python packages into venv (PyWavelets, scipy, numpy, matplotlib, PyQt6)..."
& $venvPython -m pip install --upgrade PyWavelets scipy numpy matplotlib PyQt6

if (-Not (Test-Path -Path (Join-Path $here 'vendor')) ) {
    New-Item -ItemType Directory -Path (Join-Path $here 'vendor') | Out-Null
}

$toolkit_dir = Join-Path $here 'vendor\wavelet_prosody_toolkit'
if (-Not (Test-Path -Path $toolkit_dir)) {
    Write-Host "Cloning wavelet_prosody_toolkit into vendor/..."
    git clone https://github.com/asuni/wavelet_prosody_toolkit.git $toolkit_dir
} else {
    Write-Host "Toolbox already cloned at $toolkit_dir"
}

Write-Host "Installing toolkit (editable) into venv..."
& $venvPython -m pip install -e $toolkit_dir

Write-Host "Installation finished. To run the GUI:"
Write-Host "  cd $here"
Write-Host '  .\.venv\Scripts\Activate'
Write-Host "  python run_gui.py"
