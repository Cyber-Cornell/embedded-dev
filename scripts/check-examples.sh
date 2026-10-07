#!/usr/bin/env bash
# Builds every example in its dev shell and runs the language server over it,
# failing on any build error, editor diagnostic (the "false warnings" VS Code
# would show), lint (clang-tidy, clippy, ruff, pyright) or unformatted file.
# Usage: scripts/check-examples.sh [example-or-system-dir...]
#   e.g. examples/pico/blink-c, or examples/pico for all Pico examples
set -uo pipefail
cd "$(dirname "$0")/../examples" || exit 1

shell_for() {
  case "$1" in
    *pico*) echo pico ;; *esp32*) echo esp32 ;; *stm32*) echo stm32 ;; *msp430*) echo ti ;; *rpi-baremetal*) echo rpi-baremetal ;; *rpi*) echo rpi ;;
    host/*) echo host ;;
  esac
}

check() {
  local dir=$1 shell
  shell=$(shell_for "$dir")
  # shellcheck disable=SC2016 # the script runs, and expands, inside the shell
  (cd "$dir" && nix develop "../../..#$shell" --quiet -c bash -c '
    set -o pipefail
    log=$(mktemp)
    case "$PWD" in
      *-rust)
        cargo build --release >"$log" 2>&1 || { cat "$log"; exit 1; }
        # Real diagnostics only; rust-analyzer logs internal noise on stderr.
        # Code behind a disabled cfg (e.g. the other chip) is only faded out.
        diags=$(rust-analyzer diagnostics . 2>/dev/null | grep -Ev "^(processing crate|diagnostic scan complete|$)" | grep -v "inactive_code")
        lints=$(cargo clippy --release 2>&1 | grep -E "^(warning|error)" | grep -v "future version of Rust")
        # Second chip of the Pico example (Pico 2, RP2350).
        if grep -q "^\[target.thumbv8m.main-none-eabihf\]" .cargo/config.toml; then
          lints+=$(cargo clippy --release --target thumbv8m.main-none-eabihf 2>&1 | grep -E "^(warning|error)")
        fi
        lints+=$(cargo fmt --check 2>&1 | head -20)
        ;;
      */host/*) # Python projects
        uv sync --locked >"$log" 2>&1 || { cat "$log"; exit 1; }
        diags=$(pyright 2>&1 | grep -E " - (error|warning)")
        lints=$(ruff check --quiet . 2>&1; ruff format --check --quiet . 2>&1)
        uv run --locked pytest -q >"$log" 2>&1 || { tail -30 "$log"; exit 1; }
        ;;
      */esp32/blink-c | */esp32/blink-cpp) # ESP-IDF projects
        { idf.py set-target esp32 && idf.py build; } >"$log" 2>&1 || { tail -30 "$log"; exit 1; }
        ;;
      *)
        { cmake --preset default && cmake --build build; } >"$log" 2>&1 || { tail -30 "$log"; exit 1; }
        # Second board of the Pico examples (Pico 2, RP2350).
        if grep -q "\"pico2\"" CMakePresets.json 2>/dev/null; then
          { cmake --preset pico2 && cmake --build build-pico2; } >"$log" 2>&1 || { tail -30 "$log"; exit 1; }
        fi
        ;;
    esac
    if [[ "$PWD" != *-rust && "$PWD" != */host/* ]]; then
      srcs=$(find src main -name "*.c" -o -name "*.cpp" -o -name "*.h" 2>/dev/null)
      # Errors clangd would show in the editor (clangd skips clang-tidy in
      # --check mode, so that runs below).
      diags=$(for f in $srcs; do
        clangd "--query-driver=/nix/store/**/bin/*" --compile-commands-dir=build --check="$f" 2>&1 |
          grep -E "^E\[.*\] \[.*\] Line"
      done)
      lints=$(clang-format --dry-run --Werror $srcs 2>&1 | head -20)
      # clang-tidy, with the .clang-tidy checks clangd shows in the editor.
      lints+=$(python3 ../../../scripts/clang-tidy-cross.py $srcs)
    fi
    [[ -z "$diags$lints" ]] || { echo "$diags$lints"; exit 1; }
  ') >/tmp/check-$$.log 2>&1
  local rc=$?
  if ((rc == 0)); then echo "ok    $dir"; else echo "FAIL  $dir"; grep -v "^warning: Git tree" /tmp/check-$$.log | sed "s/^/      /"; fi
  rm -f /tmp/check-$$.log
  return $rc
}

(($#)) || set -- */*/
status=0
for arg in "$@"; do
  arg=${arg%/}
  arg=${arg#examples/}
  # A system folder (e.g. examples/pico) means every example in it.
  if [[ $arg == */* ]]; then dirs=("$arg"); else dirs=("$arg"/*); fi
  for dir in "${dirs[@]}"; do
    check "$dir" || status=1
  done
done
exit $status
