#!/usr/bin/env bash
# lca v5 — cross-platform launcher (public, MIT)
#
# This launcher is POSIX-portable: it runs under Termux, Linux, macOS, and even
# inside a Git-Bash / WSL environment on Windows. For native Windows use the
# companion PowerShell launcher: bin/lca.ps1  (also callable from CMD via
# bin/lca.cmd, which just wraps the .ps1).
#
# Responsibilities (public, auditable):
#   1. Locate the project (LCA_HOME, or ./.., or ~/.lca)
#   2. Verify the closed core's SHA256 (refuse to run if tampered)
#   3. Auto-detect GPU (Vulkan / Metal / CUDA) and set LCA_GPU
#   4. Hand off to the core, which does the actual agent work
#
# The closed core (core/lca_core) owns: the tool-loop, master prompt, model
# routing, tier gate, skills, auto-repair, self-memory. That part is
# obfuscated + checksummed and is NOT in this public launcher.

set -eu

# ---- 1. locate the project -------------------------------------------
if [[ -n "${LCA_HOME:-}" ]]; then
  :
elif [[ -d "$(dirname "${0}")/../core" ]]; then
  LCA_HOME="$(cd "$(dirname "${0}")/.." && pwd)"
else
  LCA_HOME="${HOME}/.lca"
fi
[[ -d "${LCA_HOME}" ]] || { echo "lca: project not found (set LCA_HOME)" >&2; exit 1; }

CORE="${LCA_HOME}/core/lca_core"
SUM="${LCA_HOME}/core/lca_core.sha256"
[[ -f "${CORE}" ]] || { echo "lca: core missing: ${CORE} (run install.sh)" >&2; exit 1; }
[[ -f "${SUM}"  ]] || { echo "lca: checksum missing: ${SUM}" >&2; exit 1; }

# ---- 2. integrity gate ------------------------------------------------
actual="$(sha256sum "${CORE}" 2>/dev/null | awk '{print $1}' \
        || shasum -a 256 "${CORE}" 2>/dev/null | awk '{print $1}')"
expected="$(awk '{print $1}' "${SUM}")"
if [[ -z "${actual}" || "${actual}" != "${expected}" ]]; then
  echo "lca: CORE INTEGRITY CHECK FAILED" >&2
  echo "  expected: ${expected}" >&2
  echo "  actual:   ${actual:-<no sha tool>}" >&2
  echo "The closed core was modified. Rebuild + re-sign with:" >&2
  echo "  bash ${LCA_HOME}/core/build_core.sh" >&2
  exit 2
fi

# ---- 3. GPU-first detection (public helper; the core reads LCA_GPU) --
detect_gpu() {
  # Order of preference: Vulkan (Termux/Android + Linux), Metal (macOS),
  # CUDA (Linux/Windows), then CPU. Sets LCA_GPU to: vulkan|metal|cuda|cpu
  LCA_GPU="cpu"
  if [[ -d /dev/dri ]] && command -v vulkaninfo >/dev/null 2>&1; then
    LCA_GPU="vulkan"
  elif command -v vulkaninfo >/dev/null 2>&1; then
    LCA_GPU="vulkan"
  elif [[ -d /System/Library/Frameworks/Metal.framework ]]; then
    LCA_GPU="metal"
  elif command -v nvidia-smi >/dev/null 2>&1; then
    LCA_GPU="cuda"
  fi
  # Termux: opengl es via /dev/dri/0
  [[ -d /dev/dri && -n "$(ls /dev/dri 2>/dev/null | grep card || true)" ]] && LCA_GPU="vulkan"
}
detect_gpu

# ---- 4. hand off to the closed core ----------------------------------
export LCA_CORE_HOME="${LCA_HOME}"
export LCA_GPU="${LCA_GPU:-cpu}"
exec bash "${CORE}" "$@"
