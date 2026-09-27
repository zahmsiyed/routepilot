#!/bin/zsh
set -e
cd "${0:A:h}"
if command -v python3 >/dev/null 2>&1; then
  exec python3 -B launch.py "$@"
elif command -v uv >/dev/null 2>&1; then
  exec uv run --no-project --python 3.13 python -B launch.py "$@"
else
  print -u2 'Install Python 3.10+ or uv, then run this launcher again.'
  exit 1
fi
