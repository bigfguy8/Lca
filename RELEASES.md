# lca releases

Each release ships **three** files that must be committed together:
`core/lca_core` (obfuscated), `core/registry.json`, and `core/manifest.json`
(signed). `lca-update` fetches the manifest, verifies its signature, then pulls
the core + registry and checks their SHA256s before swapping.

## Changelog

### v5.0.0 (2026-11-15)
- **License sub-commands**: `lca --license` (show), `--license-verify`,
  `--license-new <email>` (maintainer issues a signed Pro license). Offline
  SHA256 verification; no server auth.
- **Per-project rules**: `.lca/rules.md` (CWD) and `~/.lca/rules.md` (global)
  are auto-appended to the master prompt.
- **Parallel tool calls** (`--parallel`, Pro): the model can emit up to 3
  independent tool lines per turn (read-only tools only). Falls back to
  single-tool mode without a Pro license.
- **New skills**: `fuzz`, `ctf`, `docker`, `ml` (in `skills/skills.conf`).
- **Ollama / LM-Studio auto-discovery**: `lca models list` probes
  `:11434` and `:1234`; live endpoints are auto-registered into
  `registry.json`.
- **Web UI** (public, localhost-only): `sh bin/lca-web` starts a
  python3/nc-backed HTTP server exposing the same closed core over
  `127.0.0.1`. Endpoints: `/`, `/status`, `/models`, `/run`.
- `core/lca_core` re-signed; `manifest.json` → v5.0.0; `lca_core.sha256`
  regenerated.

### v4.0.0 (2026-11-15)
- Initial public release of the cross-platform v4 tree.
- Skills, auto-repair, self-memory, sessions, `--learn`, `--security`,
  `--doctor`, `--unlimited`, GPU-first, model registry, Pro/Free tier,
  signed-manifest updater, cross-platform installers.

## Publishing a new version

1. Edit the core (the readable source), run `bash core/build_core.sh`.
2. Update `core/registry.json` if you added/removed model entries.
3. Sign: `bash core/sign_manifest.sh <version>`, and replace the
   `bigfguy8` placeholders in the manifest with your GitHub handle.
4. Commit all three files to `main` (or a release tag).

Free-tier users get at most one auto-update per 30 days; Pro-tier users update
on demand. The updater is `bin/lca-update`.
