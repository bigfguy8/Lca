#!/usr/bin/env bash
# build_core.sh — maintainer script (kept in the repo; output is closed).
#
# 1. Reads the readable source at core/lca_core
# 2. Obfuscates it:
#      a. strip full-line '#' comments
#      b. base64-wrap the master-prompt block (not grep-able in the shipped file)
# 3. Writes the obfuscated version back over core/lca_core
# 4. Computes + writes core/lca_core.sha256 (the launcher's integrity gate)
#
# Pure POSIX + coreutils (base64, sed, awk) — no python required. The shipped
# core is a bash script (run under bash / Termux); the base64 decode uses
# `$( )` command substitution, which is safe in bash.
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
# spanning several lines, ending with the line whose first chars are just `"`.
# We: locate the start line, find the matching end (the line that is exactly
# the closing quote), capture the body in between, base64-encode it, and
# replace the whole range with a single-line decode:
#     BASE_MASTER="$(printf '%s' '<b64>' | base64 -d)"
start="$(grep -n '^BASE_MASTER=' "${tmp}" | head -1 | cut -d: -f1)"
if [[ -n "${start}" ]]; then
  # The block ends at the line that ENDS with a closing double-quote
  # (the last line of the multi-line string literal). Find it after ${start}.
  end="$(awk -v s="${start}" 'NR>=s && /"[[:space:]]*$/ {print NR; exit}' "${tmp}")"
  if [[ -n "${end}" && "${end}" -gt "${start}" ]]; then
    # Capture the body: strip the leading 'BASE_MASTER="' from the first line
    # and the trailing '"' from the last line.
    body="$(sed -n "${start},${end}p" "${tmp}" \
            | sed "1s/^BASE_MASTER=\"//; \${s/\"$//} ")"
    b64="$(printf '%s' "${body}" | base64 | tr -d '\n')"
    # Build the single-line decode replacement in a variable (no nested-quote
    # printf pitfalls), then splice: lines before start + decode + lines after.
    decode_line="BASE_MASTER=\"\$(printf '%s' '${b64}' | base64 -d)\""
    { sed -n "1,$((start-1))p" "${tmp}"
      printf '%s\n' "${decode_line}"
      sed -n "$((end+1)),\$p" "${tmp}"
    } > "${tmp}.wrap"
    mv "${tmp}.wrap" "${tmp}"
    echo "  base64-wrapped the master-prompt block (lines ${start}-${end})"
  else
    echo "  WARN: could not locate the BASE_MASTER block end; leaving prompt plaintext" >&2
  fi
fi

# ---- install + checksum --------------------------------------------
cp "${tmp}" "${SRC}"
rm -f "${tmp}"

sum="$(sha256sum "${SRC}" | awk '{print $1}')"
printf '%s  %s\n' "${sum}" "${SRC}" > "${SRC}.sha256"
echo "core rebuilt + checksummed."
echo "checksum: ${sum}"
echo "next: sh core/sign_manifest.sh <version>   then commit lca_core + .sha256 + manifest.json"
