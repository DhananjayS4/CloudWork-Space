#!/usr/bin/env bash
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required" >&2
  exit 1
fi

npm ci || npm install

OUTDIR="$DIR/../infra/.dist"
mkdir -p "$OUTDIR"
ZIP="$OUTDIR/lambdas.zip"

rm -f "$ZIP"
zip -r "$ZIP" . -x "node_modules/.cache/*" -x "infra/*" -x "**/.DS_Store" -x "**/.git*" >/dev/null

echo "Created $ZIP"
