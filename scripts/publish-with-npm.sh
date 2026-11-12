#!/usr/bin/env bash
# Packs with pnpm, which resolves the workspace: and catalog: protocols, then publishes the
# tarball with the npm CLI, which performs the OIDC exchange in CI. Skips private packages and
# versions already on the registry, so a rerun is safe.
# NPM_DIST_TAG sets the dist-tag (bootstrap publish); DRY_RUN=1 passes --dry-run to npm.
set -euo pipefail

root=$(pwd)
mkdir -p "$root/.packs"

for dir in packages/*/; do
  manifest="$root/${dir}package.json"
  name=$(node -p "require('$manifest').name")
  version=$(node -p "require('$manifest').version")

  if [ "$(node -p "Boolean(require('$manifest').private)")" = "true" ]; then
    echo "skip $name (private)"
    continue
  fi

  published=$(npm view "$name@$version" version 2>/dev/null || true)
  if [ "$published" = "$version" ]; then
    echo "skip $name@$version (already published)"
    continue
  fi

  tarball=$(cd "$dir" && pnpm pack --json --pack-destination "$root/.packs" | node -e 'let s="";process.stdin.on("data",c=>s+=c).on("end",()=>{const r=JSON.parse(s);console.log((Array.isArray(r)?r[0]:r).filename)})')
  echo "publish $name@$version from $tarball"
  npm publish "$tarball" --access public ${NPM_DIST_TAG:+--tag "$NPM_DIST_TAG"} ${DRY_RUN:+--dry-run}
done
