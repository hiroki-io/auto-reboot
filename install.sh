#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# shellcheck source=common.sh
. ./common.sh

# Build before anything stops, so that a failed build does not change the
# running install.
./build.sh >/dev/null

if launchctl print "system/$LABEL" >/dev/null 2>&1; then
  sudo launchctl bootout "system/$LABEL"
fi
# install -d also changes the mode and owner of a directory that exists.
[ -d "$(dirname "$BINARY")" ] || sudo install -d -m 755 -o root -g wheel "$(dirname "$BINARY")"
sudo install -m 755 -o root -g wheel build/auto-reboot "$BINARY"
sudo install -m 644 -o root -g wheel "$LABEL.plist" "$PLIST"
sudo launchctl bootstrap system "$PLIST"
sudo mkdir -p "$(dirname "$COMMAND")"
sudo ln -sf "$BINARY" "$COMMAND"

echo "Done. Run 'auto-reboot status' to check the settings."
