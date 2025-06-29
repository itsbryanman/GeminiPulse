# GeminiPulse – Context‑Weaving CLI for Google Gemini

**GeminiPulse** is a *single, portable shell script* that super‑charges the official [`gemini-cli`](https://github.com/google-gemini/gemini-cli) by weaving rich project context into every prompt. No daemons, no background services—just drop it into your repo and watch your AI responses become razor‑sharp.


 ██████╗ ███████╗███╗   ███╗██╗███╗   ██╗██╗    ██████╗ ██╗   ██╗██╗     ███████╗███████╗    
██╔════╝ ██╔════╝████╗ ████║██║████╗  ██║██║    ██╔══██╗██║   ██║██║     ██╔════╝██╔════╝    
██║  ███╗█████╗  ██╔████╔██║██║██╔██╗ ██║██║    ██████╔╝██║   ██║██║     ███████╗█████╗      
██║   ██║██╔══╝  ██║╚██╔╝██║██║██║╚██╗██║██║    ██╔═══╝ ██║   ██║██║     ╚════██║██╔══╝      
╚██████╔╝███████╗██║ ╚═╝ ██║██║██║ ╚████║██║    ██║     ╚██████╔╝███████╗███████║███████╗    
 ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝    ╚═╝      ╚═════╝ ╚══════╝╚══════╝╚══════╝    
                                                                                             



## 1 Why GeminiPulse?

Most wrappers merely pass your text through to the model. GeminiPulse acts as a **Context Weaver**: it scans your codebase, Git history, dependency files, and prior chats, then auto‑builds a world‑class prompt before calling `gemini`. Better prompts → better answers, every time.



## 2 Architecture at a Glance

```text
/your-project/
├── .pulse/                 # Project‑local knowledge base
│   ├── cache/              # ∑ file summaries + embeddings (base64 filenames)
│   ├── history/            # Timestamped chat logs
│   └── config              # Per‑project overrides (YAML)
└── gpulse.sh               # 250‑line POSIX shell script – THAT’S IT
```

> **No binaries. No Node stack.** Delete `.pulse/` and Pulse forgets everything.



## 3 Core Commands

| Command               | Purpose             | How It Works                                   |
| --------------------- | ------------------- | ---------------------------------------------- |
| `gpulse init`         | Bootstrap `.pulse/` | mkdir + write default config                   |
| `gpulse index`        | Summarise codebase  | `find` → `gemini summary` → JSON in `cache/`   |
| `gpulse index --deep` | Build code map      | `ctags`/`tree‑sitter` for function & class map |
| `gpulse ask "…"`      | Context Q\&A        | rank cache + `git diff` ± deps → weave prompt  |
| `gpulse chat`         | Stateful REPL       | Send growing `history/` log each turn          |
| `gpulse commit`       | AI commit msg       | Staged diff → `gemini` → Conventional Commit   |

All verbs live in **one** file (`gpulse.sh`) so you can read, audit, and hack it in minutes.



## 4 Installation

```bash
git clone https://github.com/<org>/gemini‑pulse.git
cd gemini‑pulse
./install.sh   # copies gpulse.sh to /usr/local/bin and chmod +x

gpulse --help  # sanity check
```

Requires: POSIX shell, `git`, and the official `gemini` binary in `$PATH`.



## 5 Quick Start

```bash
# Inside your project
gpulse init
gpulse index          # ~seconds

# Ask a question
gpulse ask "Refactor auth.js to handle JWT expiry gracefully"
```

Pulse selects the most relevant summaries, splices in your uncommitted diff, embeds dependency data from `package.json`, and fires one composite prompt at Gemini. Response quality goes 📈 while token usage goes 📉.



## 6 Personality Presets & Prompt Packs

GeminiPulse ships with **Prompt Packs**—pre‑tuned persona templates you can toggle per query:

| Pack           | Role                       | Sample Trigger                                                      |
| -------------- | -------------------------- | ------------------------------------------------------------------- |
| `architect`    | Big‑picture system design  | `gpulse ask -p architect "Design a microservice layout for…"`       |
| `code‑guru`    | Hyper‑detailed code review | `gpulse ask -p code‑guru "Review security of login.go"`             |
| `doc‑smith`    | Documentation generator    | `gpulse ask -p doc‑smith "Generate README for utils/"`              |
| `regex‑wizard` | Complex pattern crafting   | `gpulse ask -p regex‑wizard "Write a PCRE for RFC‑3339 timestamps"` |
| `rubber‑duck`  | Socratic explainer         | `gpulse chat -p rubber‑duck`                                        |

Prompt Packs live in `.pulse/packs/*.md`. Add your own by dropping a markdown file—first line becomes the system prompt.



## 7 Extending Pulse (add your own verbs)

Because it’s plain shell, new commands take \~10 lines:

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



## 8 Deeper, “Fuzzy” Contextual Understanding

* **Dynamic Context Ranking** – Grep is fine; ranking is better. Pulse scores cached summaries and feeds only the top 3–5 snippets to the model.
* **Code‑Structure Awareness** – `gpulse index --deep` builds a tag map so you can ask:

  ```bash
  gpulse ask "What does calculate_total() in billing.py do?"
  ```
* **Dependency & Environment Awareness** – Pulse parses `package.json`, `requirements.txt`, `pom.xml`, etc. Ask:

  ```bash
  gpulse ask "Use axios to POST JSON in this project"
  ```



## 9 Configuration Reference (`.pulse/config`)

```yaml
model: gemini-1.5-pro
rank_top_k: 5            # how many snippets to embed
packs_enabled:
  - code-guru
  - architect
history_max_tokens: 12000
```

Override any value per‑repo; global defaults live at `~/.config/gpulse/config`.



## 10 Example Workflows

**A. Code Review**

```bash
git add .
gpulse commit                 # AI writes Conventional Commit

gpulse chat -p code-guru      # start review session
```

**B. README Generator**

```bash
gpulse index --deep
gpulse ask -p doc-smith "Generate a top‑tier README for this repo"
```



## 11 Environment Flags & Variables

| Flag / Var       | Purpose            | Default      |
| ---------------- | ------------------ | ------------ |
| `-p, --pack`     | Select Prompt Pack | none         |
| `GPULSE_MODEL`   | Override model     | config value |
| `GPULSE_RANK_K`  | Top‑K snippets     | 5            |
| `GPULSE_DEBUG=1` | Verbose tracing    | off          |

---

## 12 Roadmap

* Vector search backend (SQLite + cosine)
* Plugin directory (`.pulse/plugins/*.sh`)
* Remote cache sync (Git LFS)
* **Inline Diff Reviewer** (`gpulse review`) – annotate diff with AI comments.



## 13 Troubleshooting

| Symptom                      | Fix                                              |
| ---------------------------- | ------------------------------------------------ |
| `command not found: gemini`  | Install `gemini-cli` and ensure it’s in `$PATH`. |
| “No snippets ranked”         | Run `gpulse index` or increase `rank_top_k`.     |
| Model returns 400 tokens max | You’re on a free tier—switch model in config.    |

---

## 14 Contributing

Pull requests welcome. Keep it POSIX, keep it readable. All new verbs **must** fit in `gpulse.sh` or live under `.pulse/plugins/`.



## 15 License

MIT © 2025 \Bryan Cruse\thecorneroftheweb.com
