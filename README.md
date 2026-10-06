# embedded-dev

Reproducible Nix dev shells for embedded targets in C, C++ and Rust. VS Code's
language servers understand each cross toolchain, so you don't get false
"header not found" or "undeclared identifier" warnings.

| Shell | Targets | C / C++ | Rust |
| --- | --- | --- | --- |
| `pico` | RP2040 / RP2350 (Pico, Pico W, Pico 2) | arm-none-eabi GCC, pico-sdk (with submodules), picotool, OpenOCD | stable + Cortex-M targets, probe-rs |
| `esp32` | ESP32, -S2, -S3, -C2, -C3, -C6, -H2, -P4 | ESP-IDF v5.5 (Xtensa + RISC-V GCC, esp-clang, esptool) | Espressif's Xtensa rustc (`espup`'s build), espflash |
| `stm32` | STM32 and other Cortex-M parts | arm-none-eabi GCC, OpenOCD, stlink, probe-rs | stable + Cortex-M targets |
| `ti` | TI MSP430 | TI msp430-elf GCC + device headers/linker scripts, mspdebug | nightly + `rust-src` (`-Zbuild-std`) |
| `rpi` | Raspberry Pi 3, 4, 5, Zero, Zero W, Zero 2 W (Linux userspace) | static musl GCC for aarch64 and ARMv6 hard-float, `rpi-run` | stable + `aarch64-unknown-linux-musl`, `arm-unknown-linux-musleabihf` |
| `rpi-baremetal` | Raspberry Pi 3, 4, 5, Zero, Zero W, Zero 2 W (no OS) | aarch64-none-elf + arm-none-eabi GCC, GPU firmware, `rpi-boot` | nightly + `rust-src` (`-Zbuild-std`): `aarch64-unknown-none-softfloat`, `armv6-none-eabihf` |

Every shell also has `cmake`, `ninja`, `make`, `bear`, `picocom`, `python3`, a
host C compiler (for Cargo build scripts), a `clangd` and a `rust-analyzer` that
match the shell's toolchains.

> TI's Arm-based parts (MSPM0, TM4C/Tiva, MSP432) are plain Cortex-M, so use the
> `stm32` shell for them.

## Examples / templates

Every board has a blink example in each language, under `examples/blink-<board>-<lang>`:

| Board | Shell | C | C++ | Rust |
| --- | --- | --- | --- | --- |
| Raspberry Pi Pico | `pico` | [pico-sdk](examples/blink-pico-c) | [pico-sdk](examples/blink-pico-cpp) | [rp2040-hal](examples/blink-pico-rust) |
| ESP32 DevKit | `esp32` | [ESP-IDF](examples/blink-esp32-c) | [ESP-IDF](examples/blink-esp32-cpp) | [esp-hal](examples/blink-esp32-rust) |
| Nucleo-F401RE | `stm32` | [bare metal](examples/blink-stm32-c) | [bare metal](examples/blink-stm32-cpp) | [stm32f4xx-hal](examples/blink-stm32-rust) |
| MSP-EXP430G2ET LaunchPad | `ti` | [msp430.h, Timer_A ISR](examples/blink-msp430-c) | [msp430.h, Timer_A ISR](examples/blink-msp430-cpp) | [msp430g2553 PAC](examples/blink-msp430-rust) |
| Raspberry Pi 3 / 4 / 5 / Zero (all), Linux | `rpi` | [GPIO uAPI](examples/blink-rpi-c) | [GPIO uAPI](examples/blink-rpi-cpp) | [gpiocdev](examples/blink-rpi-rust) |
| Raspberry Pi 3 / 4 / 5 / Zero (all), bare metal | `rpi-baremetal` | [registers](examples/blink-rpi-baremetal-c) | [registers](examples/blink-rpi-baremetal-cpp) | [registers](examples/blink-rpi-baremetal-rust) |

Each example is also a flake template named `<board>-<lang>`:

```sh
mkdir my-project && cd my-project
nix flake init -t github:Cyber-Cornell/embedded-dev#pico-rust   # e.g. esp32-c, stm32-cpp, msp430-rust
direnv allow # Note that you need direnv installed
code .
```

You can also enter a shell manually (no direnv) with `nix develop github:Cyber-Cornell/embedded-dev#stm32`.

### Build and flash

```sh
# C / C++ (pico, stm32, msp430)
cmake --preset default && cmake --build build
cmake --build build --target flash          # stm32 / msp430 examples
#   pico: hold BOOTSEL, plug in, then  picotool load -x build/blink.uf2

# C / C++ (rpi): copies the binary to the Pi over SSH and runs it there
export RPI_HOST=user@raspberrypi.local       # the default host is raspberrypi.local
cmake --preset default && cmake --build build --target run              # 64-bit OS
cmake --preset armv6 && cmake --build build-armv6 --target run          # Zero / Zero W, 32-bit OS

# C / C++ (rpi-baremetal): writes the boot files to a mounted FAT32 SD card
export RPI_BOOT_DIR=/run/media/$USER/BOOT    # unset: build/boot, copy it yourself
cmake --preset default && cmake --build build --target flash            # kernel8.img: Pi 3, 4, 5, Zero 2 W
cmake --preset armv6 && cmake --build build-armv6 --target flash        # kernel.img: Zero / Zero W

# C / C++ (esp32)
idf.py set-target esp32 && idf.py build
idf.py -p /dev/ttyUSB0 flash monitor # Linux user needs to be added to group "dialout"

# Rust (all boards): the runner in .cargo/config.toml flashes the board
cargo build --release
cargo run --release
cargo run --release --target arm-unknown-linux-musleabihf   # rpi: Zero / Zero W, 32-bit OS
cargo run --release --target armv6-none-eabihf              # rpi-baremetal: Zero / Zero W
```

The Rust runners are `picotool` (Pico in BOOTSEL mode), `probe-rs` (Nucleo
ST-Link), `espflash` (ESP32), `mspdebug tilib` (LaunchPad eZ-FET) and
`rpi-run` (Raspberry Pi over SSH) and `rpi-boot` (Raspberry Pi SD card).

## One-time setup (NixOS)

```nix
# configuration.nix
programs.direnv.enable = true;          # auto-load shells on `cd` (includes nix-direnv)
services.udev.packages = with pkgs; [   # USB access to probes without sudo
  picotool openocd stlink probe-rs-tools
];
users.users.<you>.extraGroups = [ "dialout" ];  # serial ports
```

VS Code extensions (each example recommends the ones it needs):

- `mkhl.direnv`: loads the dev shell into VS Code. Required.
- `llvm-vs-code-extensions.vscode-clangd`: C/C++ IntelliSense.
- `rust-lang.rust-analyzer`: Rust IntelliSense.
- `ms-vscode.cmake-tools`: optional, for building C/C++ from the editor.
- `marus25.cortex-debug` / `probe-rs.probe-rs-debugger`: optional, for debugging.

The C/C++ examples disable Microsoft's C/C++ IntelliSense engine
(`ms-vscode.cpptools`) for the workspace, so it doesn't duplicate or contradict
clangd.

## How the IntelliSense setup works

False warnings in embedded projects usually come from the language server
analyzing your code as if it were a desktop program. It sees host glibc headers,
the host target and the wrong macros. This setup closes those gaps.

### C / C++ (clangd)

1. **`compile_commands.json`.** CMake (`CMAKE_EXPORT_COMPILE_COMMANDS` in
   `CMakePresets.json`) and `idf.py` write the exact flags, defines and include
   paths of every source file to `build/`. For Makefile projects, run
   `bear -- make`.
2. **`--query-driver=/nix/store/**/bin/*`.** clangd runs the real cross
   compiler named in `compile_commands.json`. From it, clangd learns the target
   triple (`arm-none-eabi`, `msp430-elf`, `xtensa-esp-elf`, ...) and the system
   headers (newlib, libstdc++, MSP430 device headers).
3. **An unwrapped clangd** ([nix/clangd.nix](nix/clangd.nix)). nixpkgs'
   `clang-tools` wrapper injects host glibc headers through `CPATH`, and those
   shadow the newlib headers.
4. **Per-target fixes**:
   - `esp32` uses Espressif's esp-clang `clangd`, which supports Xtensa.
     `.clangd` strips the GCC-only flags that ESP-IDF passes.
   - `ti` declares MSP430 GCC builtins such as `__delay_cycles` for clang only,
     inside `in430.h` ([nix/msp430-gcc.nix](nix/msp430-gcc.nix)).

Configure or build the project once so that `build/compile_commands.json`
exists. After that, clangd resolves pico-sdk, ESP-IDF, HAL and CMSIS headers.

### Rust (rust-analyzer)

1. **The target comes from `.cargo/config.toml`** (`[build] target = ...`).
   rust-analyzer analyzes the code for the MCU, not the host.
2. **The shell's own `rust-analyzer`** (`rust-analyzer.server.path`). It matches
   the shell's rustc, so the core library sources and proc-macro server line
   up. This matters most for the Xtensa and nightly toolchains.
3. **No test harness.** `test = false` on the binary, plus
   `rust-analyzer.check.allTargets: false`, stop the "can't find crate for
   `test`" errors that `no_std` firmware otherwise gets.

### Checking for false warnings

[`scripts/check-examples.sh`](scripts/check-examples.sh) builds every example
(or the ones you name) in its shell. It then runs the language server and clippy
from the command line, and fails on any diagnostic VS Code would show:

```sh
scripts/check-examples.sh                      # all examples
scripts/check-examples.sh examples/blink-pico-rust
```

If VS Code still shows stale errors, run **clangd: Restart language server** or
**rust-analyzer: Restart server**.

## Layout

```text
flake.nix                 dev shells, packages, templates
nix/clangd.nix            unwrapped clangd / clang-format / clang-tidy
nix/msp430-gcc.nix        TI MSP430 GCC + device support files
nix/esp-rust.nix          Espressif's Rust toolchain (Xtensa)
nix/rpi-run.nix           copy a binary to a Raspberry Pi over SSH and run it
nix/rpi-boot.nix          write a bare-metal kernel + GPU firmware + config.txt for an SD card
scripts/check-examples.sh build + language-server check of every example
examples/blink-<board>-<lang>/
  .envrc                  uses this repo's flake locally, the GitHub one otherwise
  .vscode/                language-server + direnv settings, extension recommendations
  CMakePresets.json       (C/C++) Ninja build in build/, compile_commands.json on
  .cargo/config.toml      (Rust) target, linker flags, flash runner
```

## Notes

- **Raspberry Pi (Linux).** The Pi 3, 4, 5 and Zero boards usually run
  Linux, and the `rpi` shell cross-compiles Linux programs for them. You
  don't flash them; `rpi-run` copies them over SSH. Pick the target from the
  Pi's OS, not the board. A 64-bit Raspberry Pi OS (Pi 3, 4, 5, Zero 2 W) uses
  `aarch64` (preset `default`). The Pi Zero and Zero W (ARMv6), or any Pi on a
  32-bit OS, use ARMv6 hard-float (preset `armv6`). Binaries are statically
  linked against musl. A dynamically linked Nix binary would look for its
  loader in `/nix/store` and need a newer glibc than Raspberry Pi OS has. The
  examples drive GPIO 17 (header pin 11) through the kernel's GPIO character
  device, which works on every model, including the Pi 5's RP1. Wire an LED and
  a resistor from pin 11 to ground. To use C libraries such as libgpiod, they
  must be cross-built statically for the same target.
- **Raspberry Pi (bare metal).** In the `rpi-baremetal` shell, your program is
  the only thing running; no OS needs to be installed. A Pi has no flash to
  program. Its GPU firmware loads `kernel8.img` (64-bit: Pi 3, 4, 5, Zero 2 W)
  or `kernel.img` (ARMv6: Pi Zero, Zero W) from a FAT32 SD card and jumps to
  it with the MMU and caches off. `rpi-boot` turns the ELF into that image. It
  also adds the firmware files (from nixpkgs' `raspberrypifw`) and a
  `config.txt`. Use a spare SD card: `rpi-boot` refuses to write to one that
  boots Linux (it has `cmdline.txt`) unless `RPI_BOOT_FORCE=1` is set. If you
  build both images onto one card, it boots on every supported Pi. The one
  `kernel8.img` tells the 64-bit boards apart by CPU type: Cortex-A53 for the
  Pi 3 and Zero 2 W, A72 for the Pi 4, A76 for the Pi 5. The Pi 5's header
  GPIO is on the RP1 chip behind PCIe; `config.txt` sets `pciex4_reset=0` so
  the bootloader leaves that link up. The 64-bit code avoids FP/SIMD registers
  (`-mgeneral-regs-only`, Rust's `-softfloat` target), which the firmware may
  leave trapped. Like the Linux examples, these blink an LED on GPIO 17 (pin
  11). You can try the Zero, Pi 3 and Pi 4 images in QEMU, for example
  `qemu-system-aarch64 -M raspi3b -kernel build/boot/kernel8.img`.

- **STM32 HAL.** The STM32 C/C++ examples are register-level, so they need only
  the toolchain. For HAL projects, generate a CMake project in STM32CubeMX
  (*Toolchain/IDE → CMake*) and build it in the `stm32` shell. CubeMX is unfree
  and large: `NIXPKGS_ALLOW_UNFREE=1 nix run --impure nixpkgs#stm32cubemx`.
- **Other chips in Rust.** Change the HAL's chip feature in `Cargo.toml`, plus
  `memory.x` and the target and runner in `.cargo/config.toml`. For RISC-V ESP32
  chips (C3, C6, ...), use e.g. `target = "riscv32imc-unknown-none-elf"` with the
  matching `esp-hal` feature.
- **Pico 2 (RP2350).** For C/C++, set `PICO_BOARD` to `pico2` in
  `CMakePresets.json`. For Rust, use `rp235x-hal` and `thumbv8m.main-none-eabihf`.
  Only the Arm cores are covered, not the RISC-V Hazard3 cores.
- **Version pins.** ESP-IDF comes from
  [nixpkgs-esp-dev](https://github.com/mirrexagon/nixpkgs-esp-dev), using that
  project's own nixpkgs pin, because ESP-IDF's Python tooling breaks on newer
  nixpkgs. The Rust toolchains come from
  [rust-overlay](https://github.com/oxalica/rust-overlay), and the MSP430
  nightly is pinned through `flake.lock`.
- **Updating.** `nix flake update` bumps everything. The MSP430 GCC and Xtensa
  Rust toolchains are pinned by URL and hash in `nix/`. After updating, run
  `scripts/check-examples.sh`.
