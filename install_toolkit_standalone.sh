#!/usr/bin/env bash
#
# Standalone installer for Wavelet Prosody Toolkit (macOS/Linux)
# GLOBAL USER-LEVEL INSTALLATION
#
# This installs the toolkit to your user Python environment so it's
# available from any project directory.
#
# Usage:
#   chmod +x install_toolkit_standalone.sh
#   ./install_toolkit_standalone.sh [install_directory]
#
# If no directory is specified, installs to: ~/wavelet_prosody_toolkit

set -e  # Exit on error

# Determine installation directory
if [ -z "$1" ]; then
    INSTALL_DIR="$HOME/wavelet_prosody_toolkit"
    echo "No directory specified. Installing to default: $INSTALL_DIR"
else
    INSTALL_DIR="$1"
    echo "Installing to: $INSTALL_DIR"
fi

# Create parent directory if needed
mkdir -p "$(dirname "$INSTALL_DIR")"

echo ""
echo "========================================="
echo "Wavelet Prosody Toolkit - Global Install"
echo "========================================="
echo ""

# Install dependencies
echo "Installing dependencies (PyWavelets, scipy, numpy, matplotlib, PyQt6)..."
python3 -m pip install --upgrade pip --user
python3 -m pip install --upgrade PyWavelets scipy numpy matplotlib PyQt6 --user

# Clone repository
if [ ! -d "$INSTALL_DIR" ]; then
    echo ""
    echo "Cloning wavelet_prosody_toolkit from GitHub..."
    git clone https://github.com/asuni/wavelet_prosody_toolkit.git "$INSTALL_DIR"
else
    echo ""
    echo "Directory already exists: $INSTALL_DIR"
    echo "Pulling latest changes..."
    cd "$INSTALL_DIR"
    git pull
    cd -
fi

# Install toolkit in editable mode (user-level)
echo ""
echo "Installing toolkit globally (user-level, editable mode)..."
python3 -m pip install --user -e "$INSTALL_DIR"

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo ""
echo "The toolkit is now installed and available from any Python project."
echo "Toolkit source code location: $INSTALL_DIR"
echo ""
echo "To use the GUI from any directory:"
echo "  python3 -m wavelet_prosody_toolkit.wavelet_gui"
echo ""
echo "Or run the GUI script directly:"
echo "  python3 $INSTALL_DIR/wavelet_prosody_toolkit/wavelet_gui.py"
echo ""
echo "To use in Python scripts:"
echo "  import wavelet_prosody_toolkit"
echo ""
echo "To update the toolkit in the future:"
echo "  cd $INSTALL_DIR"
echo "  git pull"
echo ""
