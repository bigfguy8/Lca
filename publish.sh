#!/bin/sh
# publish.sh — one-command release: build → sign → commit → tag → push
# Usage:  sh publish.sh [version]   (default: auto-increment patch)
#
# What it does:
#   1. Prompts for version (default: auto-patch from CHANGELOG/RELEASES.md)
#   2. Builds the closed core (bash core/build_core.sh)
#   3. Signs the manifest (bash core/sign_manifest.sh <ver>)
#   4. Stages everything, commits, tags, and pushes
#
# Must be run from the lca/ project root.
# Requires: bash, git, sha256sum (all present in Termux).

set -eu

cd "$(dirname "${0}")"

# ---- 0. sanity checks ----------------------------------------------------
if [ ! -d ".git" ]; then echo "publish.sh: not in a git repo (run from ~/lca)" >&2; exit 1; fi
if [ ! -f "core/build_core.sh" ]; then echo "publish.sh: core/build_core.sh not found" >&2; exit 1; fi
if ! command -v git >/dev/null 2>&1; then echo "publish.sh: git not found" >&2; exit 1; fi
if ! command -v bash >/dev/null 2>&1; then echo "publish.sh: bash not found" >&2; exit 1; fi

# ---- 1. version -----------------------------------------------------------
if [ -n "${1:-}" ]; then
  VER="${1}"
elif [ -f "RELEASES.md" ]; then
  # auto-increment patch: read last version from RELEASES.md, bump patch
  last="$(grep -m1 '^## \[v' RELEASES.md 2>/dev/null | grep -oE '[0-9]+\.[0-9]+.[0-9]+' || echo "5.0.1")"
  major="$(printf '%s' "${last}" | cut -d. -f1)"
  minor="$(printf '%s' "${last}" | cut -d. -f2)"
  patch="$(printf '%s' "${last}" | cut -d. -f3)"
  patch="$(( patch + 1 ))"
  VER="${major}.${minor}.${patch}"
  echo "auto-bumped version: ${last} → ${VER}"
else
  echo "Usage: sh publish.sh [version]   or: sh publish.sh 5.1.0"
  echo "Current RELEASES.md not found; pass version explicitly."
  exit 1
fi

# strip leading 'v' if given
VER="${VER#v}"
echo ""
echo "=== publishing lca v${VER} ==="
echo ""

# ---- 2. dirty-check --------------------------------------------------------
# Show uncommitted changes; if there are staged files, skip the prompt.
# If there are unstaged changes, require confirmation unless -f is passed.
dirty=0
if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  dirty=1
  if [ "${FORCE:-0}" -ne 1 ]; then
    echo "uncommitted changes detected:"
    git status --short | head -20
    echo ""
    printf 'publish anyway? (will stage all changes) [y/N]: '
    read -r confirm
    case "${confirm}" in
      y|Y|yeah|yes) dirty=0 ;;
      *) echo "aborted."; exit 0 ;;
    esac
  fi
fi

# ---- 3. build the closed core ---------------------------------------------
echo "[1/5] building closed core…"
bash core/build_core.sh
echo ""

# ---- 4. sign the manifest --------------------------------------------------
echo "[2/5] signing manifest for v${VER}…"
bash core/sign_manifest.sh "${VER}"
echo ""

# ---- 5. stage + commit ----------------------------------------------------
echo "[3/5] staging + committing…"
git add -A

# include a meaningful commit message
msg="${1:-lca v${VER}: $(date -u +%Y-%m-%d)}"
git commit -m "${msg}"
echo "committed: $(git rev-parse --short HEAD)"

# ---- 6. tag ---------------------------------------------------------------
echo "[4/5] tagging v${VER}…"
# delete local + remote tag if it already exists
git tag -d "v${VER}" 2>/dev/null || true
git push origin ":refs/tags/v${VER}" 2>/dev/null || true
git tag -a "v${VER}" -m "lca v${VER}"
echo "tagged: v${VER}"

# ---- 7. push --------------------------------------------------------------
echo "[5/5] pushing to GitHub…"
git push
git push --tags
echo ""

# ---- summary --------------------------------------------------------------
echo "=== published: lca v${VER} ==="
echo "  commit : $(git rev-parse --short HEAD)"
echo "  tag    : v${VER}"
echo "  remote : $(git remote get-url origin 2>/dev/null | sed 's|git@github.com:||;s|https://github.com/||')"
echo ""
echo "Smoke-test the one-liner:"
echo "  curl -fsSL https://raw.githubusercontent.com/bigfguy8/Lca/main/install.sh | sh"
