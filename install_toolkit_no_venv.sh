#!/usr/bin/env bash
#
# Bash installer for the Wavelet Prosody Toolkit demo (macOS/Linux).
# NO VIRTUAL ENVIRONMENT VERSION - installs directly to user Python.
#
# Warning: This installs packages to your system/user Python installation.
# Consider using install_toolkit.sh with venv for better isolation.
#
# Run this script from the `abstract_toolkit_demo` directory.
# Make executable with: chmod +x install_toolkit_no_venv.sh
# Then run: ./install_toolkit_no_venv.sh

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "Installer running in: $SCRIPT_DIR"

cd "$SCRIPT_DIR"

echo "Upgrading pip..."
python3 -m pip install --upgrade pip --user

echo "Installing core Python packages (PyWavelets, scipy, numpy, matplotlib, PyQt6)..."
python3 -m pip install --upgrade PyWavelets scipy numpy matplotlib PyQt6 --user

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

echo "Installing toolkit (editable) to user site-packages..."
python3 -m pip install -e "$TOOLKIT_DIR" --user

echo ""
echo "Installation finished! To run the GUI:"
echo "  cd $SCRIPT_DIR"
echo "  python3 run_gui.py"
