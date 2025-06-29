#!/usr/bin/env bash
set -Eeuo pipefail
INSTALL_DIR="/usr/local/bin"; BIN="gpulse"; SRC="gpulse.sh"
R="1;31"; G="1;32"; Y="1;33"; B="1;34"

say(){ echo -e "\033[$2m$1\033[0m"; }
die(){ say "$1" "$R"; exit 1; }
need(){ command -v "$1" &>/dev/null || die "Missing '$1'."; }

say "GeminiPulse installer…" "$B"
for c in node npm git base64; do need "$c"; done
npm list -g @google/gemini-cli &>/dev/null || \
  die "Install gemini CLI first: npm i -g @google/gemini-cli"

[ -f "$SRC" ] || die "$SRC not found."
sudo_cmd=""; [ -w "$INSTALL_DIR" ] || sudo_cmd="sudo"
$sudo_cmd install -Dm755 "$SRC" "$INSTALL_DIR/$BIN"
"$BIN" --help &>/dev/null || die "$BIN self‑test failed."
say "✔ Installed to $INSTALL_DIR/$BIN" "$G"
