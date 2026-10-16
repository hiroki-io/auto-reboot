#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# With no arguments, a missing linter is skipped. CI names each linter, so a
# missing one fails the job.
if [ $# -eq 0 ]; then
  set -- shell swift
  optional=1
else
  optional=0
fi

status=0

check_installed() {
  command -v "$1" >/dev/null && return 0
  if [ "$optional" -eq 1 ]; then
    echo "lint: $1 not found, skipped" >&2
  else
    echo "lint: $1 not found" >&2
    status=1
  fi
  return 1
}

for linter in "$@"; do
  case "$linter" in
    shell)
      if check_installed shellcheck; then
        git ls-files -z '*.sh' | xargs -0 -r shellcheck || status=1
      fi
      ;;
    swift)
      if check_installed swift; then
        git ls-files -z '*.swift' | xargs -0 -r swift format lint --strict || status=1
      fi
      ;;
    *)
      echo "usage: ./lint.sh [shell|swift]..." >&2
      exit 2
      ;;
  esac
done

exit "$status"
