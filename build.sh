#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=common.sh
. ./common.sh

OUT=build/auto-reboot

mkdir -p build
swiftc -swift-version 6 -O -target "$(uname -m)-apple-macos$MACOS_MIN" -o "$OUT" Sources/*.swift
codesign --force --options runtime --sign - "$OUT"

echo "built $OUT"
