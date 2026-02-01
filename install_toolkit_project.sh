#!/usr/bin/env bash
#
# Per-project installer for Wavelet Prosody Toolkit (macOS/Linux)
# VIRTUAL ENVIRONMENT VERSION
#
# This creates a project-specific installation with isolated dependencies.
# Use this if you need different versions of the toolkit for different projects.
#
# Usage (run from your project directory):
#   chmod +x install_toolkit_project.sh
#   ./install_toolkit_project.sh

set -e  # Exit on error

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Installing toolkit for project in: $SCRIPT_DIR"

cd "$SCRIPT_DIR"

echo ""
echo "=============================================="
echo "Wavelet Prosody Toolkit - Per-Project Install"
echo "=============================================="
echo ""

# Create virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
else
    echo ".venv already exists; skipping creation"
fi

# Activate virtual environment
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
VENV_PIP="$SCRIPT_DIR/.venv/bin/pip"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "Error: Virtual environment creation failed"
    exit 1
fi

echo "Upgrading pip..."
"$VENV_PIP" install --upgrade pip

echo "Installing dependencies (PyWavelets, scipy, numpy, matplotlib, PyQt6)..."
"$VENV_PIP" install --upgrade PyWavelets scipy numpy matplotlib PyQt6

# Clone toolkit to local vendor directory
mkdir -p vendor

TOOLKIT_DIR="$SCRIPT_DIR/vendor/wavelet_prosody_toolkit"
if [ ! -d "$TOOLKIT_DIR" ]; then
    echo ""
    echo "Cloning wavelet_prosody_toolkit into vendor/..."
    git clone https://github.com/asuni/wavelet_prosody_toolkit.git "$TOOLKIT_DIR"
else
    echo ""
    echo "Toolkit already exists in vendor/"
    echo "Pulling latest changes..."
    cd "$TOOLKIT_DIR"
    git pull
    cd "$SCRIPT_DIR"
fi

echo ""
echo "Installing toolkit into project venv (editable mode)..."
"$VENV_PIP" install -e "$TOOLKIT_DIR"

echo ""
echo "=============================================="
echo "Installation Complete!"
echo "=============================================="
echo ""
echo "The toolkit is installed in this project's virtual environment."
echo "Toolkit location: $TOOLKIT_DIR"
echo ""
echo "To activate the environment and run the GUI:"
echo "  cd $SCRIPT_DIR"
echo "  source .venv/bin/activate"
echo "  python -m wavelet_prosody_toolkit.wavelet_gui"
echo ""
echo "Or run directly without activation:"
echo "  $VENV_PYTHON -m wavelet_prosody_toolkit.wavelet_gui"
echo ""
echo "To use in Python scripts (with venv activated):"
echo "  import wavelet_prosody_toolkit"
echo ""
