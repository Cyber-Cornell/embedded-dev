#!/usr/bin/env bash
# Builds every example in its dev shell and runs the language server over it,
# failing on any build error or editor diagnostic (the "false warnings" VS Code
# would show). Usage: scripts/check-examples.sh [example-dir...]
set -uo pipefail
cd "$(dirname "$0")/../examples"

shell_for() {
  case "$1" in
    *pico*) echo pico ;; *esp32*) echo esp32 ;; *stm32*) echo stm32 ;; *msp430*) echo ti ;; *rpi-baremetal*) echo rpi-baremetal ;; *rpi*) echo rpi ;;
  esac
}

check() {
  local dir=$1 shell
  shell=$(shell_for "$dir")
  (cd "$dir" && nix develop "../..#$shell" --quiet -c bash -c '
    set -o pipefail
    log=$(mktemp)
    case "$PWD" in
      *-rust)
        cargo build --release >"$log" 2>&1 || { cat "$log"; exit 1; }
        # Real diagnostics only; rust-analyzer logs internal noise on stderr.
        diags=$(rust-analyzer diagnostics . 2>/dev/null | grep -Ev "^(processing crate|diagnostic scan complete|$)")
        lints=$(cargo clippy --release 2>&1 | grep -E "^(warning|error)" | grep -v "future version of Rust")
        ;;
      *-esp32-*)
        { idf.py set-target esp32 && idf.py build; } >"$log" 2>&1 || { tail -30 "$log"; exit 1; }
        ;;
      *)
        { cmake --preset default && cmake --build build; } >"$log" 2>&1 || { tail -30 "$log"; exit 1; }
        ;;
    esac
    if [[ "$PWD" != *-rust ]]; then
      diags=$(for f in $(find src main -name "*.c" -o -name "*.cpp" 2>/dev/null); do
        clangd "--query-driver=/nix/store/**/bin/*" --compile-commands-dir=build --check="$f" 2>&1 |
          grep -E "^E\[.*\] \[.*\] Line"
      done)
      lints=""
    fi
    [[ -z "$diags$lints" ]] || { echo "$diags$lints"; exit 1; }
  ') >/tmp/check-$$.log 2>&1
  local rc=$?
  if ((rc == 0)); then echo "ok    $dir"; else echo "FAIL  $dir"; grep -v "^warning: Git tree" /tmp/check-$$.log | sed "s/^/      /"; fi
  rm -f /tmp/check-$$.log
  return $rc
}

(($#)) || set -- blink-*/
status=0
for dir in "$@"; do
  dir=${dir%/}
  check "${dir#examples/}" || status=1
done
exit $status
