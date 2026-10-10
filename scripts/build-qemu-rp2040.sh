#!/usr/bin/env bash
# Build a QEMU with the RP2040 "raspi-pico" machine. The machine comes from an
# RFC patch series that is not upstream yet, so stock QEMU does not have it.
# Run this inside `nix develop nixpkgs#qemu` to get QEMU's build dependencies.
set -euo pipefail

dest=${QEMU_RP2040_DIR:-$HOME/.cache/embedded-dev/qemu-rp2040}
tag=tags/patchew/20260705220320.90395-1-gilles.grimaud@univ-lille.fr # Built and tested with QEMU commit 9e316daf248f2cc05a3255de3cf4cde067983e9f

mkdir -p "${dest}"
[ -d "${dest}/src" ] || git clone https://gitlab.com/qemu-project/qemu.git "${dest}/src"
cd "${dest}/src"
git fetch https://github.com/patchew-project/qemu "${tag}"
git checkout -B pico FETCH_HEAD
mkdir -p build
cd build
../configure --target-list=arm-softmmu
ninja

echo "Done. Run:  export QEMU_RP2040=${dest}/src/build/qemu-system-arm"

chmod +x scripts/build-qemu-rp2040.sh