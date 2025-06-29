#!/usr/bin/env bash
# ---------------------------------------------------------------
# gpulse.sh – GeminiPulse CLI  (v0.2.0)
# ---------------------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'

# --------- CONFIG ------------------------------------------------
GEMINI_CMD="${GEMINI_CMD:-gemini}"     # override with env
PULSE_DIR=".pulse"; CACHE="$PULSE_DIR/cache"; HIST="$PULSE_DIR/history"
GLOBAL_PACKS_DEST_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/gpulse/templates/packs"
VERSION="0.2.0"

# --------- COLORS ------------------------------------------------
R="1;31"; G="1;32"; Y="1;33"; B="1;34"; C="1;36"
say() { echo -e "\033[$2m$1\033[0m"; }
die() { say "$1" "$R"; exit "${2:-1}"; }

# --------- COMMON CHECKS ----------------------------------------
need_repo()   { [ -d ".git" ] || die "Not inside a git repo."; }
need_pulse()  { [ -d "$PULSE_DIR" ] || die "Run 'gpulse init' first."; }
need_cmd()    { command -v "$1" &>/dev/null || die "Missing '$1'."; }

# --------- COMMANDS ---------------------------------------------
init() {
  mkdir -p "$CACHE" "$HIST" "$PULSE_DIR/packs"
  # seed default packs
  if [ -d "$GLOBAL_PACKS_DEST_DIR" ]; then
    cp -n "$GLOBAL_PACKS_DEST_DIR"/*.md "$PULSE_DIR/packs/" 2>/dev/null || true
  elif [ -d "$(dirname "$0")/template/packs" ]; then
    cp -n "$(dirname "$0")"/template/packs/*.md "$PULSE_DIR/packs/" 2>/dev/null || true
  fi
  grep -qxF ".pulse/" .gitignore 2>/dev/null || echo ".pulse/" >> .gitignore
  say "✔ Project initialised. Run 'gpulse index' next." "$G"
}

index() {
  need_pulse; need_cmd "$GEMINI_CMD"
  say "Indexing project…" "$B"

  find . -type f \
    ! -path "./.git/*" ! -path "./node_modules/*" ! -path "./$PULSE_DIR/*" \
    ! -name "*.log" ! -name "*.lock" \
  | while read -r f; do
      cf="$CACHE/$(printf '%s' "$f" | base64)"
      [ -f "$cf" ] && continue
      prompt="Summarise '$f' for later context:\n$(<"$f")"
      printf '%s\n' "$prompt" | "$GEMINI_CMD" > "$cf" || true
      say "  cached: $f" "$C"
    done
  say "✔ Index complete." "$G"
}

ask() {
  need_pulse; need_cmd "$GEMINI_CMD"
  # --- parse -p flag (pack) -------------------------------------
  pack=""; if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--pack" ]; then
    pack=$2; shift 2 || die "Missing pack name after -p"
  fi
  [ $# -gt 0 ] || die "gpulse ask [-p pack] \"<question>\""
  q="$*"

  # system prompt from pack (if any)
  sys=""
  if [ -n "$pack" ]; then
    pk="$PULSE_DIR/packs/${pack}.md"
    if [ -f "$pk" ]; then sys="$(cat "$pk")"
    else say "⚠ Pack '$pack' not found; continuing." "$Y"; fi
  fi

  # gather context (top 5 hits)
  ctx=""
  for w in $q; do grep -lri "$w" "$CACHE" || true; done | sort -u | head -n 5 \
  | while read -r hit; do file=$(basename "$hit" | base64 -d)
      ctx+="\n--- $file ---\n$(<"$hit")"
    done

  # add uncommitted diff
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    diff=$(git diff --staged; git diff)
    [ -n "$diff" ] && ctx+="\n--- Uncommitted Diff ---\n$diff"
  fi

  prompt="$sys
Use the following context only if relevant.
$ctx
--- Question ---
$q"

  say "🧠 Asking Gemini…" "$C"
  printf '%s\n' "$prompt" | "$GEMINI_CMD"
}

commit_msg() {
  need_repo; need_cmd "$GEMINI_CMD"
  diff=$(git diff --staged); [ -n "$diff" ] || die "No staged changes."
  msg=$(printf 'Write a Conventional Commit for diff:\n%s\n' "$diff" | "$GEMINI_CMD")
  say "$msg" "$Y"
  read -rp "Commit with this message? [y/N] " ans
  [[ $ans =~ ^[Yy]$ ]] || die "Aborted."
  git commit -m "$msg"
  say "✔ Committed." "$G"
}

scaffold_ci() {
  need_repo
  CI=".github/workflows/ci.yml"; mkdir -p "$(dirname "$CI")"
  [[ -e "$CI" ]] || cat >"$CI" <<'YML'
name: CI
on:
  push: { branches: [ main ] }
  pull_request: { branches: [ main ] }
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: sudo apt-get update && sudo apt-get install -y shellcheck
      - run: shellcheck gpulse.sh
YML

  [[ -e LICENSE ]] || cat > LICENSE <<LICENSE
MIT License
Copyright (c) $(date +%Y) Bryan Cruse
Permission is hereby granted, free of charge, to any person obtaining a copy
...
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND...
LICENSE

  git add "$CI" LICENSE
  if git diff --cached --quiet; then say "Nothing to commit." "$Y"
  else
    git commit -m "chore: add CI workflow and MIT license"
    git push -u origin "$(git branch --show-current)"
    say "✔ CI scaffold pushed." "$G"
  fi
}

help() {
cat <<EOF
GeminiPulse $VERSION  – context‑weaving wrapper for Google Gemini

Usage: gpulse <command> [args]

Commands:
  init           initialise .pulse/ in repo
  index          build context cache
  ask [-p pack] "question"  ask with context (optional prompt-pack)
  commit-msg     AI‑generated Conventional Commit
  scaffold-ci    add CI workflow + MIT license
  help           show this message
EOF
}

# --------- MAIN --------------------------------------------------
cmd=${1:-help}; shift || true
case "$cmd" in
  init) init;;
  index) index;;
  ask) ask "$@";;
  commit|commit-msg) commit_msg;;
  scaffold-ci) scaffold_ci;;
  help|-h|--help) help;;
  *) die "Unknown command '$cmd'";;
esac
