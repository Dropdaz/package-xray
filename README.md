# 📦 Package-Xray

> A beautiful, high-performance CLI Package Manager and Activity Explorer for Debian-based systems, inspired by Neovim's elegant aesthetics.

**Package-Xray** provides a lightning-fast, highly visual Terminal User Interface (TUI) to audit, explore, and manage your installed packages. Built on top of Neovim's powerful UI engine natively leveraging Lua, it turns package management from a chore into a premium developer experience.

<img width="500" height="300" alt="imagen" src="https://github.com/user-attachments/assets/c5cd4b73-a4dc-409f-b2e3-c870e995580a" />


![License](https://img.shields.io/badge/license-GPLv3-blue.svg)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-orange.svg)

---

## ✨ Features

- **Spotlight-Style Search:** A sleek, centered floating command palette to instantly search through all installed packages and applications.
- **Categorized Explorer:** Packages are intelligently grouped chronologically into `Default` (System) and `User` domains, making it effortless to identify what belongs where.
- **Bulk Operations:** Select multiple packages at once and uninstall them in batches with a beautifully animated, real-time progress layout.
- **Activity Logs & Revert System:** Keep a persistent JSON-backed history of all your installations and uninstallations. Made a mistake? Seamlessly review session details and **revert** actions directly from the Log Explorer.
- **Intuitive Navigation:** Navigate smoothly using `j/k`, arrow keys, or the mouse wheel. Collapsible tree views keep your workspace tidy.
- **Zero Config Required:** Works out of the box with zero interference with your existing Neovim configuration (`--clean`).

---

## 🚀 Installation

### Prerequisites
- **Debian-based OS** (Ubuntu, Debian, Pop!_OS, WSL, etc.) using `apt`/`dpkg`.
- **Neovim** (`>= 0.8.0` recommended) for the UI rendering engine.
- **jq** for JSON log parsing (optional but heavily recommended for reliability).

### Quick Setup

The easiest way to install **Package-Xray** is with this one-liner curl script. It will automatically check for prerequisites, clone the repository to `~/.local/share/package-xray`, and create an executable symlink in `~/.local/bin`:

```bash
curl -sSL https://raw.githubusercontent.com/Dropdaz/package-xray/main/install.sh | bash
```

*(Note: Ensure `~/.local/bin` is in your system's `$PATH`)*

### Manual Installation

If you prefer to install it manually:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Dropdaz/package-xray.git
   cd package-xray
   ```

2. **Make the launch script executable:**
   ```bash
   chmod +x pkgray
   ```

3. **Add to your PATH for global access:**
   ```bash
   mkdir -p ~/.local/bin
   ln -s $(pwd)/pkgray ~/.local/bin/package-xray
   ```

---

## 🎮 Usage

Simply run the tool from your terminal:

```bash
./pkgray
# or if added to your PATH:
package-xray
```

Remember to use sudo to be able to install/uninstall packages!
```bash
sudo ./pkgray
# or if added to your PATH:
sudo package-xray
```

<img width="2838" height="1501" alt="imagen" src="https://github.com/user-attachments/assets/a9aaa7fc-430a-4387-90ec-75e5fd56672b" />


<img width="2807" height="1461" alt="imagen" src="https://github.com/user-attachments/assets/1cd5c3f5-cad4-4c35-9f59-f80bee58ae7c" />


### ⌨️ Keybindings & Controls

The interface relies heavily on Vim-inspired shortcuts:

| Key | Action |
| --- | --- |
| `j` / `k` / `Down` / `Up` | Move cursor down / up |
| `Left` | Collapse folder, or pan to Side Menu |
| `Right` | Expand folder, or pan to Main List |
| `Enter` | Expand folder or view detailed package info |
| `Space` | Select / Unselect a package for bulk action |
| `a` | Select all currently visible packages |
| `s` or `/` | Open the floating Spotlight Search Palette |
| `U` | Start Uninstall process for the marked packages |
| `Tab` | Switch focus between Side & Main panes |
| `q` or `Esc` | Go back to Menu / Exit application |
| `C` (In Logs) | Clear complete activity history |
| `r` (In Logs) | Revert an old uninstall session |

---

## 📜 License

Package-Xray is distributed under the **GNU General Public License v3.0 (GPLv3)**. See the `LICENSE` file for more details.

Copyright (C) 2026 Ernesto Vives Femenia  
Contact: ernestovivesxalo@gmail.com | [GitHub as Dropdaz](https://github.com/Dropdaz)
