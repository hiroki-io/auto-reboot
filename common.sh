# shellcheck shell=bash
# Other scripts use these values. shellcheck cannot see that from this file.
# shellcheck disable=SC2034
LABEL=io.hiroki.auto-reboot
BINARY=/Library/PrivilegedHelperTools/$LABEL
COMMAND=/usr/local/bin/auto-reboot
PLIST=/Library/LaunchDaemons/$LABEL.plist
MACOS_MIN=13.0
