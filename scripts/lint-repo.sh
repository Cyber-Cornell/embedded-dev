#!/usr/bin/env bash
# Lints and format-checks this repo's own files: Nix, shell scripts, Python
# helpers and Markdown. Run it in the default shell:
#   nix develop -c scripts/lint-repo.sh
# (The examples have their own checks: scripts/check-examples.sh.)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

status=0
run() {
  echo "== $*"
  "$@" || status=1
}
run nixfmt --check flake.nix nix/*.nix
run statix check .
run shellcheck scripts/*.sh
run ruff check scripts
run ruff format --check scripts
run markdownlint-cli2 README.md
exit $status
