#!/usr/bin/env bash
set -Eeuo pipefail
INSTALL_DIR="${GPULSE_INSTALL_DIR:-/usr/local/bin}"; BIN="gpulse"; SRC="gpulse.sh"
R="1;31"; G="1;32"; Y="1;33"; B="1;34"

say(){ echo -e "\033[$2m$1\033[0m"; }
die(){ say "$1" "$R"; exit 1; }
need(){ command -v "$1" &>/dev/null || die "Missing '$1'."; }
info(){ say "$1" "$B"; }

say "GeminiPulse installer…" "$B"

# Check basic dependencies
for c in git base64; do need "$c"; done

# Check for gemini - more flexible detection
if command -v gemini &>/dev/null; then
  info "✓ Found gemini at: $(command -v gemini)"
elif [ -x "$HOME/.local/share/pnpm/gemini" ]; then
  info "✓ Found gemini at: $HOME/.local/share/pnpm/gemini"
elif [ -x "$HOME/.npm-global/bin/gemini" ]; then
  info "✓ Found gemini at: $HOME/.npm-global/bin/gemini"
else
  say "⚠ Gemini CLI not found in PATH. You may need to install it:" "$Y"
  say "  npm install -g @google/gemini-cli" "$Y"
  say "  # or" "$Y"
  say "  pnpm add -g gemini-cli" "$Y"
  say "" "$Y"
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || die "Installation cancelled."
fi

# Check if source exists
[ -f "$SRC" ] || die "$SRC not found."

# Install the script
sudo_cmd=""; [ -w "$INSTALL_DIR" ] || sudo_cmd="sudo"
info "Installing $BIN to $INSTALL_DIR..."
$sudo_cmd install -Dm755 "$SRC" "$INSTALL_DIR/$BIN"

# Copy template directory if it exists
if [ -d "template" ]; then
  TEMPLATE_DIR="$HOME/.config/gpulse/template"
  info "Copying template files to $TEMPLATE_DIR..."
  mkdir -p "$TEMPLATE_DIR"
  cp -r template/* "$TEMPLATE_DIR/" 2>/dev/null || true
fi

# Test the installation
"$BIN" help &>/dev/null || die "$BIN self-test failed."

say "✔ Installed to $INSTALL_DIR/$BIN" "$G"
say "✔ Run 'gpulse help' to get started" "$G"
