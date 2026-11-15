#!/usr/bin/env bash
# lca v4 installer — cross-platform (Termux / Linux / macOS / Git-Bash).
#
# One-line form (from GitHub):
#   curl -fsSL https://raw.githubusercontent.com/<YOU>/lca/main/install.sh | sh
#
# Self-contained form:
#   bash install.sh          # from the lca/ project dir
#
# v4 changes:
#   - installs the full tree (bin/{lca.sh,lca.ps1,lca.cmd}, skills/, core/)
#   - creates `lca` as a shim that auto-picks the right launcher:
#       * Unix/Termux   -> bin/lca.sh
#       * Windows (Git-Bash/WSL) -> bin/lca.sh (POSIX) or bin/lca.ps1
#   - re-signs the core checksum for this install
#   - builds llama.cpp if deps + network are present
#
# No sudo. Termux + macOS + Linux friendly.

set -eu

LCA_DIR="${LCA_INSTALL_DIR:-$HOME/lca}"
LCA_SRC="${LCA_SRC_DIR:-.}"
LCA_TIER="${LCA_TIER:-free}"

# ---- 1. locate project ------------------------------------------------
[[ -d "${LCA_SRC}/bin" && -d "${LCA_SRC}/core" && -d "${LCA_SRC}/src" ]] || {
  echo "install.sh: cannot find project layout in ${LCA_SRC}" >&2; exit 1
}

# ---- 2. install -------------------------------------------------------
rm -rf "${LCA_DIR}"
mkdir -p "${LCA_DIR}"
cp -R "${LCA_SRC}/." "${LCA_DIR}/"
chmod +x "${LCA_DIR}/bin/lca.sh" "${LCA_DIR}/bin/lca-update" "${LCA_DIR}/core/lca_core" "${LCA_DIR}/src/tools.sh" 2>/dev/null || true

# re-sign the core checksum for this install
core="${LCA_DIR}/core/lca_core"
sum="$(sha256sum "${core}" 2>/dev/null | awk '{print $1}' || shasum -a 256 "${core}" | awk '{print $1}')"
printf '%s  %s\n' "${sum}" "lca_core" > "${LCA_DIR}/core/lca_core.sha256"

# ---- 3. create the `lca` command (a smart shim) ------------------------
mkdir -p "${HOME}/.local/bin"
cat > "${HOME}/.local/bin/lca" <<SHIM
#!/bin/sh
# lca v4 shim — picks the right launcher for this OS.
LCA_HOME="${LCA_HOME:-$HOME/lca}"
case "\$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)  # Windows via Git-Bash / WSL
    if command -v powershell >/dev/null 2>&1; then
      exec powershell -NoProfile -ExecutionPolicy Bypass -File "\${LCA_HOME}/bin/lca.ps1" "\$@"
    else
      exec sh "\${LCA_HOME}/bin/lca.sh" "\$@"
    fi ;;
  Darwin)  exec /bin/sh "\${LCA_HOME}/bin/lca.sh" "\$@" ;;
  Linux|Android|*) exec sh "\${LCA_HOME}/bin/lca.sh" "\$@" ;;
esac
SHIM
chmod +x "${HOME}/.local/bin/lca"
ln -sf "${LCA_DIR}/bin/lca-update" "${HOME}/.local/bin/lca-update" 2>/dev/null || true
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) : ;;
  *) echo "export PATH=\"\$PATH:${HOME}/.local/bin\"" >> "${HOME}/.profile" ;;
esac

# ---- 4. llama.cpp (optional) ------------------------------------------
cli="${LCA_DIR}/llama.cpp/build/bin/llama-cli"
if [[ ! -x "${cli}" ]]; then
  if command -v git && command -v cmake && command -v clang; then
    echo "install.sh: building llama.cpp (needs ~1GB disk)…" >&2
    ( cd "${LCA_DIR}" && git clone --depth 1 https://github.com/ggml-org/llama.cpp \
        && cd llama.cpp \
        && cmake -B build -DBUILD_SHARED=OFF \
        && cmake --build build --config Release -j4 ) \
      || echo "llama.cpp build failed — local models will not work"
  else
    echo "install.sh: llama.cpp missing. pkg: git cmake clang libopenblas-static (Termux) or apt/brew equivalents."
  fi
fi

# ---- 5. sanity ---------------------------------------------------------
if "${HOME}/.local/bin/lca" --doctor >/dev/null 2>&1; then
  echo "✓ lca v4 installed to ${LCA_DIR} (tier: ${LCA_TIER})"
  echo "  Run: lca \"build me a python todo app\""
  echo "  Skills: lca --skill debug \"fix the crash\"   (reverse/ghidra/test/perf/build/security)"
  echo "  Models: lca models   Memory: lca --memory   GPU: auto (vulkan>metal>cuda>cpu)"
else
  echo "install.sh: sanity check failed — see errors above." >&2
  exit 1
fi
