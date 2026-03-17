#!/bin/bash
# Package-Xray Installer Script
set -e

echo "📦 Installing Package-Xray..."

# 1. Check for required dependencies
MISSING_DEPS=""
if ! command -v git &> /dev/null; then MISSING_DEPS="git "; fi
if ! command -v nvim &> /dev/null; then MISSING_DEPS="${MISSING_DEPS}neovim "; fi
if ! command -v jq &> /dev/null; then MISSING_DEPS="${MISSING_DEPS}jq "; fi

if [ -n "$MISSING_DEPS" ]; then
    echo "⚙️  Missing dependencies detected: $MISSING_DEPS"
    echo "🔑 Requesting sudo privileges to install them..."
    sudo apt update && sudo apt install -y $MISSING_DEPS
    echo "✅ Dependencies installed!"
fi

# 2. Define installation paths
INSTALL_DIR="$HOME/.local/share/pckray"
# Using /usr/local/bin ensures 'sudo pckray' works correctly
GLOBAL_BIN="/usr/local/bin/pckray"

# 3. Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 Updating existing installation at $INSTALL_DIR..."
    cd "$INSTALL_DIR"
    git pull origin main
else
    echo "📥 Cloning repository to $INSTALL_DIR..."
    git clone https://github.com/Dropdaz/package-xray.git "$INSTALL_DIR"
fi

# 4. Set execution permissions for the internal script
chmod +x "$INSTALL_DIR/pkgray"

# 5. Create a global symlink
echo "🔗 Creating global symlink in /usr/local/bin..."
# This requires sudo but makes the command available system-wide
sudo ln -sf "$INSTALL_DIR/pkgray" "$GLOBAL_BIN"

echo ""
echo "✅ Package-Xray installed successfully!"
echo "🚀 Launch it with: pckray"
echo "🔐 For administrative tasks: sudo pckray"