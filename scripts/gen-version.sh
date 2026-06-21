#!/usr/bin/env bash
# Generate version.json from the latest .dmg in releases/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RELEASES_DIR="$ROOT_DIR/releases"

# Find all .dmg files and extract version, pick the latest
LATEST=""
LATEST_FILE=""
for f in "$RELEASES_DIR"/*.dmg; do
  [ -f "$f" ] || continue
  fname="$(basename "$f")"
  # Extract version: awedot_X.Y.Z_universal.dmg -> X.Y.Z
  if [[ "$fname" =~ ^awedot_([0-9]+\.[0-9]+\.[0-9]+)_universal\.dmg$ ]]; then
    ver="${BASH_REMATCH[1]}"
    if [[ -z "$LATEST" || "$ver" > "$LATEST" ]]; then
      LATEST="$ver"
      LATEST_FILE="$fname"
    fi
  fi
done

if [ -z "$LATEST" ]; then
  echo "Error: No .dmg files found in $RELEASES_DIR" >&2
  exit 1
fi

cat > "$ROOT_DIR/version.json" <<EOF
{
  "version": "$LATEST",
  "filename": "$LATEST_FILE"
}
EOF

echo "Generated version.json: v$LATEST ($LATEST_FILE)"
