#!/bin/bash

set -e

echo "🏝️  Islands Dark Theme Installer for macOS/Linux"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect which editors are available
HAS_VSCODE=false
HAS_CURSOR=false

if command -v code &> /dev/null; then
    HAS_VSCODE=true
fi

if command -v cursor &> /dev/null; then
    HAS_CURSOR=true
fi

if [ "$HAS_VSCODE" = false ] && [ "$HAS_CURSOR" = false ]; then
    echo -e "${RED}❌ Error: Neither VS Code CLI (code) nor Cursor CLI (cursor) found!${NC}"
    echo "Please install VS Code or Cursor and make sure the CLI command is in your PATH."
    echo "You can do this by:"
    echo "  1. Open VS Code or Cursor"
    echo "  2. Press Cmd+Shift+P (macOS) or Ctrl+Shift+P (Linux)"
    echo "  3. Type 'Shell Command: Install code/cursor command in PATH'"
    exit 1
fi

if [ "$HAS_VSCODE" = true ]; then
    echo -e "${GREEN}✓ VS Code CLI found${NC}"
fi
if [ "$HAS_CURSOR" = true ]; then
    echo -e "${GREEN}✓ Cursor CLI found${NC}"
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "📦 Step 1: Installing Islands Dark theme extension..."

# Install for VS Code
if [ "$HAS_VSCODE" = true ]; then
    EXT_DIR="$HOME/.vscode/extensions/bwya77.islands-dark-1.0.0"
    rm -rf "$EXT_DIR"
    mkdir -p "$EXT_DIR"
    cp "$SCRIPT_DIR/package.json" "$EXT_DIR/"
    cp -r "$SCRIPT_DIR/themes" "$EXT_DIR/"

    if [ -d "$EXT_DIR/themes" ]; then
        echo -e "${GREEN}✓ Theme extension installed to $EXT_DIR${NC}"
    else
        echo -e "${RED}❌ Failed to install theme extension for VS Code${NC}"
    fi
fi

# Install for Cursor
if [ "$HAS_CURSOR" = true ]; then
    EXT_DIR="$HOME/.cursor/extensions/bwya77.islands-dark-1.0.0"
    rm -rf "$EXT_DIR"
    mkdir -p "$EXT_DIR"
    cp "$SCRIPT_DIR/package.json" "$EXT_DIR/"
    cp -r "$SCRIPT_DIR/themes" "$EXT_DIR/"

    if [ -d "$EXT_DIR/themes" ]; then
        echo -e "${GREEN}✓ Theme extension installed to $EXT_DIR${NC}"
    else
        echo -e "${RED}❌ Failed to install theme extension for Cursor${NC}"
    fi
fi

echo ""
echo "🔧 Step 2: Installing Custom UI Style extension..."
if [ "$HAS_VSCODE" = true ]; then
    if code --install-extension subframe7536.custom-ui-style --force; then
        echo -e "${GREEN}✓ Custom UI Style extension installed for VS Code${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not install Custom UI Style extension for VS Code${NC}"
    fi
fi
if [ "$HAS_CURSOR" = true ]; then
    if cursor --install-extension subframe7536.custom-ui-style --force; then
        echo -e "${GREEN}✓ Custom UI Style extension installed for Cursor${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not install Custom UI Style extension for Cursor${NC}"
        echo "   Please install it manually from the Extensions marketplace in Cursor"
    fi
fi

echo ""
echo "🔤 Step 3: Installing Bear Sans UI fonts..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    FONT_DIR="$HOME/Library/Fonts"
    echo "   Installing fonts to: $FONT_DIR"
    cp "$SCRIPT_DIR/fonts/"*.otf "$FONT_DIR/" 2>/dev/null || true
    echo -e "${GREEN}✓ Fonts installed to Font Book${NC}"
    echo "   Note: You may need to restart applications to use the new fonts"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    echo "   Installing fonts to: $FONT_DIR"
    cp "$SCRIPT_DIR/fonts/"*.otf "$FONT_DIR/" 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
    echo -e "${GREEN}✓ Fonts installed${NC}"
else
    echo -e "${YELLOW}⚠️  Could not detect OS type for automatic font installation${NC}"
    echo "   Please manually install the fonts from the 'fonts/' folder"
fi

echo ""
echo "⚙️  Step 4: Applying settings..."

# Function to apply settings for a given editor
apply_settings() {
    local EDITOR_NAME="$1"
    local SETTINGS_DIR="$2"

    mkdir -p "$SETTINGS_DIR"
    local SETTINGS_FILE="$SETTINGS_DIR/settings.json"

    echo "   Applying settings for $EDITOR_NAME..."

    if [ -f "$SETTINGS_FILE" ]; then
        echo -e "${YELLOW}⚠️  Existing $EDITOR_NAME settings.json found${NC}"
        echo "   Backing up to settings.json.backup"
        cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"

        echo "   Merging Islands Dark settings with your existing settings..."

        if command -v node &> /dev/null; then
            SETTINGS_FILE="$SETTINGS_FILE" node << 'NODE_SCRIPT'
const fs = require('fs');
const path = require('path');

function stripJsonc(text) {
    text = text.replace(/\/\/(?=(?:[^"\\]|\\.)*$)/gm, '');
    text = text.replace(/\/\*[\s\S]*?\*\//g, '');
    text = text.replace(/,\s*([}\]])/g, '$1');
    return text;
}

const scriptDir = process.cwd();
const newSettings = JSON.parse(stripJsonc(fs.readFileSync(path.join(scriptDir, 'settings.json'), 'utf8')));

const settingsFile = process.env.SETTINGS_FILE;
const existingText = fs.readFileSync(settingsFile, 'utf8');
const existingSettings = JSON.parse(stripJsonc(existingText));

const mergedSettings = { ...existingSettings, ...newSettings };

const stylesheetKey = 'custom-ui-style.stylesheet';
if (existingSettings[stylesheetKey] && newSettings[stylesheetKey]) {
    mergedSettings[stylesheetKey] = {
        ...existingSettings[stylesheetKey],
        ...newSettings[stylesheetKey]
    };
}

fs.writeFileSync(settingsFile, JSON.stringify(mergedSettings, null, 2));
console.log('Settings merged successfully');
NODE_SCRIPT
        else
            echo -e "${YELLOW}   Node.js not found. Please manually merge settings.json into your $EDITOR_NAME settings.${NC}"
            echo "   Your original settings have been backed up to settings.json.backup"
        fi
    else
        cp "$SCRIPT_DIR/settings.json" "$SETTINGS_FILE"
        echo -e "${GREEN}✓ $EDITOR_NAME settings applied${NC}"
    fi
}

# Apply settings for VS Code
if [ "$HAS_VSCODE" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        apply_settings "VS Code" "$HOME/Library/Application Support/Code/User"
    else
        apply_settings "VS Code" "$HOME/.config/Code/User"
    fi
fi

# Apply settings for Cursor
if [ "$HAS_CURSOR" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        apply_settings "Cursor" "$HOME/Library/Application Support/Cursor/User"
    else
        apply_settings "Cursor" "$HOME/.config/Cursor/User"
    fi
fi

echo ""
echo "🚀 Step 5: Enabling Custom UI Style..."
echo "   VS Code will reload after applying changes..."

# Create a flag file to indicate first run
FIRST_RUN_FILE="$SCRIPT_DIR/.islands_dark_first_run"
if [ ! -f "$FIRST_RUN_FILE" ]; then
    touch "$FIRST_RUN_FILE"
    echo ""
    echo -e "${YELLOW}📝 Important Notes:${NC}"
    echo "   • IBM Plex Mono and FiraCode Nerd Font Mono need to be installed separately"
    echo "   • After VS Code reloads, you may see a 'corrupt installation' warning"
    echo "   • This is expected - click the gear icon and select 'Don't Show Again'"
    echo ""
    if [ -t 0 ]; then
        read -p "Press Enter to continue and reload VS Code..."
    fi
fi

# Apply custom UI style
echo "   Applying CSS customizations..."

# Reload VS Code to apply changes
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "🎉 Islands Dark theme has been installed!"
echo "   VS Code will now reload to apply the custom UI style."
echo ""

# Use AppleScript on macOS to show a notification and reload VS Code
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e 'display notification "Islands Dark theme installed successfully!" with title "🏝️ Islands Dark"' 2>/dev/null || true
fi

if [ "$HAS_VSCODE" = true ]; then
    echo "   Reloading VS Code..."
    code --reload-window 2>/dev/null || code . 2>/dev/null || true
fi
if [ "$HAS_CURSOR" = true ]; then
    echo "   Reloading Cursor..."
    cursor --reload-window 2>/dev/null || cursor . 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}Done! 🏝️${NC}"
