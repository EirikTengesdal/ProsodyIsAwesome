#!/usr/bin/env bash
#
# Bash installer for the Wavelet Prosody Toolkit demo (macOS/Linux).
#
# It will:
# - create a virtual environment `.venv` inside this folder
# - upgrade pip
# - install Python dependencies
# - clone the toolkit repo to `vendor/wavelet_prosody_toolkit`
# - pip install the toolkit in editable mode
#
# Run this script from the `abstract_toolkit_demo` directory.
# Make executable with: chmod +x install_toolkit.sh
# Then run: ./install_toolkit.sh

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Installer running in: $SCRIPT_DIR"

cd "$SCRIPT_DIR"

# Create virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
else
    echo ".venv already exists; skipping venv creation"
fi

# Use the venv's python executable
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    echo "Warning: venv python not found at $VENV_PYTHON - falling back to system python3"
    VENV_PYTHON="python3"
fi

echo "Upgrading pip inside venv..."
"$VENV_PYTHON" -m pip install --upgrade pip

echo "Installing core Python packages into venv (PyWavelets, scipy, numpy, matplotlib, PyQt6)..."
"$VENV_PYTHON" -m pip install --upgrade PyWavelets scipy numpy matplotlib PyQt6

# Create vendor directory if it doesn't exist
if [ ! -d "vendor" ]; then
    mkdir -p vendor
fi

TOOLKIT_DIR="$SCRIPT_DIR/vendor/wavelet_prosody_toolkit"
if [ ! -d "$TOOLKIT_DIR" ]; then
    echo "Cloning wavelet_prosody_toolkit into vendor/..."
    git clone https://github.com/asuni/wavelet_prosody_toolkit.git "$TOOLKIT_DIR"
else
    echo "Toolkit already cloned at $TOOLKIT_DIR"
fi

echo "Installing toolkit (editable) into venv..."
"$VENV_PYTHON" -m pip install -e "$TOOLKIT_DIR"

echo ""
echo "Installation finished! To run the GUI:"
echo "  cd $SCRIPT_DIR"
echo "  source .venv/bin/activate"
echo "  python run_gui.py"
echo ""
echo "Or run directly without activation:"
echo "  $VENV_PYTHON run_gui.py"
