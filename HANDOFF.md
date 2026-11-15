# LCA v5.0.2 → v5.0.3 — Handoff & Context
**Date:** 2026-11-15 (late session)
**Repo:** github.com/bigfguy8/Lca (public, MIT)
**Working dir:** ~/lca (Termux)
**Latest tag:** v5.0.2 (tag → 0af7ea7; HEAD = 7950976)
**Purpose of this doc:** preserve full session state so the next
update/upgrade session can resume without re-deriving anything.

═══════════════════════════════════════════════════════════════
## 1. TL;DR
═══════════════════════════════════════════════════════════════

- **The update loop WORKS for the first time since v5.0.0.**
  `bash bin/lca-update` → fetch manifest → verify sig → verify core
  SHA256 → verify registry SHA256 → swap → stamp. Proven live.
- **14 bugs fixed** across launcher / core / updater / manifest /
  signer / installers / docs.
- **9 tags on origin:** v5.0.1, -r1…-r7, v5.0.2.
- **No blocking bugs.** Everything user-facing works.
- **ClozedCode app: keep installed** — not a release blocker (§5.1).

═══════════════════════════════════════════════════════════════
## 2. Current state (what works)
═══════════════════════════════════════════════════════════════

WORKING — verified end-to-end:
  bash bin/lca.sh --help              → full command banner
  bash bin/lca.sh --doctor            → system report (v5.0.2+)   ✅
  bash bin/lca.sh models              → registry list + auto-discovery
  bash bin/lca.sh --upgrade           → routes to bin/lca-update
  bash bin/lca-update                 → full fetch/verify/swap loop
  bash bin/lca.sh "prompt"            → agent loop (needs local model)
  bash bin/lca.sh --chat              → REPL
  bash bin/lca.sh --resume            → session journal
  bash bin/lca.sh --memory            → memory graph
  bash bin/lca.sh --license           → tier/license status

INTEGRITY — all verified:
  manifest core_sha256  = 45cd5d8ce7fd303e20657c0abe5f7133f522baf0d904172f746b1c2cacb9dcff
  local lca_core hash   = 45cd5d8c... (SAME)
  manifest reg_sha256   = 71c6574d0c1936fdba11d36025a0546a9dcc585a97a0825261b6d784d8124599
  local registry hash   = 71c6574d... (SAME)
  manifest sig          = a49498d234eb69185d161981d932f850031e6bf2b91e024b451e6c4ecf46fa94
  lca_core.sha256 file  = 45cd5d8c... (SAME as manifest)

═══════════════════════════════════════════════════════════════
## 3. Version history (git tags)
═══════════════════════════════════════════════════════════════

  v5.0.1        ec190e6  base (core rebuilt, manifest 5.0.1)
  v5.0.1-r1     36ed099  launcher headers v4→v5; release notes
  v5.0.1-r2     36ed099  EMPTY (intended URL fix, silently reverted
                          by sign_manifest template — historical)
  v5.0.1-r3     cf0f8fe  exec sh → exec bash in launcher
  v5.0.1-r4     d75d13a  sig algorithm alignment; LCA_HOME;
                          --upgrade routing; manifest Lca URLs
  v5.0.1-r5     9813cfd  docs polish; URLs normalized; installer 5.0.1
  v5.0.1-r6     b22e9c7  hardening: registry_sha256 verified before swap

Note: v5.0.1-r1 and v5.0.1-r2 point to the SAME commit (36ed099).
That is a historical artifact — do NOT try to "fix" it by force-moving
or deleting. Client-facing functional release is v5.0.1-r4.

═══════════════════════════════════════════════════════════════
## 4. Critical invariants — DO NOT BREAK
═══════════════════════════════════════════════════════════════

4.1 sig algorithm must stay aligned
  sign_manifest.sh computes:  sha256( body with "sig": "PLACEHOLDER" )
  lca-update verifies via:    sed -E 's/"sig": *"[a-f0-9]{64}"/"sig": "PLACEHOLDER"/' | sha256sum
  If either side changes algorithm, the updater breaks for all users.
  Test after ANY change to sign_manifest.sh or lca-update:
    body=$(sed -E 's/"sig": *"[a-f0-9]{64}"/"sig": "PLACEHOLDER"/' core/manifest.json)
    expected=$(grep -oE '"sig": *"[a-f0-9]{64}"' core/manifest.json | grep -oE '[a-f0-9]{64}' | head -1)
    actual=$(printf '%s' "$body" | sha256sum | awk '{print $1}')
    [ "$expected" = "$actual" ] && echo MATCH || echo MISMATCH

4.2 URLs must be bigfguy8/Lca (capital L)
  GitHub repo renamed; raw.githubusercontent.com is case-sensitive
  and does NOT redirect. Any file containing 'bigfguy8/lca' (lowercase)
  will 404. sign_manifest.sh template hardcodes the URL — verify it
  says 'Lca' before re-signing.

4.3 Launcher must exec bash (not sh)
  bin/lca.sh line ~75: exec bash "${CORE}" "$@"
  If changed to 'exec sh', the core's [[ ]] tests fail under dash
  and produce 20+ '[[: not found' errors + false 'registry not found'.

4.4 Core hash and manifest hash must match
  After any edit to core/lca_core:
    1. sha256sum core/lca_core > core/lca_core.sha256  (or use awk form)
    2. bash core/sign_manifest.sh 5.0.1
    3. commit core/lca_core, core/lca_core.sha256, core/manifest.json
       TOGETHER in one commit (partial commits will leave users
       with a broken update that fails SHA verification)

4.5 Manifest registry_sha256 must match core/registry.json
  Same reasoning. If registry.json changes, update manifest's
  registry_sha256 via sign_manifest.sh, re-sign, commit together.

═══════════════════════════════════════════════════════════════
## v5.0.2 (2026-11-15) — core fixes
- [x] LCA_HOME fallback `../..` → `..` in core/lca_core line 4
- [x] `UNLIMITED=0; PARALLEL=0` initialized (set -u safety)
- [x] `memory_inject()` wrapped in `if` + `return 0` (set -e safety)
- [x] `|| true` on 6 single-line `[[ ]] &&` statements
- [x] `--doctor` works (direct + via launcher), verified
- [x] Re-signed: core_sha256 `45cd5d8c…`, sig `a49498d2…`

## 5. Known deferred work (cosmetic / non-blocking)
═══════════════════════════════════════════════════════════════

5.1 ClozedCode app — KEEP INSTALLED (do not recommend uninstall)
  The app is not part of the release path. The earlier cache/batch
  bugs were in the harness tool, not the app. Workflow is Termux +
  Git only. Leave the app alone.

5.2 --version flag — NOT IMPLEMENTED
  bash bin/lca.sh --version → treated as LLM prompt, hangs waiting
  for a model. Users expect a version print.
  Fix (v5.0.2, requires core rebuild + re-sign + retag):
    Edit core/lca_core, add a --version) case that echoes version
    from core/manifest.json, then §4.4 checklist.

5.3 core/lca_core: no shebang
  head -1 core/lca_core → empty
  Works fine when launcher does 'exec bash'. Fails only if user
  runs './core/lca_core' directly. Fix (v5.0.2):
    sed -i '1i #!/usr/bin/env bash' core/lca_core  → §4.4 checklist

5.4 core/lca_core: LCA_HOME fallback uses ../..
  Line 4: LCA_HOME="${LCA_CORE_HOME:-$(cd "$(dirname "${0}")/../.." && pwd)}"
  Goes one level too high when invoked directly. Same fix pattern as
  bin/lca-update got in v5.0.1-r4 (../.. → ..). §4.4 checklist.

5.5 bin/lca.sh: no exec bit
  -rw------- instead of -rwx--. Works via 'bash bin/lca.sh'.
  Fix: chmod +x bin/* install.sh install.ps1 install.cmd publish.sh
       git update-index --chmod=+x <same list>
  No re-sign needed (only affects bin/, not core/).

5.6 lca-web: untested end-to-end
  Fixed in b7841c2 but not run this session. Test:
    sh bin/lca-web         # start on :7880
    curl 127.0.0.1:7880/status
    sh bin/lca-web stop

5.7 Windows launchers (lca.ps1, lca.cmd): untested
  No Windows available. Syntax reviewed clean. Test on any Windows
  machine before publishing a formal v5.0.2 release.

5.8 Self-referential sig — architectural limitation
  The 'sig' field is sha256(body with placeholder). It detects
  transit corruption but is NOT cryptographic authentication.
  Anyone with push access can recompute it. For real origin auth,
  v5.1 should move to Ed25519 or minisign (key-based).
  Not a blocker for v5.0.x.

═══════════════════════════════════════════════════════════════
## 6. Next session priorities (v5.0.2)
═══════════════════════════════════════════════════════════════

Recommended order — stop at any point and ship:

  P1  --version flag in core/lca_core       (§5.2) — high UX value
  P2  shebang + LCA_HOME fix in core        (§5.3, §5.4) — 2 lines
  P3  chmod +x all scripts                  (§5.5) — 1 command
  P4  lca-web smoke test                    (§5.6) — 5 min
  P5  Windows test (if HW available)        (§5.7) — defer
  P6  Ed25519 sig migration                 (§5.8) — v5.1 scope

Each core/lca_core edit requires the §4.4 checklist:
  1. edit core/lca_core
  2. sha256sum core/lca_core | awk '{print $1"  lca_core"}' > core/lca_core.sha256
  3. bash core/sign_manifest.sh 5.0.1
  4. body/recomputed sig check (§4.1)
  5. git add core/lca_core core/lca_core.sha256 core/manifest.json
  6. git commit -m "..." && git tag -a v5.0.2 ...
  7. git push origin main --follow-tags

P1–P3 combined could ship as v5.0.2 in one session.
P4–P6 could ship as v5.0.3 / v5.1 separately.

═══════════════════════════════════════════════════════════════
## 7. How to resume (copy-paste block)
═══════════════════════════════════════════════════════════════

cd ~/lca

# 1. Confirm state is intact
git log --oneline -7
git tag -l 'v5.0.1*'
git status --short          # must be clean

# 2. Confirm integrity
echo -n "manifest core: "; grep -oE '"core_sha256": *"[a-f0-9]{64}"' core/manifest.json | grep -oE '[a-f0-9]{64}'
echo -n "local core:    "; sha256sum core/lca_core | awk '{print $1}'
echo -n "manifest reg:  "; grep -oE '"registry_sha256": *"[a-f0-9]{64}"' core/manifest.json | grep -oE '[a-f0-9]{64}'
echo -n "local reg:     "; sha256sum core/registry.json | awk '{print $1}'

# 3. Confirm scripts run
bash bin/lca.sh --help 2>&1 | head -1
bash bin/lca.sh models 2>&1 | head -2

# 4. Confirm update path (may say 'free tier: N days left' — that's OK)
LCA_CORE_HOME="$HOME/lca" bash bin/lca-update 2>&1 | head -3

# 5. Confirm sig self-consistency
body=$(sed -E 's/"sig": *"[a-f0-9]{64}"/"sig": "PLACEHOLDER"/' core/manifest.json)
expected=$(grep -oE '"sig": *"[a-f0-9]{64}"' core/manifest.json | grep -oE '[a-f0-9]{64}' | head -1)
actual=$(printf '%s' "$body" | sha256sum | awk '{print $1}')
[ "$expected" = "$actual" ] && echo "sig OK" || echo "sig MISMATCH"

All six checks pass → safe to start §6.

═══════════════════════════════════════════════════════════════
## 8. Common pitfalls — read before editing anything
═══════════════════════════════════════════════════════════════

8.1 HARNESS TOOL BUGS (only apply to the AI harness / app-sandbox,
    NOT to Termux). Do NOT use the harness for file writes; do all
    edits in Termux.
    - Batch write bug: all destinations collapse to SD+'/core/lca_core'
      → every file gets last file's content. NEVER batch write.
    - Execute cache bug: write goes to path-keyed cache, not disk.
      read() sees cache; grep sees disk. TRUST grep, not read().
    These are why the earlier sessions burned hours. Now irrelevant
    because we work directly in Termux.

8.2 grep escaped dashes
    'grep -E "\-\-help"' triggers "stray \ before -". Use:
      grep -nF -- '--help' file           (correct)
      grep -nE '(--help|--version)' file  (also correct)

8.3 sh vs bash
    Termux does NOT have /bin/bash — bash is at $PREFIX/bin/bash.
    Always invoke via 'bash script.sh' or ensure 'pkg install termux-exec'
    so #!/usr/bin/env bash works.

8.4 sign_manifest.sh rewrites the whole manifest
    It has a heredoc template that OVERWRITES core/manifest.json.
    Any manual edit to the manifest (URLs, extra fields) will be
    REVERTED the next time sign_manifest.sh runs. To make a
    persistent manifest change, edit the TEMPLATE inside
    sign_manifest.sh, not the manifest file.

8.5 Tag hygiene
    Never force-move a pushed tag. Use sequential suffixes:
    v5.0.1-r1 → -r2 → ... → -r7 etc. Clients that pulled an old
    tag stay on it; new clients get the new tag.

8.6 raw.githubusercontent.com CDN
    After a push, raw URLs can serve stale content for up to ~5 min
    depending on CDN edge. Add '?t=$(date +%s)' cache-buster when
    verifying: curl -sS "URL?t=$(date +%s)"

═══════════════════════════════════════════════════════════════
## 9. Architecture notes (how the pieces fit)
═══════════════════════════════════════════════════════════════

Layers:
  bin/lca.sh          user entry point (bash); routes flags
                      exports LCA_CORE_HOME, LCA_HOME; exec bash core
  core/lca_core       the agent loop (bash script, "obfuscated" =
                      minified / hard to read, NOT compiled)
  src/tools.sh        tool layer invoked by the core
  bin/lca-update      self-updater (bash)
  bin/lca-web         localhost web UI (sh + python3 or nc)
  bin/lca.ps1 / .cmd  Windows launchers (untested)

Config / data:
  core/registry.json  model registry (auto-discovery + user entries)
  core/manifest.json  signed manifest (version, hashes, URLs, sig)
  core/lca_core.sha256  fast local hash check for the launcher
  .lca_last_update    timestamp (free-tier rate limit)
  skills/skills.conf  capability packs registry

Update flow:
  1. bin/lca-update reads update.url from core/manifest.json
  2. curl fetches new manifest
  3. sed replaces sig with "PLACEHOLDER"; sha256 compared to sig field
  4. extract core_sha256, registry_sha256, core_url, registry_url
  5. curl fetch core + registry
  6. verify BOTH sha256 (core then registry) — v5.0.1-r6 adds registry
  7. cp lca_core and registry over existing
  8. rewrite lca_core.sha256 (printf form, not sha256sum)
  9. date +%s > .lca_last_update

═══════════════════════════════════════════════════════════════
## 10. Release process (for future v5.0.x)
═══════════════════════════════════════════════════════════════

1. Edit source (bin/* or core/lca_core or src/*)
2. If core/lca_core changed:
     a. sha256sum core/lca_core | awk '{print $1"  lca_core"}' > core/lca_core.sha256
     b. bash core/sign_manifest.sh <new-version>
     c. Verify sig self-consistency (see §4.1)
3. Update RELEASES.md with new entry
4. Update PROGRESS.md with checklist
5. git add -A
6. git commit -m "<scope>: <summary>"
7. git tag -a v5.0.<X> -m "<message>"
8. git push origin main --follow-tags
9. Verify live:
     curl -sS "https://raw.githubusercontent.com/bigfguy8/Lca/main/core/manifest.json?t=$(date +%s)" | grep -E 'core_url|"sig"'
10. Test end-to-end:
     LCA_CORE_HOME="$HOME/lca" bash bin/lca-update
    (may say 'free tier: N days' — remove stamp to force)
     rm -f .lca_last_update && LCA_CORE_HOME="$HOME/lca" bash bin/lca-update

═══════════════════════════════════════════════════════════════
## 11. Files in repo (map)
═══════════════════════════════════════════════════════════════

.gitignore
LICENSE                  MIT
NOTICE
PROGRESS.md              task board / session log
README.md                user-facing docs
RELEASES.md              changelog
HANDOFF.md               <-- this file
bin/lca.sh               main launcher (bash)
bin/lca.ps1              Windows PowerShell launcher
bin/lca.cmd              Windows CMD wrapper
bin/lca-web              localhost web UI
bin/lca-update           self-updater
core/build_core.sh       rebuild core/lca_core (minify)
core/sign_manifest.sh    write + sign core/manifest.json
core/lca_core            the agent (bash, minified)
core/lca_core.sha256     fast hash check
core/manifest.json       signed manifest
core/registry.json       model registry
install.sh               one-line installer (Linux/Termux/macOS)
install.ps1              Windows installer
install.cmd              Windows CMD installer
publish.sh               release helper
skills/skills.conf       capability pack registry
src/tools.sh             tool layer
test/fake_llama_cli      test stub
web/index.html           web UI page

═══════════════════════════════════════════════════════════════
## 12. Emergency recovery
═══════════════════════════════════════════════════════════════

If the working tree gets corrupted mid-session:
  cd ~/lca
  git fetch origin
  git reset --hard origin/main       # DESTROYS local uncommitted work
  git clean -fdx                     # removes untracked too

If the manifest sig breaks after an edit:
  git checkout origin/main -- core/manifest.json core/lca_core core/lca_core.sha256
  # restores the last known-good signed trio

If lca-update reports 'registry sha mismatch' after a real update:
  This is v5.0.1-r6's guard working — the manifest declares a
  registry hash that doesn't match the fetched file. Check whether
  core/registry.json was edited without re-signing. Fix by running
  sign_manifest.sh and committing all three files together.

End of handoff.

