#!/bin/bash
# Package-Xray Installer Script
set -e

echo "📦 Installing Package-Xray..."

# 1. Add Neovim Stable PPA to get version 0.10+ (replaces old apt/snap versions)
echo "🌐 Adding Neovim Stable PPA for modern UI support..."
sudo add-apt-repository ppa:neovim-ppa/stable -y
sudo apt update

# 2. Check and install dependencies
MISSING_DEPS=""
if ! command -v git &> /dev/null; then MISSING_DEPS="git "; fi
if ! command -v nvim &> /dev/null; then MISSING_DEPS="${MISSING_DEPS}neovim "; fi
if ! command -v jq &> /dev/null; then MISSING_DEPS="${MISSING_DEPS}jq "; fi

if [ -n "$MISSING_DEPS" ]; then
    echo "⚙️  Installing dependencies: $MISSING_DEPS"
    sudo apt install -y $MISSING_DEPS
    echo "✅ Dependencies installed!"
fi

# 3. Define installation paths
INSTALL_DIR="$HOME/.local/share/pckray"
GLOBAL_BIN="/usr/local/bin/pckray"

# 4. Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    echo "🔄 Updating existing installation at $INSTALL_DIR..."
    cd "$INSTALL_DIR"
    git pull origin main
else
    echo "📥 Cloning repository to $INSTALL_DIR..."
    git clone https://github.com/Dropdaz/package-xray.git "$INSTALL_DIR"
fi

# 5. Set execution permissions for the internal launcher
chmod +x "$INSTALL_DIR/pkgray"

# 6. Create a global symlink in /usr/local/bin
# This allows 'pckray' and 'sudo pckray' to work from any folder
echo "🔗 Creating global symlink..."
sudo ln -sf "$INSTALL_DIR/pkgray" "$GLOBAL_BIN"

# 7. Clear command hash to avoid "snap/bin/nvim" errors
hash -r

echo ""
echo "✅ Package-Xray installed successfully!"
echo "🚀 Run it from anywhere: pckray"
echo "🔐 Delete packages with: sudo pckray"