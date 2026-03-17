#!/bin/bash
# Package-Xray Installer Script

set -e

echo "📦 Installing Package-Xray..."

MISSING_DEPS=""
if ! command -v git &> /dev/null; then MISSING_DEPS="git "; fi
if ! command -v nvim &> /dev/null; then MISSING_DEPS="${MISSING_DEPS}neovim "; fi
if ! command -v jq &> /dev/null; then MISSING_DEPS="${MISSING_DEPS}jq "; fi

if [ -n "$MISSING_DEPS" ]; then
    echo "⚙️  Missing dependencies detected: $MISSING_DEPS"
    echo "🔑 Requesting sudo privileges to install them via apt..."
    sudo apt update
    sudo apt install -y $MISSING_DEPS
    echo "✅ Dependencies installed!"
fi

# Define paths
INSTALL_DIR="$HOME/.local/share/pckray"
BIN_DIR="$HOME/.local/bin"

# Clone or update repo
if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 Updating existing installation at $INSTALL_DIR..."
    cd "$INSTALL_DIR"
    git pull origin main
else
    echo "📥 Cloning repository to $INSTALL_DIR..."
    git clone https://github.com/Dropdaz/package-xray.git "$INSTALL_DIR"
fi

# Set executable permission
chmod +x "$INSTALL_DIR/pkgray"

# Create symlink
echo "🔗 Creating symlink..."
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/pkgray" "$BIN_DIR/pckray"

# Path check
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "⚠️  Important: $BIN_DIR is not in your PATH."
    echo "👉 Please add the following line to your ~/.bashrc or ~/.zshrc:"
    echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo "   Then restart your terminal or run: source ~/.bashrc"
    echo ""
fi

echo "✅ Package-Xray installed successfully!"
echo "🚀 Run 'pckray' to launch the application."
