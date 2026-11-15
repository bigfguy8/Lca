# LCA — Local Code Agent

**A fully-local, phone-first coding agent.** No cloud, no accounts, no API keys
by default. A small LLM runs a tight ReAct-style loop — think → call a tool
(`ls`/`cat`/`grep`/`write`/`writef`/`shell`) → observe → repeat — until it says
`done`. Works on a 6 GB-RAM phone with a 1.5 B Q4 model in ~10–25 s per turn.

**Runs on Termux, Linux, macOS, PowerShell, and CMD** with one install.
**GPU-first** (Vulkan > Metal > CUDA > CPU), **self-healing** (auto-repair),
**self-memory** (remembers what worked), and **open-source skills**
(reverse/REA, Ghidra, debug, test, security, perf, build, fuzz, ctf, docker, ml).

v5 adds: **`lca --license`** (offline sign/verify), **`.lca/rules.md`**
(per-project rules), **`--parallel`** (Pro: 3 tools a turn), **Ollama/LM-Studio
auto-discovery**, and an optional **localhost web UI**.

> 📄 See **`PROGRESS.md`** for the full progress board + command screenshots.

## One-line install + run

```bash
# from GitHub (after you publish the repo)
#   Linux / Termux / macOS:
curl -fsSL https://raw.githubusercontent.com/bigfguy8/lca/main/install.sh | sh
#   Windows (PowerShell):
iwr -UseBasicParsing https://raw.githubusercontent.com/bigfguy8/lca/main/install.ps1 | iex

# self-contained, no network needed for the agent itself
bash /sdcard/download/lca/install.sh        # Termux / Linux / macOS
powershell -File lca\install.ps1            # Windows
```

Then:
```bash
lca "build a todo app in python"        # default: local GGUF
lca --fast "fix the bug in main.py"     # auto-pick the cheapest model that fits
lca --use groq "explain this code"      # cloud, pay-per-token (Pro)
lca models add                          # wizard: register any provider in seconds
lca --security                          # local scan: secrets / injection sinks
lca --sessions                          # journal of every run
lca --resume                            # continue from the last session
lca --doctor                            # what the agent detected (incl. GPU)
lca --learn                             # benchmark + auto-tune budgets
lca --memory                            # self-memory graph
lca --chat                              # REPL, no tools
lca --skill reverse ./bin               # open-source capability packs
lca --unlimited "big refactor"          # no token/iteration cap
lca --parallel "audit TODOs, FIXMEs, big files"  # 3 tools/turn (Pro)
lca --license                           # show / verify / sign a Pro license
lca models list                         # auto-discovers Ollama/LM Studio
sh bin/lca-web                          # optional localhost web UI
```

## Skills (open-source capability packs)

```bash
lca --skill debug  "the tests fail"     # reproduce → isolate → fix → re-run
lca --skill reverse ./malware.bin       # REA / Ghidra / radare2
lca --skill ghidra main.exe             # decompile via Ghidra headless
lca --skill security .                  # vuln triage (read-only)
lca --skill perf  "slow endpoint"       # profile → optimize → re-measure
lca --skill build  "get it building"    # fix the cause, not the symptom
lca --skill fuzz  ./binary              # build + run a fuzzer
lca --skill ctf   challenge.tar         # CTF triage + exploit
lca --skill docker .                    # build / slim container images
lca --skill ml    .                     # pick + serve + benchmark a local model
```
Skill definitions are **public** in `skills/skills.conf` (prompt fragment +
allowed tools + binary hints). Add your own by appending a `[skill.<name>]`
block — no core change. The *router* that picks a skill lives in the closed
core.

## The model registry (the heart of it)

The closed core ships a **registry** (`core/registry.json`) that maps short ids to
real endpoints. Hot-swap between local and cloud with **one command, no rebuild**:

```bash
lca models            # list registered models
lca models add        # wizard: provider → base/model → key (hidden) → LIVE TEST → save
lca models use groq   # set default
lca models test groq  # ping a registered model, time it
lca models remove h2o
```

| id | What it is | Cost |
|---|---|---|
| `local` | GGUF via llama-cli (default) | free, offline |
| `ollama` / `lmstudio` | local servers, no key | free |
| `groq` | cloud, fast, cheap | pay-per-token (Pro) |
| `openrouter` | 100+ models, one key | pay-per-token (Pro) |
| `openai` / `anthropic` | your own keys | pay-per-token (Pro) |

Add **any** OpenAI-compatible endpoint (Together, DeepSeek, Mistral, your own
server, EURI) in seconds with `lca models add` — the wizard live-tests the model
before saving it, so a bad entry never ends up in your registry.

## Pro / Free tiers

| | Free | Pro |
|---|---|---|
| Local models (GGUF/Ollama/LM Studio) | ✅ | ✅ |
| Cloud models (bring-your-own-key) | ❌ | ✅ |
| Tool-loop iterations | 3–4 | 6–8 |
| Tokens per turn | 256–512 | 512–2048 |
| `--parallel` (3 tools/turn) | ❌ | ✅ |
| `--fast` cloud model-picking | local only | cloud first |
| Updates | monthly (rate-limited) | daily |
| Support | community | email |

The gate is a **signed license file** (`~/.lca/license.json`, SHA256 over its
body) — no phone-home, no server-side auth. You sign licenses with
`lca --license-new <email>` and hand them out; the core verifies locally on
every run. `lca --license-verify` confirms a license offline.

```bash
export LCA_TIER=pro
export LCA_LICENSE=$HOME/.lca/license.json
lca "prompt"
```

## Per-project rules (`.lca/rules.md`)

Drop a `.lca/rules.md` in any project directory (or `~/.lca/rules.md`
globally) and it is **auto-appended to the master prompt** — no flag needed.
Use it to pin down project-specific conventions:

```bash
mkdir -p my-project/.lca
cat > my-project/.lca/rules.md <<EOF
# Project rules
- 2-space indent, no tabs.
- No var, only let/const.
- Tests live in tests/ and run via `npm test`.
EOF
cd my-project && lca "add a new module"
# [lca] loaded rules: ./.lca/rules.md
```

## Web UI (optional, localhost-only)

```bash
sh bin/lca-web              # start on 127.0.0.1:7880 (python3 or nc)
# open http://127.0.0.1:7880 in the phone browser
sh bin/lca-web stop
```
The web UI is a thin shell: it calls `bin/lca.sh` under the hood, so the closed
core still does all the work + enforces the SHA256 gate + the tier rules.
Bound to `127.0.0.1` only, no auth, no daemon. Endpoints: `GET /`, `GET
/status`, `GET /models`, `POST /run`.

## GPU-first (fast on any system)

The launcher auto-detects the best accelerator in preference order:
**Vulkan → Metal → CUDA → CPU** (Termux/Android use Vulkan via `/dev/dri`).
When a GPU is found, the core offloads layers (`-ngl 99`) and **doubles the
context window**, so the same model runs faster and holds more state.

```bash
lca --doctor      # shows gpu: vulkan|metal|cuda|cpu + the chosen budgets
lca --unlimited "large refactor"   # no token/iteration cap (Pro, or local-only)
```

## Keep it fast on any system

`lca` auto-detects Termux vs Linux/macOS, RAM, CPU threads, and GPU, then picks
a context/token/iteration budget that fits:

```bash
lca --doctor      # see exactly what it detected and why
lca --learn       # benchmark your model, write a tuned .lca/profile.json
```

The learned profile is auto-loaded on every run, so the agent gets faster the
more you use it on a given device.

## Auto-update (stay current)

```bash
lca-update        # fetch signed manifest, verify, swap core + registry
```

The manifest (`core/manifest.json`) is signed; the updater refuses anything whose
signature doesn't match. Free tier: at most one update a month. Pro: unlimited.
You publish new manifests to GitHub releases; users just run the command.

## Architecture

```
lca/
├── bin/lca.sh            # public Unix launcher: SHA256 gate + GPU detect + exec
├── bin/lca.ps1           # public Windows launcher (PowerShell): same gate, CUDA detect
├── bin/lca.cmd           # CMD shim → lca.ps1
├── bin/lca-update        # public updater: fetch + verify + swap
├── bin/lca-web           # public localhost web UI (python3 or nc fallback)
├── src/tools.sh          # public tool layer: sandboxed shell/file ops (MIT)
├── skills/skills.conf    # public skills: reverse/ghidra/debug/test/security/perf/build/fuzz/ctf/docker/ml
├── web/index.html        # minimal HTML UI served by lca-web
├── core/
│   ├── lca_core          # CLOSED-SOURCE: loop, master prompt, model routing,
│   │                     #   skills router, auto-repair, self-memory, tier gate,
│   │                     #   license sub-commands, .lca/rules.md, --parallel,
│   │                     #   Ollama/LM-Studio discovery
│   ├── lca_core.sha256   # integrity gate — launcher refuses to run if core edited
│   ├── registry.json     # model registry (user-editable; closed core reads it)
│   ├── manifest.json     # signed manifest for auto-update (v5.0.0)
│   ├── build_core.sh     # (maintainer) obfuscate + checksum the core
│   └── sign_manifest.sh  # (maintainer) sign a release manifest
├── install.sh            # one-line installer: Termux / Linux / macOS / Git-Bash
├── install.ps1           # one-line installer: Windows (PowerShell)
├── install.cmd           # CMD wrapper for install.ps1
└── README.md / PROGRESS.md / RELEASES.md
```

The **public layer** (`bin/`, `src/`, `skills/`, installers) is MIT and fully
auditable — that's the part that touches your files. The **closed core** owns
the loop, the master prompt, model routing, skills, auto-repair, self-memory,
and tier gating. It ships obfuscated and the launcher verifies its SHA256
before every run.

## Security

- `write`/`writef` are confined to the current directory (16 KB cap per write).
- `shell` refuses pipes, redirects, `sudo`, and `rm -rf /`.
- `lca --security` greps the project for hardcoded secrets, `eval`/`exec`,
  string-built SQL, shell-injection sinks, disabled TLS verification, open CORS,
  and weak hashes — entirely local.

## Requirements

- Termux (or any POSIX system with `sh`, `cmake`, `clang`, `git`, `curl`)
- ~1 GB disk for the `llama.cpp` build
- 2–3 GB free RAM at runtime (1.5 B Q4 + 4 k context)
- A GGUF model (`qwen2.5-coder-1.5b-instruct-q4_k_m.gguf` is a great 6 GB pick)
- For cloud models (Pro): `curl` + an API key in the environment

## License

`bin/`, `src/`, `install.sh`, `README.md` — MIT.
`core/` — proprietary (obfuscated + SHA256 + manifest signature).
See `LICENSE` and `NOTICE`.
