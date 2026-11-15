#!/bin/sh
# lca v5 installer — cross-platform (Termux / Linux / macOS / Git-Bash).
#
# One-line form (from GitHub):
#   curl -fsSL https://raw.githubusercontent.com/bigfguy8/Lca/main/install.sh | sh
#
# Self-contained form:
#   sh install.sh          # from the lca/ project dir
#
# Pure POSIX sh (toybox / dash / bash / zsh). No bashisms. No sudo.
#
# What it does:
#   1. Copies the project to $HOME/lca (or LCA_INSTALL_DIR)
#   2. Re-signs the core checksum for this install (SHA256 over lca_core)
#   3. Writes a smart `lca` shim into ~/.local/bin (picks lca.sh / lca.ps1 by OS)
#   4. Optionally builds llama.cpp if git+cmake+clang are present
#   5. Sanity-checks with `lca --doctor`

set -eu

LCA_DIR="${LCA_INSTALL_DIR:-$HOME/lca}"
LCA_SRC="${LCA_SRC_DIR:-.}"
LCA_TIER="${LCA_TIER:-free}"

# ---- 1. locate project ------------------------------------------------
# Detect the bootstrap case: no local source layout in LCA_SRC.
BOOTSTRAPPED=0
if [ ! -d "${LCA_SRC}/bin" ] || [ ! -d "${LCA_SRC}/core" ] || [ ! -d "${LCA_SRC}/src" ]; then
  # If LCA_INSTALL_DIR was explicitly given and already holds a checkout, reuse it.
  if [ -n "${LCA_INSTALL_DIR:-}" ] && [ -d "${LCA_DIR}/bin" ] && [ -d "${LCA_DIR}/core" ]; then
    LCA_SRC="${LCA_DIR}"
    BOOTSTRAPPED=0
  elif command -v git >/dev/null 2>&1; then
    # LCA_INSTALL_DIR may not propagate through `VAR=x cmd | sh`, so fall back
    # to a safe throwaway dir rather than clobbering a dev ~/lca.
    BOOTDIR="${LCA_INSTALL_DIR:-$HOME/lca-install}"
    echo "install.sh: no local source — cloning into ${BOOTDIR}…" >&2
    rm -rf "${BOOTDIR}"
    # git clone creates the target dir itself; do NOT mkdir -p first.
    git clone --depth 1 https://github.com/bigfguy8/Lca.git "${BOOTDIR}" >&2
    LCA_DIR="${BOOTDIR}"
    LCA_SRC="${BOOTDIR}"
    BOOTSTRAPPED=1          # source == install dir; skip the rm/cp below
  else
    echo "install.sh: cannot find project layout in ${LCA_SRC} and git is missing." >&2
    echo "install.sh: run from the lca/ project dir (sh install.sh) or install git first." >&2
    exit 1
  fi
fi

# Safety: never install into a dir that is the same as (or a parent of) the
# source we just located — that would `rm -rf` the source before the copy.
if [ "${BOOTSTRAPPED}" -eq 0 ]; then
  case "${LCA_SRC}" in
    "${LCA_DIR}"|"${LCA_DIR}/"*)
      echo "install.sh: LCA_SRC (${LCA_SRC}) is inside LCA_DIR (${LCA_DIR}); refusing to self-delete." >&2
      echo "install.sh: pass LCA_INSTALL_DIR pointing elsewhere, or run from a clean checkout." >&2
      exit 1 ;;
  esac
  case "${LCA_DIR}" in
    "${LCA_SRC}"|"${LCA_SRC}/"*)
      echo "install.sh: LCA_DIR (${LCA_DIR}) is the source dir; install to a fresh dir instead." >&2
      echo "install.sh: try: LCA_INSTALL_DIR=\$HOME/lca-install sh install.sh" >&2
      exit 1 ;;
  esac
fi

# ---- 2. install -------------------------------------------------------
if [ "${BOOTSTRAPPED}" -eq 1 ]; then
  # The clone IS the install dir; nothing to copy.
  :
else
  rm -rf "${LCA_DIR}"
  mkdir -p "${LCA_DIR}"
  cp -R "${LCA_SRC}/bin" "${LCA_DIR}/bin"
  cp -R "${LCA_SRC}/core" "${LCA_DIR}/core"
  cp -R "${LCA_SRC}/src" "${LCA_DIR}/src"
  cp -R "${LCA_SRC}/skills" "${LCA_DIR}/skills" 2>/dev/null || true
  cp -R "${LCA_SRC}/web" "${LCA_DIR}/web" 2>/dev/null || true
  cp "${LCA_SRC}"/LICENSE "${LCA_SRC}"/NOTICE "${LCA_SRC}"/README.md "${LCA_DIR}/" 2>/dev/null || true
fi
chmod +x "${LCA_DIR}/bin/lca.sh" "${LCA_DIR}/bin/lca-update" "${LCA_DIR}/bin/lca-web" \
         "${LCA_DIR}/core/lca_core" "${LCA_DIR}/src/tools.sh" 2>/dev/null || true

# re-sign the core checksum for this install
core="${LCA_DIR}/core/lca_core"
sum="$(sha256sum "${core}" 2>/dev/null | awk '{print $1}' || shasum -a 256 "${core}" 2>/dev/null | awk '{print $1}' || true)"
if [ -n "${sum}" ]; then
  printf '%s  lca_core\n' "${sum}" > "${LCA_DIR}/core/lca_core.sha256"
else
  echo "install.sh: warning — could not compute SHA256; integrity gate will fail" >&2
fi

# ---- 3. create the `lca` command (a smart shim) ------------------------
mkdir -p "${HOME}/.local/bin"
cat > "${HOME}/.local/bin/lca" <<SHIM
#!/bin/sh
# lca v5 shim — picks the right launcher for this OS.
LCA_HOME="\${LCA_HOME:-$HOME/lca}"
case "\$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
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
# link the updater
ln -sf "${LCA_DIR}/bin/lca-update" "${HOME}/.local/bin/lca-update" 2>/dev/null || true
# link the web UI
ln -sf "${LCA_DIR}/bin/lca-web" "${HOME}/.local/bin/lca-web" 2>/dev/null || true
# ensure ~/.local/bin is on PATH
case ":${PATH}:" in
  *":${HOME}/.local/bin:"*) : ;;
  *) echo 'export PATH="$PATH:'$HOME'/\.local/bin"' >> "${HOME}/.profile" ;;
esac

# ---- 4. llama.cpp (optional) ------------------------------------------
cli="${LCA_DIR}/llama.cpp/build/bin/llama-cli"
if [ ! -x "${cli}" ]; then
  if command -v git >/dev/null 2>&1 && command -v cmake >/dev/null 2>&1 && command -v clang >/dev/null 2>&1; then
    echo "install.sh: building llama.cpp (needs ~1GB disk)…" >&2
    ( cd "${LCA_DIR}" && \
      git clone --depth 1 https://github.com/ggml-org/llama.cpp && \
      cd llama.cpp && \
      cmake -B build -DBUILD_SHARED=OFF && \
      cmake --build build --config Release -j4 ) \
      || echo "llama.cpp build failed — local models will not work" >&2
  else
    echo "install.sh: llama.cpp missing. pkg: git cmake clang libopenblas-static (Termux) or apt/brew equivalents."
  fi
fi

# ---- 5. sanity ---------------------------------------------------------
if "${HOME}/.local/bin/lca" --doctor >/dev/null 2>&1; then
  echo "✓ lca v5 installed to ${LCA_DIR} (tier: ${LCA_TIER})"
  echo "  Run: lca \"build me a python todo app\""
  echo "  Skills: lca --skill debug \"fix the crash\"   (reverse/ghidra/test/perf/build/fuzz/ctf/docker/ml)"
  echo "  Models: lca models   Memory: lca --memory   Web: sh bin/lca-web"
  echo "  GPU: auto (vulkan>metal>cuda>cpu)"
else
  echo "install.sh: sanity check failed — see errors above." >&2
  echo "  (If llama.cpp is missing, the doctor check will fail but the install is still usable for cloud models.)"
  exit 0
fi
