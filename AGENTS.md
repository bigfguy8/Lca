# AGENTS.md — LCA project rules

## Never violate
- Manifest sig = sha256(body with "sig": "PLACEHOLDER"). If you change
  sign_manifest.sh or lca-update, both sides must stay byte-identical
  in what they hash.
- URLs must stay bigfguy8/Lca (capital L). raw.githubusercontent.com
  is case-sensitive and does not redirect.
- bin/lca.sh must exec bash (not sh). Termux has no /bin/bash.
- core/lca_core, core/lca_core.sha256, core/manifest.json are committed
  TOGETHER in one commit. Never one without the others.
- Never edit core/registry.json without re-signing the manifest.
- Never batch-write files. One write per file.
- Never force-move a pushed git tag. Use vX.Y.Z-rN.

## Release ritual
1. bash -n <changed script>
2. If core/lca_core changed:
     sha256sum core/lca_core | awk '{print $1"  lca_core"}' > core/lca_core.sha256
     bash core/sign_manifest.sh <version>
3. Verify sig self-consistency:
     body=$(sed -E 's/"sig": *"[a-f0-9]{64}"/"sig": "PLACEHOLDER"/' core/manifest.json)
     exp=$(grep -oE '"sig": *"[a-f0-9]{64}"' core/manifest.json | grep -oE '[a-f0-9]{64}' | head -1)
     act=$(printf '%s' "$body" | sha256sum | awk '{print $1}')
     [ "$exp" = "$act" ] || exit 1
4. git add the three signed files; git commit; git tag -a; push --follow-tags
5. Verify live: curl -sS ".../manifest.json?t=$(date +%s)" | grep '"sig"'

## Verification commands
- bash bin/lca.sh --help
- bash bin/lca.sh --doctor
- bash bin/lca.sh models
- LCA_CORE_HOME="$HOME/lca" bash bin/lca-update

## Forbidden
- Editing core/ when the task is a docs or launcher task.
- Touching .lca_last_update (free-tier rate-limit stamp).
