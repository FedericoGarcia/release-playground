#!/usr/bin/env bash
# Publishes a minimal placeholder for a package that does not exist on npm yet, so a trusted
# publisher can be configured for it before CI publishes the first real release.
# The placeholder is the prerelease 0.0.0-bootstrap.0 under the `bootstrap` dist-tag; unpublish it
# (and npm's 0.0.0-stage) once CI has published the first release.
# Usage: bash scripts/bootstrap-placeholder.sh packages/<name>
set -euo pipefail

manifest="$(cd "$1" && pwd)/package.json"
name=$(node -p "require('$manifest').name")

if npm view "$name" name >/dev/null 2>&1; then
  echo "$name already exists on npm; no placeholder needed" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

node -e '
  const fs = require("fs");
  const [source, out] = process.argv.slice(1);
  const pkg = require(source);
  const placeholder = {
    name: pkg.name,
    version: "0.0.0-bootstrap.0",
    description: "Placeholder published to configure npm trusted publishing. Not meant to be installed.",
    license: pkg.license,
    repository: pkg.repository,
  };
  fs.writeFileSync(`${out}/package.json`, JSON.stringify(placeholder, null, 2) + "\n");
  fs.writeFileSync(`${out}/README.md`, `# ${pkg.name}\n\nPlaceholder published to configure npm trusted publishing. Install the latest release instead.\n`);
' "$manifest" "$work"

echo "publish $name@0.0.0-bootstrap.0 (placeholder, dist-tag bootstrap)"
npm publish "$work" --tag bootstrap --access public
