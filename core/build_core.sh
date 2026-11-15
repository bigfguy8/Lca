#!/usr/bin/env bash
# build_core.sh — maintainer script (kept in the repo; output is closed).
#
# 1. Reads the readable source at core/lca_core
# 2. Obfuscates it:
#      a. strip full-line '#' comments
#      b. base64-wrap the master-prompt block (not grep-able in the shipped file)
#      c. mangle the tool-loop counter i -> it
# 3. Writes the obfuscated version back over core/lca_core
# 4. Computes + writes core/lca_core.sha256 (the launcher's integrity gate)
#
# The shipped core is a bash script (run under bash / Termux). We use `$( )`
# command substitution for the base64 decode, which is safe in bash.
#
# This is anti-inspection, not crypto. Rebuild + re-sign before every release.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
SRC="lca_core"
tmp="$(mktemp)"

# ---- a. strip full-line comments --------------------------------------
grep -vE '^[[:space:]]*#' "${SRC}" > "${tmp}"

# ---- b. base64-wrap the master-prompt block --------------------------
# The block is:   BASE_MASTER="<multi-line text>"
# We capture the whole assignment, base64 the captured text, and rewrite it
# as:   BASE_MASTER="$(printf '%s' '<b64>' | base64 -d)"
if command -v python3 >/dev/null 2>&1; then
  python3 - "${tmp}" <<'PYEOF'
import re, sys, base64
p = sys.argv[1]
s = open(p).read()
m = re.search(r'^BASE_MASTER="((?:.|\n)*?)"\s*$', s, re.M | re.S)
if m:
    b64 = base64.b64encode(m.group(1).encode()).decode()
    repl = 'BASE_MASTER="$(printf \'%s\' \'\'' + b64 + "' | base64 -d)"'
    s = s[:m.start()] + repl + s[m.end():]
    open(p, "w").write(s)
PYEOF
else
  echo "  (no python3 — base64 wrap skipped, comments still stripped)" >&2
fi

# ---- c. (counter mangle dropped — fragile) ---------------------------
# The tool-loop counter `i` is referenced in ~5 places (banner, [${i}] You:,
# turns=${i}, etc.). Hand-mangling it with sed is brittle; the real value of
# the build is hiding the *master prompt* (step b), which is the part that
# reveals the agent's behavior. We leave the counter name as-is.

# ---- install + checksum --------------------------------------------
cp "${tmp}" "${SRC}"
rm -f "${tmp}"

sum="$(sha256sum "${SRC}" | awk '{print $1}')"
printf '%s  %s\n' "${sum}" "${SRC}" > "${SRC}.sha256"
echo "core rebuilt + checksummed."
echo "checksum: ${sum}"
echo "next: sh core/sign_manifest.sh <version>   then commit lca_core + .sha256 + manifest.json"
