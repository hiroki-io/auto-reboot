#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
ROOT=$(cd .. && pwd)
OUT=build/tests

# shellcheck source=common.sh
. "$ROOT/common.sh"

# Sources/main.swift has top-level code. Absolute paths let #filePath find
# this tree from any directory.
sources=()
for file in "$ROOT"/Sources/*.swift; do
  [[ "$file" == */main.swift ]] || sources+=("$file")
done

while read -r name; do
  if ! grep -q "^$name()" "$ROOT/Tests/main.swift"; then
    echo "main.swift does not call $name" >&2
    exit 1
  fi
done < <(grep -h '^func test' "$ROOT"/Tests/*.swift | sed 's/^func \([A-Za-z0-9]*\).*/\1/')

mkdir -p build
swiftc -swift-version 6 \
  -target "$(uname -m)-apple-macos$MACOS_MIN" \
  -o "$OUT" \
  "$ROOT"/Tests/*.swift "${sources[@]}"

echo "built $OUT"
