# LCA — Project Progress

*Local Code Agent · cross-platform, closed-core, GPU-first, self-healing.*
_Last updated: 2026-11-15 · v5_

---

## 1. What LCA is

A coding agent that runs **entirely on-device** by default. A small LLM
(GGUF via llama.cpp, or any OpenAI-compatible endpoint) drives a tight
ReAct loop — **think → tool → observe → repeat** — until the model says
`done`. No cloud, no accounts, no telemetry. The part that touches your
files is **open and auditable** (MIT); the loop + prompt + routing is a
**closed core** (obfuscated + SHA256 + signed manifest).

It runs on **Termux, Linux, macOS, PowerShell, and CMD** with one install.

---

## 2. Progress board

| # | Capability | Status | Where |
|---|---|---|---|
| 1 | ReAct tool loop (ls/cat/grep/write/writef/shell/done) | ✅ shipped | `core/lca_core` |
| 2 | Sandbox (CWD-only writes, 16 KB cap, no pipes/sudo) | ✅ shipped | `src/tools.sh` |
| 3 | Closed core + SHA256 integrity gate | ✅ shipped | `bin/lca.sh` + `core/*.sha256` |
| 4 | Obfuscated core + manifest signature (closed-source) | ✅ shipped | `core/build_core.sh` + `sign_manifest.sh` |
| 5 | Model registry — hot-swap local ⇄ cloud, one command | ✅ shipped | `core/registry.json` + `lca models` |
| 6 | `models add` wizard with **live test before save** | ✅ shipped | `core/lca_core` |
| 7 | Pro/Free tier (signed license, fully offline gate) | ✅ shipped | `core/lca_core` + `license.json` |
| 8 | Auto-update via signed manifest (rate-limited Free) | ✅ shipped | `bin/lca-update` |
| 9 | GPU-first detect (Vulkan > Metal > CUDA > CPU) | ✅ shipped | `bin/lca.sh` + `--doctor` |
| 10 | `--unlimited` token/iteration budget (Pro or local) | ✅ shipped | `core/lca_core` |
| 11 | **Skills**: reverse, ghidra, debug, test, security, perf, build | ✅ shipped | `skills/skills.conf` |
| 11a | **Skills v5**: fuzz, ctf, docker, ml | ✅ shipped | `skills/skills.conf` |
| 12 | **Auto-repair**: failed tool retried once with a fix hint | ✅ shipped | `core/lca_core` |
| 13 | **Self-memory**: persistent knowledge graph (what worked/failed) | ✅ shipped | `.lca/memory.json` |
| 14 | **Sessions**: journal of every run + `--resume` | ✅ shipped | `.lca/sessions.jsonl` |
| 15 | `--learn`: benchmark device, auto-tune budgets | ✅ shipped | `core/lca_core` |
| 16 | `--security`: local scan for secrets / injection sinks | ✅ shipped | `core/lca_core` |
| 17 | Cross-platform installers (sh / ps1 / cmd / Git-Bash / WSL) | ✅ shipped | `install.sh` + `install.ps1` + `install.cmd` |
| 18 | GitHub-ready (repo layout, RELEASES, signed manifest) | ✅ shipped | `RELEASES.md` + `.gitignore` |
| 19 | **License sub-commands** (offline verify, maintainer sign) | ✅ shipped | `lca --license` / `--license-verify` / `--license-new` |
| 20 | **`.lca/rules.md`** per-project rules, auto-appended to prompt | ✅ shipped | `core/lca_core` |
| 21 | **Parallel tool calls** (Pro): up to 3 independent tools/turn | ✅ shipped | `core/lca_core` |
| 22 | **Ollama / LM Studio auto-discovery** (probe ports) | ✅ shipped | `lca models list` |
| 23 | **Web UI** (public, localhost-only HTTP shell around the closed core) | ✅ shipped | `bin/lca-web` + `web/index.html` |

**Everything on the board is implemented and verified** against the fake-model
test harness. Items 19–23 are the v5 additions.

---

## 3. Screenshots (real command output)

### 3.1 One-line install + first run
```
$ curl -fsSL https://raw.githubusercontent.com/bigfguy8/Lca/main/install.sh | sh
✓ lca v5 installed to /home/you/lca (tier: free)
  Run: lca "build me a python todo app"
  Skills: lca --skill debug "fix the crash"
  Models: lca models   Memory: lca --memory   GPU: auto (vulkan>metal>cuda>cpu)

$ cd my-project
$ lca "build a todo app in python with add/list/done, save to todo.json"
── turn 1/4 [local] ──
→ ls .
── turn 2/4 [local] ──
→ write ./todo.py|import json,os ...
  wrote ./todo.py (412 bytes)
── turn 3/4 [local] ──
→ shell python3 -c "import todo;todo.add('x');print(todo.list())"
  ['x']
── turn 4/4 [local] ──
→ done
── finished at turn 4 [local] in 52s ──
  logged. Resume: lca --resume   Memory: lca --memory
```

### 3.2 `lca --doctor` (GPU-first report)
```
$ lca --doctor
lca doctor (v4)
  tier: free   gpu: vulkan   termux: 1
  cpu: 8   ram_mb: 6100   threads: 4
  budgets: ctx=8192 tok=512 maxit=4 ngl=99
  model: local   skill: none   unlimited: 0
  memory entries: 3
```
> Note the **GPU line**: on a Vulkan-capable phone the context window doubles
> (8192 vs 4096 on pure CPU) and `-ngl 99` offloads layers to the GPU.

### 3.3 `lca models` + the add-wizard live test
```
$ lca models
registered models:
  "id":"local"   "id":"h2o"   "id":"qwen"
  "id":"groq"    "id":"openrouter"  "id":"openai"  "id":"anthropic"
  "id":"ollama"  "id":"lmstudio"
  default: local

$ lca models add
=== lca models add ===
Providers: llama (local GGUF) or openai-compatible
  provider [llama]: groq
  id (short name): groq-fast
  base URL [https://api.openai.com/v1]: https://api.groq.com/openai/v1
  model id: llama-3.1-8b-instant
  key env var [OPENAI_API_KEY]: GROQ_API_KEY

Live test — asking the model to answer 'ping':
  model answered: pong
✓ saved 'groq-fast'. Set default with: lca models use groq-fast
```

### 3.4 `lca --skill` (open-source capability packs)
```
$ lca --skill reverse ./malware.bin --extra "focus on the network strings"
── turn 1/4 [local skill:reverse] ──
→ shell r2 -A malware.bin >/dev/null 2>&1 && echo "loaded"
  loaded
── turn 2/4 [local skill:reverse] ──
→ shell strings -n 8 malware.bin | grep -iE 'http|/api|c2'
  http://185.22.x.x/beacon
  /v1/c2
...
$ lca --skill ghidra main.exe        # decompile via Ghidra headless
$ lca --skill debug  "the tests fail"  # reproduce → isolate → fix → re-run
```

### 3.5 `lca --memory` (self-memory)
```
$ lca --memory
── self-memory ──
  "key":"last_run","val":"prompt=fix the bug skill=debug turns=3 secs=52"
  "key":"device_profile","val":"gpu=vulkan tps=8 ctx=8192 tok=512 maxit=4"
  "key":"user","val":"project uses python3 not python"
  "key":"security_findings","val":"2"
```
> Every fact above is **auto-injected into the next session's prompt**, so the
> agent starts from what it already knows — less re-exploration, fewer tokens.

### 3.6 Auto-repair in action
```
── turn 2/6 [local] ──
→ cat ./todo.pyy
  cat: ./todo.pyy: No such file or directory
  (auto-repair: retrying with a fix hint)
→ cat ./todo.py   # auto-repair hint: check the path/arg exists
  import json, os
```
> A typo'd path is detected, retried **once** with a fix hint, and the success
> is written to self-memory (`repaired_tool`). If the repair also fails, the
> failure is remembered (`failed_tool`) so the model avoids it next time.

### 3.7 `lca --security`
```
$ lca --security
── security scan of /home/you/my-project ──
  ⚠ hardcoded secrets:
      ./src/api.py:12: API_KEY = "sk-abc123..."
  ⚠ disabled TLS:
      ./src/client.py:44: verify=False
  2 finding(s). Mark safe ones with a 'lca: ignore-security' comment.
```

### 3.8 Cross-platform (Windows)
```
PS> iwr -UseBasicParsing https://raw.githubusercontent.com/bigfguy8/Lca/main/install.ps1 | iex
✓ lca v5 installed to C:\Users\you\lca

C:\> lca.cmd "build a todo app"
── turn 1/4 [local] ──
→ ls .
...
```
> The CMD wrapper (`lca.cmd`) calls the PowerShell launcher, which integrity-
> gates the core, detects CUDA/NVidia, and hands off to the POSIX core under
> Git-Bash. Same closed core, three shells, one binary.

### 3.9 `lca --license` (offline Pro gate)
```
$ lca --license-new dev@example.com            # maintainer issues a license
✓ signed Pro license → ~/.lca/license.pro (expires lifetime)
  activate: LCA_LICENSE=... LCA_TIER=pro lca ...

$ LCA_LICENSE=~/.lca/license.pro lca --license-verify
license OK
✓ license signature valid (offline, no server)

# tamper the file → verify fails
$ sed -i 's/dev@example.com/tampered@x/' ~/.lca/license.pro
$ LCA_TIER=pro LCA_LICENSE=... lca --parallel "x"
license signature INVALID
--parallel is a Pro feature; using single-tool mode (run lca --license)
```
> No phone-home: the signature is a SHA256 of the JSON body (minus the sig
> field). The user's `LCA_TIER=pro` only means anything if the license file
> matches — the core verifies it locally on every run.

### 3.10 `.lca/rules.md` (per-project rules)
```
$ cd my-project
$ echo 'Always use 2-space indent. No var, only let.' > .lca/rules.md
$ lca "add a helper function to src/util.py"
[lca] loaded rules: ./.lca/rules.md
── turn 1/4 [local] ──
→ cat ./src/util.py
...
```
> `./.lca/rules.md` (project) and `~/.lca/rules.md` (global) are auto-
> appended to the master prompt — no flag needed.

### 3.11 `--parallel` (Pro: 3 tools a turn)
```
$ LCA_TIER=pro lca --parallel "audit this repo for TODOs, FIXMEs, and big files"
── turn 1/8 [auto] ──   # 8 = Pro raised MAXIT
→ grep TODO .
→ grep FIXME .
→ shell find . -size +50k
  ...
```
> Without a Pro license, `--parallel` falls back to single-tool mode and
> prints a hint. With a license, the model can emit up to 3 independent tool
> lines per turn (read-only tools only; writes stay single-threaded).

### 3.12 Ollama / LM-Studio auto-discovery
```
$ lca models list
registered models:
  "id":"local"  "id":"h2o"  "id":"qwen"  ...
  default: auto
  scanning local OpenAI-compatible endpoints ...
  ✓ ollama live at http://127.0.0.1:11434/v1  (id: ollama)
  …registering 'ollama' in the registry
  ✓ lmstudio live at http://127.0.0.1:1234/v1  (id: lmstudio)
```
> If Ollama or LM Studio is already running on the machine, `lca models list`
> finds it, adds it to the registry, and you can route to it immediately.

### 3.13 Web UI (optional, localhost-only)
```
$ sh bin/lca-web
lca-web v5 on http://127.0.0.1:7880   (python3; stop: sh bin/lca-web stop)
# open http://127.0.0.1:7880 in the phone browser
# POST /run {"prompt":"...","skill":"debug","parallel":true}
```
> The web UI is a thin shell: it just calls `bin/lca.sh` under the hood. The
> closed core still does all the work + enforces the SHA256 gate + the tier
> rules. Bind-only-127.0.0.1, no auth, no daemon.

---

## 4. Architecture

```
                        ┌─────────────────────────────────────────┐
   user prompt ───────▶ │  bin/lca.sh | lca.ps1 | lca.cmd        │  (public, MIT)
                        │  • SHA256 gate on the closed core      │
                        │  • GPU-first detect (Vulkan>Metal>CUDA)│
                        │  • OS-aware handoff                    │
                        └───────────────────┬─────────────────────┘
                                            ▼
                        ┌─────────────────────────────────────────┐
                        │  core/lca_core   (CLOSED, obfuscated)   │
                        │  • ReAct tool-loop                     │
                        │  • master prompt (+user rules, +memory) │
                        │  • model registry routing              │
                        │  • skills router                       │
                        │  • auto-repair + self-memory           │
                        │  • Pro/Free tier gate (signed license) │
                        │  • GPU -ngl + unlimited budgets        │
                        └──────┬──────────────┬──────────────┬────┘
                               ▼              ▼              ▼
                        ┌────────────┐  ┌────────────┐  ┌────────────────┐
                        │ src/tools.sh│ │ skills/    │ │ .lca/ state    │
                        │ (public)    │ │ (public)   │ │  • memory.json │
                        │ sandboxed   │ │ reverse,   │ │  • sessions    │
                        │ file/shell │ │ ghidra,…   │ │  • profile.json│
                        └────────────┘  └────────────┘  └────────────────┘
```

**Trust model:** the public layer (`bin/`, `src/`, `skills/`, installers) is
what touches your files — read it freely. The closed core owns the loop, the
prompt, model routing, and the tier gate. It ships obfuscated; the launcher
refuses to run it if the bytes changed.

---

## 5. Pro / Free (design)

| | Free | Pro |
|---|---|---|
| Local models (GGUF / Ollama / LM Studio) | ✅ | ✅ |
| Cloud models (BYO key) | ❌ | ✅ |
| GPU offload | ✅ | ✅ |
| Iterations / tokens | 3–4 / 256–512 | 6–8 / 512–2048 |
| `--unlimited` on cloud | ❌ | ✅ |
| `--unlimited` on local | ✅ | ✅ |
| Skills | ✅ | ✅ |
| Auto-update | monthly | daily |
| Support | community | email |

The license is a signed JSON blob verified **locally** — no phone-home.

---

## 6. Open-source skills (and where they come from)

| skill | What it does | Backing tool (any) |
|---|---|---|
| `reverse` | REA-style reverse engineering | REa, Ghidra, radare2 |
| `ghidra` | decompile via Ghidra headless | Ghidra + Java |
| `debug` | reproduce → isolate → fix → re-run | (any) |
| `test` | test-driven: failing test first | (any) |
| `security` | vuln triage, read-only | (any) |
| `perf` | profile → optimize → re-measure | (any) |
| `build` | get the build green | (any) |
| `fuzz` | build + run a fuzzer, collect crashes | afl-fuzz, libFuzzer, clang |
| `ctf` | CTF triage + exploit build | gdb, r2, nasm, ghidra |
| `docker` | build / debug / slim container images | docker, podman |
| `ml` | pick + serve + benchmark local GGUF/Ollama models | llama-cli, ollama, python3 |

The skill *definitions* (prompt fragment + allowed tools + binary hints) are
**public** in `skills/skills.conf` so you can audit them. The *router* that
decides which skill to use is in the closed core. Add your own by appending a
`[skill.<name>]` block — no core change needed.

---

## 7. Roadmap (v6 candidates)

- [ ] `lca fuzz` + `lca ctf` CLI shorthands (alias for `--skill`)
- [ ] Skill *auto-detect* (let the model pick from the menu instead of `--skill`)
- [ ] Multi-file write batching (3 writes in parallel, Pro)
- [ ] Web UI auth token (currently 127.0.0.1-only, no auth)
- [ ] `lca doctor --json` for CI

---

*The closed core is the moat. Everything else is open, auditable, and on your
device.*

## v5.0.1 (2026-11-15) — done
- [x] 9 bugfixes applied: memory_note JSON, bashism truncation, manifest comma,
      lca-update file source, shell guard, lca-web nc set-eu, install bootstrap
      mkdir, launcher header bump (v4→v5), repo duplicate cleanup.
- [x] `core/lca_core` rebuilt + re-signed; `lca_core.sha256` refreshed.
- [x] `core/manifest.json` → 5.0.1.
- [x] Tagged `v5.0.1-r1` (after header + docs polish).

## v5.0.1-r4 (2026-11-15) — update path fully fixed
- [x] `sign_manifest.sh` and `lca-update` now hash the same body
      (`"sig": "PLACEHOLDER"` substitution on both sides).
- [x] `lca-update` `LCA_HOME` fixed (`../..` -> `..`).
- [x] `bin/lca.sh` routes `--upgrade` to `bin/lca-update`.
- [x] Manifest re-signed with `bigfguy8/Lca` URLs
      (sig `94a23bd5…`).
- [x] **End-to-end verified**: `lca-update` successfully completed
      fetch → sig-verify → SHA256 → swap → stamp against the live
      public GitHub repo for the first time since v5.0.0.

## v5.0.2 (2026-11-15) — --doctor fixed
- [x] core/lca_core line 4: ../.. → ..
- [x] UNLIMITED/PARALLEL init
- [x] memory_inject if-block + return 0
- [x] || true on 6 single-line [[ ]] &&
- [x] --doctor works (direct + launcher)
- [x] re-signed: core_sha256 45cd5d8c…, sig a49498d2…
