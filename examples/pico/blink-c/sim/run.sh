#!/usr/bin/env bash
# Run the blink firmware in QEMU's raspi-pico machine and check that the LED
# toggles. Exits 0 on success. QEMU_RP2040 overrides the QEMU binary.
set -euo pipefail

elf=${1:?usage: run.sh path/to/blink.elf}
qemu=${QEMU_RP2040:-qemu-system-arm}

log=$(mktemp)
trap 'rm -f "${log}"' EXIT

# The firmware blinks forever, so let timeout stop it (exit 124 is expected).
# The UART goes to a file and stdin is /dev/null, so QEMU never touches the
# terminal.
timeout 5 "${qemu}" -machine raspi-pico -kernel "${elf}" \
  -display none -monitor none -serial "file:${log}" \
  -d unimp,guest_errors < /dev/null || true

cat "${log}"

grep -q 'LED on' "${log}" || { echo "FAIL: LED never turned on"; exit 1; }
grep -q 'LED off' "${log}" || { echo "FAIL: LED never turned off"; exit 1; }
echo "PASS: LED blinks"