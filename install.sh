#!/bin/bash
# Package-Xray Installer Script
set -e

echo "📦 Installing Package-Xray..."

# 1. Add Neovim Stable PPA for the latest version (0.10+)
# This ensures consistent colors and modern Lua API support
echo "🌐 Adding Neovim Stable PPA..."
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

# 5. Set execution permissions for the internal script
chmod +x "$INSTALL_DIR/pkgray"

# 6. Create a global symlink for 'pckray' and 'sudo pckray'
echo "🔗 Creating global symlink in /usr/local/bin..."
sudo ln -sf "$INSTALL_DIR/pkgray" "$GLOBAL_BIN"

# 7. Clear the shell's command hash table
# This fixes the "bash: /snap/bin/nvim: No such file" error
hash -r

echo ""
echo "✅ Package-Xray installed successfully with Neovim Stable!"
echo "🚀 Run it with: pckray"
echo "🔐 Administrative tasks: sudo pckray"