#!/usr/bin/env bash
# ---------------------------------------------------------------
# gpulse.sh – GeminiPulse CLI  (v0.2.0)
# ---------------------------------------------------------------
set -Eeuo pipefail
IFS=$'\n\t'

# --------- FIND PROJECT ROOT -----------------------------------
find_project_root() {
  local dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.git" ] && [ -d "$dir/.pulse" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# --------- AUTO-DETECT GEMINI -----------------------------------
find_gemini() {
  # If GEMINI_CMD is already set, use it
  if [ -n "${GEMINI_CMD:-}" ] && command -v "$GEMINI_CMD" &>/dev/null; then
    echo "$GEMINI_CMD"
    return 0
  fi
  
  # Check common locations
  local paths=(
    "gemini"                                          # In PATH
    "$HOME/.local/share/pnpm/gemini"                  # pnpm global
    "$HOME/.npm-global/bin/gemini"                    # npm global
    "$HOME/.yarn/bin/gemini"                          # yarn global  
    "$HOME/.bun/bin/gemini"                           # bun global
    "/usr/local/bin/gemini"                           # system-wide
    "$HOME/.local/bin/gemini"                         # user local
    "$HOME/bin/gemini"                                # user bin
  )
  
  for path in "${paths[@]}"; do
    if [ -x "$path" ] 2>/dev/null || command -v "$path" &>/dev/null; then
      echo "$path"
      return 0
    fi
  done
  
  return 1
}

# --------- COLORS ------------------------------------------------
R="1;31"; G="1;32"; Y="1;33"; B="1;34"; C="1;36"; M="1;35"; GRAY="0;37"
say() { echo -e "\033[$2m$1\033[0m"; }
die() { say "❌ ERROR: $1" "$R" >&2; exit "${2:-1}"; }
warn() { say "⚠️  WARNING: $1" "$Y" >&2; }
info() { say "ℹ️  INFO: $1" "$B"; }
success() { say "✅ SUCCESS: $1" "$G"; }
debug() { [ "$DEBUG" = "1" ] && say "🔍 DEBUG: $1" "$GRAY" >&2 || true; }
error() { say "❌ ERROR: $1" "$R" >&2; }

# --------- CONFIG ------------------------------------------------
# Save environment variable values (highest precedence)
ENV_GEMINI_CMD="${GEMINI_CMD:-}"
ENV_GEMINI_MODEL="${GEMINI_MODEL:-}"
ENV_DEBUG="${GPULSE_DEBUG:-}"

# Set defaults
GEMINI_CMD="$(find_gemini || echo "gemini")"
GEMINI_MODEL="gemini-2.5-pro"
PROJECT_ROOT="$(find_project_root || true)"
if [ -z "$PROJECT_ROOT" ]; then
  PROJECT_ROOT="$(pwd)" # fallback for init
fi
PULSE_DIR="$PROJECT_ROOT/.pulse"; CACHE="$PULSE_DIR/cache"; HIST="$PULSE_DIR/history"
VERSION="0.2.0"
DEBUG="0"
RANK_TOP_K="5"

# Load config file if it exists (project-specific overrides)
load_config() {
  local config_file="$1"
  if [ -f "$config_file" ]; then
    [ "$DEBUG" = "1" ] && echo "🔍 DEBUG: Loading config from: $config_file" >&2
    # Parse simple key=value pairs (ignoring comments and empty lines)
    while IFS='=' read -r key value; do
      # Skip comments and empty lines
      [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
      # Trim whitespace
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      # Apply config values
      case "$key" in
        model) GEMINI_MODEL="$value";;
        gemini_cmd) GEMINI_CMD="$value";;
        rank_top_k) RANK_TOP_K="$value";;
        debug) DEBUG="$value";;
        *) [ "$DEBUG" = "1" ] && echo "🔍 DEBUG: Unknown config key: $key" >&2;;
      esac
    done < "$config_file"
  fi
}

# Load configs in order of precedence (lowest to highest)
[ -f "$HOME/.config/gpulse/config" ] && load_config "$HOME/.config/gpulse/config"  # Global config
[ -f "$PULSE_DIR/config" ] && load_config "$PULSE_DIR/config"                      # Project config

# Apply environment variables (highest precedence)
[ -n "$ENV_GEMINI_CMD" ] && GEMINI_CMD="$ENV_GEMINI_CMD"
[ -n "$ENV_GEMINI_MODEL" ] && GEMINI_MODEL="$ENV_GEMINI_MODEL"
[ -n "$ENV_DEBUG" ] && DEBUG="$ENV_DEBUG"

# Export for debug function
export DEBUG

# Show detected settings
show_startup_info() {
  if [ "$DEBUG" = "1" ]; then
    >&2 echo "🔍 DEBUG: Using gemini at: $GEMINI_CMD"
    >&2 echo "🔍 DEBUG: Using model: $GEMINI_MODEL"
  else
    # Show model info for all commands except help
    case "${1:-}" in
      help|-h|--help|"") ;;  # Don't show for help
      *) info "Using model: $GEMINI_MODEL";;
    esac
  fi
}

# --------- ERROR TRAP -------------------------------------------
error_handler() {
  local line_no=$1
  local bash_lineno=$2
  local last_command=$3
  local error_code=$4
  
  error "Command failed with exit code $error_code"
  error "Failed command: $last_command"
  error "Location: Line $line_no"
  [ "$DEBUG" = "1" ] && error "Bash line: $bash_lineno"
  
  # Show context if in debug mode
  if [ "$DEBUG" = "1" ] && [ -f "$0" ]; then
    error "Context:"
    sed -n "$((line_no-2)),$((line_no+2))p" "$0" | while IFS= read -r line; do
      echo "  $line" >&2
    done
  fi
}

trap 'error_handler ${LINENO} ${BASH_LINENO} "$BASH_COMMAND" $?' ERR

# --------- COMMON CHECKS ----------------------------------------
need_repo()   { 
  debug "Checking for git repository..."
  [ -d ".git" ] || die "Not inside a git repo. Run this command from your project root." 
}

need_pulse()  { 
  debug "Checking for .pulse directory..."
  [ -d "$PULSE_DIR" ] || die "Pulse not initialized. Run 'gpulse init' first." 
}

need_cmd()    { 
  debug "Checking for command: $1"
  if ! command -v "$1" &>/dev/null; then
    if [ "$1" = "$GEMINI_CMD" ] || [ "$1" = "gemini" ]; then
      error "Gemini CLI not found!"
      error "Tried to find gemini at: $GEMINI_CMD"
      echo >&2
      error "To fix this, you can:"
      echo >&2 "  1. Install gemini-cli globally:"
      echo >&2 "     npm install -g gemini-cli"
      echo >&2 "     # or"
      echo >&2 "     pnpm add -g gemini-cli"
      echo >&2
      echo >&2 "  2. Set GEMINI_CMD to your gemini path:"
      echo >&2 "     export GEMINI_CMD=/path/to/gemini"
      echo >&2
      echo >&2 "  3. Add your package manager's bin to PATH:"
      echo >&2 "     export PATH=\"\$HOME/.local/share/pnpm:\$PATH\""
      echo >&2
      die "Please install gemini-cli and try again"
    else
      die "Missing required command '$1'. Please install it and try again."
    fi
  fi
}

# --------- SPINNER ----------------------------------------------
spinner() {
  local pid=$1
  local delay=0.1
  
  # Check if process exists
  if ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  
  # Use simpler spinner if terminal doesn't support Unicode well
  if [ "${GPULSE_SIMPLE_SPINNER:-0}" = "1" ]; then
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
      for i in 0 1 2 3; do
        printf "\r%c Working..." "${spinstr:$i:1}"
        sleep $delay
      done
    done
  else
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    # Store messages in separate variables to avoid bash array syntax
    local msg1="🤔 Pondering the cosmos..."
    local msg2="🧠 Neurons firing..."
    local msg3="💭 Deep in thought..."
    local msg4="🔮 Consulting the crystal ball..."
    local msg5="📚 Reading all the books..."
    local msg6="🎯 Focusing intensely..."
    local msg7="⚡ Charging brain cells..."
    local msg8="🌟 Gathering wisdom..."
    local msg9="🔍 Analyzing patterns..."
    local msg10="☕ Sipping virtual coffee..."
    
    # Pick a random message using modulo
    local msg_num=$(($(date +%s) % 10 + 1))
    local msg
    case $msg_num in
      1) msg="$msg1";;
      2) msg="$msg2";;
      3) msg="$msg3";;
      4) msg="$msg4";;
      5) msg="$msg5";;
      6) msg="$msg6";;
      7) msg="$msg7";;
      8) msg="$msg8";;
      9) msg="$msg9";;
      10) msg="$msg10";;
    esac
    
    while kill -0 "$pid" 2>/dev/null; do
      for i in $(seq 0 9); do
        printf "\r%s %s %s" "${spinstr:$i:1}" "$msg" "${spinstr:$i:1}"
        sleep $delay
      done
    done
  fi
  
  printf "\r%-60s\r" ""  # clear the line with more spaces
}

# --------- COMMANDS ---------------------------------------------
init() {
  debug "Initializing pulse directory structure..."
  mkdir -p "$CACHE" "$HIST" "$PULSE_DIR/packs"
  
  # Create default config file
  if [ ! -f "$PULSE_DIR/config" ]; then
    debug "Creating default config file..."
    cat > "$PULSE_DIR/config" <<'CONFIG'
# GeminiPulse Configuration
# Uncomment and modify values as needed

# Model to use (default: gemini-2.5-pro)
# Available: gemini-1.5-flash, gemini-2.0-flash, gemini-2.5-pro, etc.
# model=gemini-2.5-pro

# Path to gemini command (default: auto-detect)
# gemini_cmd=/path/to/gemini

# Number of context snippets to include (default: 5)
# rank_top_k=5

# Debug mode (default: 0)
# debug=0
CONFIG
  fi
  
  # seed default packs if template exists
  if [ -d "$(dirname "$0")/template/packs" ]; then
    debug "Copying template packs..."
    cp -n "$(dirname "$0")"/template/packs/*.md "$PULSE_DIR/packs/" 2>/dev/null || true
  fi
  
  # Create global config directory
  mkdir -p "$HOME/.config/gpulse"
  
  grep -qxF ".pulse/" .gitignore 2>/dev/null || echo ".pulse/" >> .gitignore
  success "Project initialized. Run 'gpulse index' next."
  info "Config file created at: $PULSE_DIR/config"
}

index() {
  need_pulse; need_cmd "$GEMINI_CMD"
  
  # Check for --deep flag (now default) or --simple flag
  local deep=1  # Default to deep indexing
  local target_dir="$PROJECT_ROOT"  # Default to project root
  
  # Parse arguments
  while [ $# -gt 0 ]; do
    case "$1" in
      --deep)
        deep=1
        shift
        ;;
      --simple)
        deep=0
        shift
        ;;
      --dir|--directory)
        if [ -z "$2" ]; then
          die "Missing directory after --dir flag"
        fi
        # Convert relative path to absolute if needed
        if [[ "$2" == /* ]]; then
          target_dir="$2"
        else
          target_dir="$PROJECT_ROOT/$2"
        fi
        # Validate directory exists
        if [ ! -d "$target_dir" ]; then
          die "Directory does not exist: $target_dir"
        fi
        shift 2
        ;;
      *)
        die "Unknown option: $1. Use --deep, --simple, or --dir <directory>"
        ;;
    esac
  done
  
  if [ "$deep" = "1" ]; then
    info "Indexing files in '$target_dir' with deep code analysis..."
  else
    info "Indexing files in '$target_dir' with simple analysis..."
  fi

  local count=0
  find "$target_dir" -type f \
    ! -path "$target_dir/.git/*" ! -path "$target_dir/.github/*" ! -path "$target_dir/node_modules/*" \
    ! -path "$target_dir/.pulse/*" ! -path "$target_dir/.vscode/*" ! -path "$target_dir/.idea/*" \
    ! -path "$target_dir/dist/*" ! -path "$target_dir/build/*" ! -path "$target_dir/out/*" \
    ! -path "$target_dir/target/*" ! -path "$target_dir/bin/*" ! -path "$target_dir/obj/*" \
    ! -path "$target_dir/.next/*" ! -path "$target_dir/.nuxt/*" ! -path "$target_dir/.cache/*" \
    ! -path "$target_dir/coverage/*" ! -path "$target_dir/.nyc_output/*" ! -path "$target_dir/.nyc_output/*" \
    ! -path "$target_dir/.env*" ! -path "$target_dir/.DS_Store" ! -path "$target_dir/Thumbs.db" \
    ! -name "*.log" ! -name "*.lock" ! -name "*.tmp" ! -name "*.temp" ! -name "*.swp" ! -name "*.swo" \
    ! -name ".dockerignore" ! -name ".gitignore" ! -name ".gitattributes" ! -name ".editorconfig" \
    ! -name "package-lock.json" ! -name "yarn.lock" ! -name "pnpm-lock.yaml" ! -name "bun.lockb" \
    ! -name "*.min.js" ! -name "*.min.css" ! -name "*.map" ! -name "*.d.ts" \
    ! -name "*.pyc" ! -name "*.pyo" ! -name "__pycache__" ! -name "*.so" ! -name "*.dylib" ! -name "*.dll" \
    ! -name "*.exe" ! -name "*.o" ! -name "*.a" ! -name "*.class" ! -name "*.jar" ! -name "*.war" \
    ! -name "*.tar.gz" ! -name "*.zip" ! -name "*.rar" ! -name "*.7z" \
  | while read -r f; do
      # Convert absolute path to relative path for cache key (always relative to project root)
      relative_f="${f#$PROJECT_ROOT/}"
      cf="$CACHE/$(printf '%s' "$relative_f" | base64)"
      [ -f "$cf" ] && [ "$deep" = "0" ] && continue
      
      debug "Processing: $relative_f"
      
      # For deep indexing, include more structural information
      if [ "$deep" = "1" ]; then
        # Check file type for code files
        case "$relative_f" in
          *.js|*.ts|*.jsx|*.tsx|*.py|*.rb|*.go|*.java|*.c|*.cpp|*.h|*.hpp|*.rs|*.sh|*.bash)
            # Try to extract functions and classes
            prompt="You are a code analyzer. Please provide ONLY a text summary. Do not execute code or modify files.

Analyze '$relative_f' and create a detailed summary including:
1. Purpose and functionality
2. Main functions/methods and their signatures
3. Classes/types defined
4. Key dependencies/imports
5. Notable patterns or algorithms

Code content:
$(<"$f")"
            ;;
          *.json|*.yaml|*.yml|*.toml|*.xml)
            prompt="You are a configuration analyzer. Please provide ONLY a text summary. Do not execute code or modify files.

Analyze this configuration file '$relative_f' and summarize:
1. Purpose and type of configuration
2. Key settings and their meanings
3. Notable values or patterns

Content:
$(<"$f")"
            ;;
          *)
            # Default deep analysis
            prompt="Please provide ONLY a text summary. Do not execute code or modify files.

Create a comprehensive summary of '$relative_f' including structure, purpose, and key elements:
$(<"$f")"
            ;;
        esac
      else
        # Regular indexing - simple summary
        prompt="Please provide ONLY a text summary. Do not execute code or modify files.

Summarise '$relative_f' for later context:
$(<"$f")"
      fi
      
      if printf '%s\n' "$prompt" | "$GEMINI_CMD" -m "$GEMINI_MODEL" --no-sandbox > "$cf" 2>/dev/null; then
        if [ "$deep" = "1" ]; then
          say "  ✓ deep-cached: $relative_f" "$M"
        else
          say "  ✓ cached: $relative_f" "$C"
        fi
        count=$((count + 1))
      else
        warn "Failed to cache: $relative_f (file might be too large or binary)"
        rm -f "$cf"
      fi
    done
    
  # Generate code map if deep indexing
  if [ "$deep" = "1" ]; then
    info "Generating code structure map..."
    
    # Create a simple code map file
    codemap="$PULSE_DIR/codemap.md"
    {
      echo "# Project Code Map"
      echo "Generated: $(date)"
      echo ""
      echo "## File Structure"
      echo '```'
      find "$target_dir" -type f \
        ! -path "$target_dir/.git/*" ! -path "$target_dir/.github/*" ! -path "$target_dir/node_modules/*" \
        ! -path "$target_dir/.pulse/*" ! -path "$target_dir/.vscode/*" ! -path "$target_dir/.idea/*" \
        ! -path "$target_dir/dist/*" ! -path "$target_dir/build/*" ! -path "$target_dir/out/*" \
        ! -path "$target_dir/target/*" ! -path "$target_dir/bin/*" ! -path "$target_dir/obj/*" \
        ! -path "$target_dir/.next/*" ! -path "$target_dir/.nuxt/*" ! -path "$target_dir/.cache/*" \
        ! -path "$target_dir/coverage/*" ! -path "$target_dir/.nyc_output/*" ! -path "$target_dir/.nyc_output/*" \
        ! -path "$target_dir/.env*" ! -path "$target_dir/.DS_Store" ! -path "$target_dir/Thumbs.db" \
        ! -name "*.log" ! -name "*.lock" ! -name "*.tmp" ! -name "*.temp" ! -name "*.swp" ! -name "*.swo" \
        ! -name ".dockerignore" ! -name ".gitignore" ! -name ".gitattributes" ! -name ".editorconfig" \
        ! -name "package-lock.json" ! -name "yarn.lock" ! -name "pnpm-lock.yaml" ! -name "bun.lockb" \
        ! -name "*.min.js" ! -name "*.min.css" ! -name "*.map" ! -name "*.d.ts" \
        ! -name "*.pyc" ! -name "*.pyo" ! -name "__pycache__" ! -name "*.so" ! -name "*.dylib" ! -name "*.dll" \
        ! -name "*.exe" ! -name "*.o" ! -name "*.a" ! -name "*.class" ! -name "*.jar" ! -name "*.war" \
        ! -name "*.tar.gz" ! -name "*.zip" ! -name "*.rar" ! -name "*.7z" \
        -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.sh" \
        -o -name "*.go" -o -name "*.java" -o -name "*.rb" | sort
      echo '```'
      echo ""
      
      # If ctags is available, use it
      if command -v ctags &>/dev/null; then
        debug "Using ctags for function mapping..."
        echo "## Functions and Classes (via ctags)"
        echo '```'
        (cd "$target_dir" && ctags -R --fields=+KS --output-format=json 2>/dev/null | head -100 || \
        ctags -R -f - --format=2 --sort=yes 2>/dev/null | head -100 || true)
        echo '```'
      else
        debug "ctags not found, using grep for function detection..."
        echo "## Functions and Methods (via pattern matching)"
        echo '```'
        # Simple function detection for common languages
        (cd "$target_dir" && grep -r -n -E "(function\s+\w+|def\s+\w+|func\s+\w+|class\s+\w+|public\s+\w+|private\s+\w+)" \
          --include="*.js" --include="*.ts" --include="*.py" --include="*.go" \
          --include="*.java" --include="*.rb" --include="*.sh" \
          --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.pulse 2>/dev/null | head -100 || true)
        echo '```'
      fi
    } > "$codemap"
    
    success "Deep index complete. Processed files: $count. Code map saved to $codemap"
  else
    success "Index complete. Processed files: $count"
  fi
}

ask() {
  need_pulse; need_cmd "$GEMINI_CMD"
  # --- parse -p flag (pack) -------------------------------------
  pack=""; if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--pack" ]; then
    pack=$2; shift 2 || die "Missing pack name after -p flag"
  fi
  [ $# -gt 0 ] || die "Usage: gpulse ask [-p pack] \"<question>\""
  q="$*"

  debug "Processing question: $q"

  # system prompt from pack (if any)
  sys=""
  if [ -n "$pack" ]; then
    pk="$PULSE_DIR/packs/${pack}.md"
    if [ -f "$pk" ]; then 
      sys="$(cat "$pk")"
      debug "Using prompt pack: $pack"
    else 
      warn "Pack '$pack' not found; continuing without it."
    fi
  fi

  # Add explicit instruction to prevent code execution
  if [ -z "$sys" ]; then
    sys="You are a helpful assistant. Please provide text-only responses. Do not attempt to execute code, modify files, or use any tools."
  fi

  # gather context (top 5 hits)
  ctx=""
  debug "Searching for context matches..."
  for w in $q; do grep -lri "$w" "$CACHE" || true; done | sort -u | head -n 5 \
  | while read -r hit; do file=$(basename "$hit" | base64 -d)
      debug "Adding context from: $file"
      ctx+="\n--- $file ---\n$(<"$hit")"
    done

  # add uncommitted diff
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    diff=$(git diff --staged; git diff)
    if [ -n "$diff" ]; then
      debug "Adding uncommitted diff to context"
      ctx+="\n--- Uncommitted Diff ---\n$diff"
    fi
  fi

  prompt="$sys

Use the following context only if relevant to answer the question.
$ctx

Question: $q

Remember: Provide ONLY a text response. Do not attempt to execute code or modify files."

  info "Asking Gemini..."
  if printf '%s\n' "$prompt" | "$GEMINI_CMD" -m "$GEMINI_MODEL" --no-sandbox; then
    debug "Response received successfully"
  else
    error "Failed to get response from Gemini"
    die "Make sure '$GEMINI_CMD' is properly installed and configured"
  fi
}

chat() {
  need_pulse; need_cmd "$GEMINI_CMD"
  # --- parse -p flag (pack) -------------------------------------
  pack=""; if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--pack" ]; then
    pack=$2; shift 2 || die "Missing pack name after -p flag"
  fi

  # create session file
  session="$HIST/$(date +%Y%m%d_%H%M%S).md"
  debug "Creating session file: $session"
  touch "$session" || die "Failed to create session file: $session"
  
  # system prompt from pack (if any)
  sys=""
  if [ -n "$pack" ]; then
    pk="$PULSE_DIR/packs/${pack}.md"
    if [ -f "$pk" ]; then 
      sys="$(cat "$pk")"
      info "Using prompt pack: $pack"
    else 
      warn "Pack '$pack' not found at $pk; continuing without it."
    fi
  fi
  
  # Add explicit instruction if no pack
  if [ -z "$sys" ]; then
    sys="You are a helpful assistant in a chat conversation. Please provide text-only responses. Do not attempt to execute code, modify files, or use any tools."
  fi

  info "Starting chat session (commands: exit, flush)"
  [ "$DEBUG" = "1" ] && debug "Session file: $session"
  
  # conversation history for current session
  conversation=""
  
  while true; do
    # prompt for input
    printf "\n"
    say "You> " "$G"
    read -r input || break
    
    # handle special commands
    case "$input" in
      exit|quit|bye) 
        success "Chat session saved to: $session"
        break;;
      flush|reset|clear) 
        conversation=""
        info "Context flushed (history preserved in $session)"
        continue;;
      "") continue;;
    esac
    
    debug "Gathering context for: $input"
    
    # gather fresh context for each turn
    ctx=""
    for w in $input; do grep -lri "$w" "$CACHE" 2>/dev/null || true; done | sort -u | head -n 5 \
    | while read -r hit; do 
        file=$(basename "$hit" | base64 -d)
        debug "Adding context from: $file"
        ctx+="\n--- $file ---\n$(<"$hit")"
      done
    
    # add uncommitted diff
    if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
      diff=$(git diff --staged; git diff)
      if [ -n "$diff" ]; then
        debug "Adding uncommitted diff to context"
        ctx+="\n--- Uncommitted Diff ---\n$diff"
      fi
    fi
    
    # build prompt with conversation history
    prompt="$sys

$conversation

Use the following context only if relevant.
$ctx

User: $input

Remember: Provide ONLY a text response. Do not attempt to execute code or modify files."
    
    # get response with spinner
    say "\nGemini> " "$C"
    
    # Check gemini command before running
    if ! command -v "$GEMINI_CMD" >/dev/null 2>&1; then
      error "Command '$GEMINI_CMD' not found!"
      error "Please install the Gemini CLI or set GEMINI_CMD environment variable"
      error "Example: export GEMINI_CMD=/path/to/gemini"
      warn "Skipping this question..."
      continue
    fi
    
    # Run gemini in background and show spinner
    response_file=$(mktemp) || die "Failed to create temporary file"
    debug "Running command: $GEMINI_CMD -m $GEMINI_MODEL --no-sandbox (output to $response_file)"
    
    # Start gemini process - use explicit command with flags
    (printf '%s\n' "$prompt" | "$GEMINI_CMD" -m "$GEMINI_MODEL" --no-sandbox > "$response_file" 2>&1) &
    gemini_pid=$!
    debug "Started Gemini process with PID: $gemini_pid"
    
    # Show spinner while waiting
    spinner $gemini_pid
    
    # Wait for completion and check exit status
    if wait $gemini_pid; then
      response=$(<"$response_file")
      if [ -z "$response" ]; then
        warn "Gemini returned empty response"
        response="(No response from Gemini)"
      fi
    else
      error "Gemini command failed!"
      error "Command output:"
      cat "$response_file" >&2
      response="Error: Failed to get response from Gemini. See error messages above."
    fi
    
    rm -f "$response_file"
    
    [ -n "$response" ] && echo "$response"
    
    # update conversation history
    conversation+="
User: $input

--- Assistant ---
$response
"
    
    # save to session file
    {
      echo "## $(date '+%Y-%m-%d %H:%M:%S')"
      echo "**User:** $input"
      echo ""
      echo "**Gemini:** $response"
      echo ""
      echo "---"
      echo ""
    } >> "$session"
  done
}

commit_msg() {
  need_repo; need_cmd "$GEMINI_CMD"
  debug "Checking for staged changes..."
  diff=$(git diff --staged)
  [ -n "$diff" ] || die "No staged changes. Use 'git add' to stage files first."
  
  info "Generating commit message..."
  msg=$(printf 'You are a commit message generator. Please provide ONLY a text response with a Conventional Commit message. Do not attempt to execute code or modify files.\n\nWrite a Conventional Commit message for this diff:\n%s\n' "$diff" | "$GEMINI_CMD" -m "$GEMINI_MODEL" --no-sandbox 2>&1)
  
  if [ $? -ne 0 ]; then
    error "Failed to generate commit message"
    error "Output: $msg"
    die "Check that Gemini is properly configured"
  fi
  
  say "\nSuggested commit message:" "$Y"
  echo "$msg"
  echo
  read -rp "Commit with this message? [y/N] " ans
  [[ $ans =~ ^[Yy]$ ]] || { warn "Commit cancelled."; exit 0; }
  
  if git commit -m "$msg"; then
    success "Changes committed successfully!"
  else
    error "Git commit failed"
    die "Check git status and try again"
  fi
}

scaffold_ci() {
  need_repo
  info "Setting up CI scaffold..."
  CI=".github/workflows/ci.yml"; mkdir -p "$(dirname "$CI")"
  
  if [[ -e "$CI" ]]; then
    warn "CI workflow already exists at $CI"
  else
    debug "Creating CI workflow at $CI"
    cat >"$CI" <<'YML'
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
  fi

  if [[ -e LICENSE ]]; then
    warn "LICENSE file already exists"
  else
    debug "Creating LICENSE file"
    cat > LICENSE <<LICENSE
MIT License
Copyright (c) $(date +%Y) Bryan Cruse
Permission is hereby granted, free of charge, to any person obtaining a copy
...
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND...
LICENSE
  fi

  git add "$CI" LICENSE
  if git diff --cached --quiet; then 
    info "Nothing new to commit."
  else
    git commit -m "chore: add CI workflow and MIT license"
    git push -u origin "$(git branch --show-current)"
    success "CI scaffold created and pushed!"
  fi
}

help() {
cat <<EOF
GeminiPulse $VERSION  – context‑weaving wrapper for Google Gemini

Usage: gpulse <command> [args]

Commands:
  init           initialise .pulse/ in repo
  index          build context cache (basic summaries)
  index --deep   build detailed code map with function analysis
  ask [-p pack] "question"  ask with context (optional prompt-pack)
  chat [-p pack] interactive stateful conversation
  commit-msg     AI‑generated Conventional Commit
  scaffold-ci    add CI workflow + MIT license
  help           show this message

Chat commands:
  exit/quit/bye  end chat session
  flush/reset    clear context (preserves history)

Environment variables:
  GEMINI_CMD     path to gemini binary (default: auto-detect)
  GEMINI_MODEL   model to use (default: gemini-2.5-pro)
  GPULSE_DEBUG   set to 1 for verbose debug output
  GPULSE_SIMPLE_SPINNER  set to 1 for ASCII-only spinner

Debug mode:
  GPULSE_DEBUG=1 gpulse chat    # shows detailed logging
  
Error logs are color-coded:
  $(say "❌ Errors in red" "$R")
  $(say "⚠️  Warnings in yellow" "$Y")
  $(say "ℹ️  Info in blue" "$B")
  $(say "✅ Success in green" "$G")
EOF
}

# --------- MAIN --------------------------------------------------
cmd=${1:-help}; shift || true

# Show startup info after config is loaded
show_startup_info "$cmd"

case "$cmd" in
  init) init;;
  index) index "$@";;
  ask) ask "$@";;
  chat) chat "$@";;
  commit|commit-msg) commit_msg;;
  scaffold-ci) scaffold_ci;;
  help|-h|--help) help;;
  *) die "Unknown command '$cmd'";;
esac
