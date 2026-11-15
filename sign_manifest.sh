#!/usr/bin/env bash
# sign_manifest.sh — maintainer script: sign the manifest for a release.
#
# Usage:  bash core/sign_manifest.sh <version>
#
# It computes the SHA256 of the core and registry, fills in the manifest,
# then computes the manifest's own signature (SHA256 of the body minus the
# "sig" field) and writes it back. Commit manifest.json + lca_core +
# registry.json together so the triplet stays consistent.

set -eu
cd "$(dirname "${0}")"
ver="${1:-0.0.0}"

core_sha="$(sha256sum lca_core | awk '{print $1}')"
reg_sha="$(sha256sum registry.json | awk '{print $1}')"

# build the manifest body (without sig)
body="$(cat <<EOF
{
  "version": "${ver}",
  "released": "$(date -u +%Y-%m-%d)",
  "core_sha256": "${core_sha}",
  "registry_sha256": "${reg_sha}",
  "core_url": "https://raw.githubusercontent.com/bigfguy8/lca/main/core/lca_core",
  "registry_url": "https://raw.githubusercontent.com/bigfguy8/lca/main/core/registry.json",
  "update": {"url": "https://raw.githubusercontent.com/bigfguy8/lca/main/core/manifest.json"},
  "sig": "PLACEHOLDER"
}
EOF
)"
# sig = sha256 of the body
sig="$(printf '%s' "${body}" | sha256sum | awk '{print $1}')"
# replace the PLACEHOLDER sig value with the real one
printf '%s\n' "${body}" | sed "s/\"sig\": \"PLACEHOLDER\"/\"sig\": \"${sig}\"/" > manifest.json

echo "signed manifest for v${ver}:"
echo "  core_sha256:     ${core_sha}"
echo "  registry_sha256: ${reg_sha}"
echo "  sig:             ${sig}"
echo "commit manifest.json + lca_core + registry.json together."
