# **GeminiPulse** — Context‑Weaving CLI for Google Gemini  
Single‑script shell tool that feeds Gemini your code, diffs & deps for smarter, project‑aware answers.

<p align="center">
  <!-- language -->
  <img src="https://img.shields.io/badge/Shell‑Bash-4EAA25?logo=gnu-bash&logoColor=white&style=for-the-badge" alt="Shell">
  <!-- lines of code -->
 <img src="https://img.shields.io/github/release-date/itsbryanman/GeminiPulse?label=Latest%20Release&style=flat-square" alt="Release Date">

  <!-- tests -->
  <img src="https://img.shields.io/badge/Tests-Passing-brightgreen?style=for-the-badge" alt="Tests">
  <!-- POSIX -->
  <img src="https://img.shields.io/badge/POSIX‑Compliant-blue?style=for-the-badge" alt="POSIX">
  <!-- Gemini -->
  <img src="https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=googlegemini&logoColor=white" alt="Gemini">
</p>

<p align="center">
  <!-- visitor counter (match case) -->
  <img src="https://visitor-badge.laobi.icu/badge?page_id=itsbryanman.GeminiPulse&style=flat-square&color=brightgreen" alt="Visitors">
  <!-- maintained -->
  <img src="https://img.shields.io/maintenance/yes/2025?style=flat-square&color=success" alt="Maintained">
  <img src="https://tokei.rs/b1/github/itsbryanman/GeminiPulse?category=code" alt="Lines of Code">
  

</p>




```
 ██████╗ ███████╗███╗   ███╗██╗███╗   ██╗██╗                  ██████╗ ██╗   ██╗██╗     ███████╗███████╗    
██╔════╝ ██╔════╝████╗ ████║██║████╗  ██║██║                  ██╔══██╗██║   ██║██║     ██╔════╝██╔════╝    
██║  ███╗█████╗  ██╔████╔██║██║██╔██╗ ██║██║                  ██████╔╝██║   ██║██║     ███████╗█████╗      
██║   ██║██╔══╝  ██║╚██╔╝██║██║██║╚██╗██║██║                  ██╔═══╝ ██║   ██║██║     ╚════██║██╔══╝      
╚██████╔╝███████╗██║ ╚═╝ ██║██║██║ ╚████║██║                  ██║     ╚██████╔╝███████╗███████║███████╗    
 ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝                  ╚═╝      ╚═════╝ ╚══════╝╚══════╝╚══════╝    
                                                                                                                     
```


## 1 Why GeminiPulse?

Most wrappers merely pass your text through to the model. GeminiPulse acts as a **Context Weaver**: it scans your codebase, Git history, dependency files, and prior chats, then auto‑builds a world‑class prompt before calling `gemini`. Better prompts → better answers, every time.

**NEW: Run from anywhere in your project!** GeminiPulse now automatically detects your project root and works from any subdirectory.

## 2 Architecture at a Glance

```text
/your-project/
├── .pulse/                 # Project‑local knowledge base
│   ├── cache/              # ∑ file summaries + embeddings (base64 filenames)
│   ├── history/            # Timestamped chat logs
│   ├── packs/              # Prompt pack templates
│   ├── codemap.md          # Generated code structure (deep indexing)
│   └── config              # Per‑project overrides
└── gpulse.sh               # Single POSIX shell script – THAT'S IT
```

> **No binaries. No Node stack.** Delete `.pulse/` and Pulse forgets everything.

## 3 Core Commands

| Command                    | Purpose                    | How It Works                                   |
| -------------------------- | -------------------------- | ---------------------------------------------- |
| `gpulse init`              | Bootstrap `.pulse/`        | mkdir + write default config                   |
| `gpulse index`             | **Deep** codebase analysis | `find` → `gemini analysis` → JSON in `cache/`  |
| `gpulse index --simple`    | Basic codebase summary     | Simple summaries for quick indexing            |
| `gpulse index --dir <path>`| **Targeted** indexing      | Index only specific directories                |
| `gpulse ask "…"`           | Context Q&A                | rank cache + `git diff` ± deps → weave prompt  |
| `gpulse chat`              | Stateful REPL              | Send growing `history/` log each turn          |
| `gpulse commit`            | AI commit msg              | Staged diff → `gemini` → Conventional Commit   |

All verbs live in **one** file (`gpulse.sh`) so you can read, audit, and hack it in minutes.

## 4 Installation

```bash
git clone https://github.com/<org>/gemini‑pulse.git
cd gemini‑pulse
./install.sh   # copies gpulse.sh to /usr/local/bin and chmod +x

gpulse --help  # sanity check
```

Requires: POSIX shell, `git`, and the official `gemini` binary in `$PATH`.

## 5 Quick Start

```bash
# Inside your project (or any subdirectory!)
gpulse init
gpulse index          # Deep analysis by default

# Ask a question
gpulse ask "Refactor auth.js to handle JWT expiry gracefully"
```

Pulse selects the most relevant summaries, splices in your uncommitted diff, embeds dependency data from `package.json`, and fires one composite prompt at Gemini. Response quality goes 📈 while token usage goes 📉.

## 6 Advanced Indexing Options

### 🚀 Run from Anywhere
```bash
# Works from project root
cd /path/to/your/project
gpulse index

# Works from any subdirectory
cd /path/to/your/project/src/components
gpulse index  # Automatically finds project root
```

### 📁 Targeted Indexing
```bash
# Index only source code
gpulse index --dir src/

# Index only tests
gpulse index --dir tests/

# Index specific service
gpulse index --dir cmd/services/korl-acsg

# Index with simple analysis
gpulse index --dir src/ --simple
```

### 🔍 Smart File Filtering
GeminiPulse automatically excludes:
- **Build artifacts**: `dist/`, `build/`, `target/`, `bin/`, `obj/`
- **Dependencies**: `node_modules/`, `.next/`, `.nuxt/`, `.cache/`
- **Version control**: `.git/`, `.github/`
- **IDE files**: `.vscode/`, `.idea/`
- **Config files**: `.gitignore`, `.dockerignore`, lock files
- **Binary files**: executables, libraries, archives, minified files

## 7 Personality Presets & Prompt Packs

GeminiPulse ships with **Prompt Packs**—pre‑tuned persona templates you can toggle per query:

| Pack           | Role                       | Sample Trigger                                                      |
| -------------- | -------------------------- | ------------------------------------------------------------------- |
| `architect`    | Big‑picture system design  | `gpulse ask -p architect "Design a microservice layout for…"`       |
| `code‑guru`    | Hyper‑detailed code review | `gpulse ask -p code‑guru "Review security of login.go"`             |
| `doc‑smith`    | Documentation generator    | `gpulse ask -p doc‑smith "Generate README for utils/"`              |
| `regex‑wizard` | Complex pattern crafting   | `gpulse ask -p regex‑wizard "Write a PCRE for RFC‑3339 timestamps"` |
| `rubber‑duck`  | Socratic explainer         | `gpulse chat -p rubber‑duck`                                        |

Prompt Packs live in `.pulse/packs/*.md`. Add your own by dropping a markdown file—first line becomes the system prompt.

## 8 Extending Pulse (add your own verbs)

Because it's plain shell, new commands take ~10 lines:

```sh
# gpulse blame – Explain why a line changed
elif [ "$cmd" = "blame" ]; then
  file=$2 line=$3
  diff=$(git blame -L $line,$line $file)
  prompt="Why did this change matter?\n$diff"
  echo "$prompt" | gemini
  exit 0
fi
```

Commit the chunk, run `gpulse blame myfile.py 42`, done.

## 9 Deeper, "Fuzzy" Contextual Understanding

* **Dynamic Context Ranking** – Grep is fine; ranking is better. Pulse scores cached summaries and feeds only the top 3–5 snippets to the model.
* **Code‑Structure Awareness** – `gpulse index` (now deep by default) builds a tag map so you can ask:

  ```bash
  gpulse ask "What does calculate_total() in billing.py do?"
  ```
* **Dependency & Environment Awareness** – Pulse parses `package.json`, `requirements.txt`, `pom.xml`, etc. Ask:

  ```bash
  gpulse ask "Use axios to POST JSON in this project"
  ```

## 10 Configuration Reference (`.pulse/config`)

```yaml
# Model configuration
model: gemini-2.5-pro
gemini_cmd: gemini

# Indexing options
rank_top_k: 5            # how many snippets to embed
debug: 0                 # enable debug output

# Global config at ~/.config/gpulse/config
# Project config at .pulse/config (overrides global)
```

### Environment Variables
| Variable        | Purpose            | Default      |
| --------------- | ------------------ | ------------ |
| `GEMINI_CMD`    | Override gemini path| auto-detect  |
| `GEMINI_MODEL`  | Override model     | config value |
| `GPULSE_DEBUG`  | Enable debug mode  | 0            |

## 11 Example Workflows

**A. Code Review**
```bash
git add .
gpulse commit                 # AI writes Conventional Commit
gpulse chat -p code-guru      # start review session
```

**B. README Generator**
```bash
gpulse index --dir src/       # Index only source code
gpulse ask -p doc-smith "Generate a top‑tier README for this repo"
```

**C. Service-Specific Analysis**
```bash
cd cmd/services/my-service
gpulse index --dir .          # Index only this service
gpulse ask "How does authentication work here?"
```

**D. Quick Documentation**
```bash
gpulse index --dir docs/ --simple  # Quick index of docs
gpulse ask "Summarize the API documentation"
```

## 12 Migration Guide

### From Previous Versions
- **Deep indexing is now default**: Use `--simple` for basic indexing
- **Improved exclusions**: Some files that were previously indexed may now be skipped
- **Subdirectory support**: Run from anywhere in your project
- **Targeted indexing**: Use `--dir` for faster, focused indexing

### Existing Caches
- All existing caches remain compatible
- No changes needed for existing workflows
- New features are additive and backward-compatible

## 13 Troubleshooting

### Common Issues
```bash
# "Not inside a git repo"
# Solution: Run from project root or any subdirectory within the repo
cd /path/to/your/project
gpulse init

# "Pulse not initialized"
# Solution: Initialize the project
gpulse init

# "Command not found"
# Solution: Install gemini CLI
npm install -g gemini-cli
# or
pnpm add -g gemini-cli
```

### Debug Mode
```bash
GPULSE_DEBUG=1 gpulse index  # Enable verbose output
```

## 14 Contributing

Pull requests welcome. Keep it POSIX, keep it readable. All new verbs **must** fit in `gpulse.sh` or live under `.pulse/plugins/`.

## 15 License

MIT © 2025 \Bryan Cruse\thecorneroftheweb.com

## if you liked what i made
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/itsbryandude)
<a href="https://coff.ee/bryanc910">
  <img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png"
       width="140" alt="Buy Me A Coffee">
</a>

