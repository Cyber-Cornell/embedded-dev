# embedded-dev

Reproducible Nix dev shells for embedded targets in C, C++ and Rust, plus a
Python shell for host-side tools. VS Code's language servers understand each
cross toolchain, so you don't get false "header not found" or "undeclared
identifier" warnings, and every example formats on save and shows lint
warnings.

| Shell | Targets | C / C++ | Rust |
| --- | --- | --- | --- |
| `pico` | RP2040 / RP2350 (Pico, Pico W, Pico 2) | arm-none-eabi GCC, pico-sdk (with submodules), picotool, OpenOCD | stable + Cortex-M targets, probe-rs |
| `esp32` | ESP32, -S2, -S3, -C2, -C3, -C6, -H2, -P4 | ESP-IDF v5.5 (Xtensa + RISC-V GCC, esp-clang, esptool) | Espressif's Xtensa rustc (`espup`'s build), espflash |
| `stm32` | STM32 and other Cortex-M parts | arm-none-eabi GCC, OpenOCD, stlink, probe-rs | stable + Cortex-M targets |
| `mspm0` | TI MSPM0 (Cortex-M0+) | arm-none-eabi GCC, TI MSPM0 SDK (DriverLib, device headers, startup files, linker scripts), probe-rs | stable + Cortex-M targets |
| `ti` | TI MSP430 | TI msp430-elf GCC + device headers/linker scripts, mspdebug | nightly + `rust-src` (`-Zbuild-std`) |
| `rpi` | Raspberry Pi 3, 4, 5, Zero, Zero W, Zero 2 W (Linux userspace) | static musl GCC for aarch64 and ARMv6 hard-float, `rpi-run` | stable + `aarch64-unknown-linux-musl`, `arm-unknown-linux-musleabihf` |
| `rpi-baremetal` | Raspberry Pi 3, 4, 5, Zero, Zero W, Zero 2 W (no OS) | aarch64-none-elf + arm-none-eabi GCC, GPU firmware, `rpi-boot` | nightly + `rust-src` (`-Zbuild-std`): `aarch64-unknown-none-softfloat`, `armv6-none-eabihf` |
| `host` | Your computer: tools that talk to the boards | — | — (Python 3, uv, Ruff, Pyright) |

Every shell also has `cmake`, `ninja`, `make`, `bear`, `picocom`, `python3`,
[`mcu`](#host-side-python-and-the-mcu-cli) (a serial-port CLI), a host C
compiler (for Cargo build scripts), and a `clangd`, `clang-format`,
`clang-tidy`, `rustfmt`, `clippy` and `rust-analyzer` that match the shell's
toolchains.

> TI's other Arm-based parts (TM4C/Tiva, MSP432) are plain Cortex-M, so use the
> `stm32` shell for them. MSPM0 has its own shell because it carries TI's SDK.

## Requirements

Linux on x86-64. Everything else that builds or flashes comes from the dev
shells; you install only the pieces below once per machine.

1. **Nix with flakes.**
   - NixOS: add `nix.settings.experimental-features = [ "nix-command" "flakes" ];`
     to `configuration.nix`.
   - Other distributions: install Nix, e.g. with
     `sh <(curl -L https://nixos.org/nix/install) --daemon`, then enable flakes
     with `experimental-features = nix-command flakes` in
     `~/.config/nix/nix.conf`.
2. **direnv with nix-direnv**, which loads a project's shell when you `cd`
   into it (and into VS Code, through the direnv extension).
   - NixOS: `programs.direnv.enable = true;` (includes nix-direnv).
   - Other distributions: install direnv from the package manager, add its
     hook to your shell (`eval "$(direnv hook bash)"` in `~/.bashrc`, or the
     `zsh` equivalent), then `nix profile install nixpkgs#nix-direnv` and put
     `source $HOME/.nix-profile/share/nix-direnv/direnvrc` in
     `~/.config/direnv/direnvrc`.
3. **Serial ports: be in the `dialout` group.** Board consoles, the ESP32's
   USB-UART and `mcu`/`picocom`/`idf.py monitor` all open `/dev/ttyUSB*` or
   `/dev/ttyACM*`, which belong to `dialout` (`uucp` on Arch).
   - NixOS: `users.users.<you>.extraGroups = [ "dialout" ];`
   - Other distributions: `sudo usermod -aG dialout $USER`.

   Log out and back in afterwards; `groups` should list `dialout`.
4. **USB probes: udev rules,** so `picotool`, `openocd`, `st-flash`,
   `probe-rs` and `mspdebug` work without `sudo`. The packages ship the rules
   (OpenOCD's also cover the XDS110 on MSPM0 LaunchPads), except for TI's
   eZ-FET, whose rule is in [`udev/`](udev/70-ti-msp430.rules).
   - NixOS:

     ```nix
     services.udev.packages = with pkgs; [ picotool openocd stlink probe-rs-tools ];
     services.udev.extraRules = builtins.readFile ./70-ti-msp430.rules; # copy of udev/70-ti-msp430.rules
     ```

   - Other distributions:

     ```sh
     for p in picotool openocd stlink probe-rs-tools; do
       sudo cp "$(nix build --no-link --print-out-paths nixpkgs#$p)"/{etc,lib}/udev/rules.d/*.rules /etc/udev/rules.d/ 2>/dev/null
     done
     sudo cp udev/70-ti-msp430.rules /etc/udev/rules.d/
     sudo udevadm control --reload && sudo udevadm trigger
     ```

5. **VS Code** with the extensions the example recommends when you open it:
   - `mkhl.direnv`: loads the dev shell into VS Code. Required.
   - `llvm-vs-code-extensions.vscode-clangd`: C/C++ IntelliSense, formatting
     and clang-tidy.
   - `rust-lang.rust-analyzer`: Rust IntelliSense, rustfmt and clippy.
   - `ms-python.python`, `ms-python.vscode-pylance`, `charliermarsh.ruff`:
     Python (the `host-python` example).
   - `ms-vscode.cmake-tools`: optional, for building C/C++ from the editor.
   - `marus25.cortex-debug` / `probe-rs.probe-rs-debugger`: optional, for
     debugging.

   The C/C++ examples turn off Microsoft's C/C++ IntelliSense engine
   (`ms-vscode.cpptools`) for the workspace, so it doesn't duplicate or
   contradict clangd.

The ESP-IDF toolchains are large: the `esp32` shell downloads a few GB the
first time.

## Examples / templates

Examples are grouped by system, one folder per board family
(`examples/<system>/`), and every board has a blink example in each language
(`examples/<system>/blink-<lang>`):

| Board | Shell | C | C++ | Rust |
| --- | --- | --- | --- | --- |
| Raspberry Pi Pico / Pico 2 | `pico` | [pico-sdk](examples/pico/blink-c) | [pico-sdk](examples/pico/blink-cpp) | [rp2040-hal](examples/pico/blink-rust) (Pico) |
| ESP32 DevKit | `esp32` | [ESP-IDF](examples/esp32/blink-c) | [ESP-IDF](examples/esp32/blink-cpp) | [esp-hal](examples/esp32/blink-rust) |
| Nucleo-F401RE | `stm32` | [bare metal](examples/stm32/blink-c) | [bare metal](examples/stm32/blink-cpp) | [stm32f4xx-hal](examples/stm32/blink-rust) |
| LP-MSPM0L2228 LaunchPad | `mspm0` | [DriverLib](examples/mspm0/blink-c) | [DriverLib](examples/mspm0/blink-cpp) | [embassy-mspm0](examples/mspm0/blink-rust) |
| MSP-EXP430G2ET LaunchPad | `ti` | [msp430.h, Timer_A ISR](examples/msp430/blink-c) | [msp430.h, Timer_A ISR](examples/msp430/blink-cpp) | [msp430g2553 PAC](examples/msp430/blink-rust) |
| Raspberry Pi 3 / 4 / 5 / Zero (all), Linux | `rpi` | [GPIO uAPI](examples/rpi/blink-c) | [GPIO uAPI](examples/rpi/blink-cpp) | [gpiocdev](examples/rpi/blink-rust) |
| Raspberry Pi 3 / 4 / 5 / Zero (all), bare metal | `rpi-baremetal` | [registers](examples/rpi-baremetal/blink-c) | [registers](examples/rpi-baremetal/blink-cpp) | [registers](examples/rpi-baremetal/blink-rust) |

### Register-level examples and linker scripts

For bootloader work, every bare-metal board also has a register-level blink:
no HAL, PAC or SDK API, just volatile reads and writes of the peripheral
registers. Each
one carries the board's linker script in the project directory. Where the
toolchain or SDK already supplies a default script, the project's copy is
referenced from a commented-out line, so the build is unchanged until you
uncomment it. Where nothing supplies a default, the script is required and its
line is active.

| Board | C | C++ | Rust | Linker script | Default from | Switch |
| --- | --- | --- | --- | --- | --- | --- |
| Raspberry Pi Pico / Pico 2 | [regs](examples/pico/blink-regs-c) | [regs](examples/pico/blink-regs-cpp) | [regs](examples/pico/blink-regs-rust) | `rp2040.ld`, `rp2350.ld` | pico-sdk / cortex-m-rt | commented out |
| ESP32 DevKit | [regs](examples/esp32/blink-regs-c) | [regs](examples/esp32/blink-regs-cpp) | [regs](examples/esp32/blink-regs-rust) | `esp32.ld` | none | active |
| Nucleo-F401RE | [bare metal](examples/stm32/blink-c) | [bare metal](examples/stm32/blink-cpp) | [regs](examples/stm32/blink-regs-rust) | `stm32f401re.ld` | none (C/C++) / cortex-m-rt (Rust) | active / commented out |
| LP-MSPM0L2228 | [regs](examples/mspm0/blink-regs-c) | [regs](examples/mspm0/blink-regs-cpp) | [regs](examples/mspm0/blink-regs-rust) | `mspm0l2228.ld` | none (C/C++) / cortex-m-rt (Rust) | active / commented out |
| MSP-EXP430G2ET | [msp430.h](examples/msp430/blink-c) | [msp430.h](examples/msp430/blink-cpp) | [regs](examples/msp430/blink-regs-rust) | `msp430g2553.ld` / `msp430g2553_rt.ld` | TI's `-mmcu` script / msp430-rt | commented out |
| Raspberry Pi (bare metal) | [registers](examples/rpi-baremetal/blink-c) | [registers](examples/rpi-baremetal/blink-cpp) | [registers](examples/rpi-baremetal/blink-rust) | `link64.ld`, `link32.ld` | none | active |

- **Switching.** C/C++: uncomment the line in `CMakeLists.txt`
  (`pico_set_linker_script` for the Pico, `-T` for the MSP430). Rust: in
  `.cargo/config.toml`, swap the commented `-T` line with the active
  `-Tlink.x` one.
- **Copied scripts keep their license.** The Pico C/C++ `rp2040.ld` and
  `rp2350.ld` are pico-sdk 2.3.1's default scripts flattened into one file
  each (BSD-3-Clause). The Rust `rp2040.ld`, `rp2350.ld`, `stm32f401re.ld`,
  `mspm0l2228.ld` and `msp430g2553_rt.ld` are
  cortex-m-rt's / msp430-rt's `link.x` with the project's `memory.x` pasted in
  (MIT). The MSP430 C/C++ `msp430g2553.ld` is TI's script, unmodified
  (BSD-3-Clause). Each file's header says what was changed. Linked with the
  copy instead of the default, every one of them produces a byte-identical
  image. The STM32 and MSPM0 C/C++ scripts were written for these examples.
- **Pico and Pico 2.** One project builds for either chip: CMake preset
  `default` (Pico, RP2040) or `pico2` (Pico 2, RP2350), and in Rust the
  `thumbv6m-none-eabi` (default) or `thumbv8m.main-none-eabihf` target. The
  register addresses, reset bits and linker script follow the chip. In C/C++
  the SDK still provides the boot path (RP2040 boot2, the RP2350 IMAGE_DEF
  block), crt0 and clock setup (`pico_runtime`), while `main` touches only
  registers. Rust uses cortex-m-rt plus `rp2040-boot2` or its own IMAGE_DEF
  block. Only the RP2350's Arm cores are covered, and the Pico W / Pico 2 W
  LEDs sit behind the wireless chip, so these examples don't blink them.
- **LP-MSPM0L2228.** The examples blink the blue channel of the RGB LED
  (LED4, PA23); jumper J4 must be on. Red is PB10 (J5) and green PB9 (J6).
  The register-level examples don't use the MSPM0 SDK at all; their startup
  code and linker script are in the project. Don't link anything into the
  NONMAIN flash at `0x41C00000` (the boot configuration and ROM bootloader
  settings): a bad write there can lock the chip for good. None of the
  linker scripts here describe it.
- **ESP32.** No ESP-IDF at all: the mask ROM loads the image from flash offset
  `0x1000`, where ESP-IDF's second-stage bootloader normally sits, straight
  into IRAM/DRAM. That is exactly where a custom bootloader runs. Flashing it
  replaces the board's second-stage bootloader, so ESP-IDF apps won't boot
  until you flash an ESP-IDF project again.

Each example is also a flake template named `<board>-<lang>`:

```sh
mkdir my-project && cd my-project
nix flake init -t github:Cyber-Cornell/embedded-dev#pico-rust   # e.g. esp32-c, pico-regs-c, host-python
direnv allow
code .
```

You can also enter a shell by hand (no direnv), e.g.
`nix develop github:Cyber-Cornell/embedded-dev#stm32`.

### Build and flash

```sh
# C / C++ (pico, stm32, mspm0, msp430)
cmake --preset default && cmake --build build
cmake --build build --target flash          # stm32 / mspm0 / msp430 examples
#   pico: hold BOOTSEL, plug in, then  picotool load -x build/blink.uf2
cmake --preset pico2 && cmake --build build-pico2   # Pico 2: build-pico2/blink.uf2

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

# C / C++ (esp32-regs): no ESP-IDF; writes build/blink.bin to flash offset 0x1000
cmake --preset default && cmake --build build --target flash   # ESPPORT=/dev/ttyUSB0 to pick a port

# Rust (all boards): the runner in .cargo/config.toml flashes the board
cargo build --release
cargo run --release
cargo run --release --target arm-unknown-linux-musleabihf   # rpi: Zero / Zero W, 32-bit OS
cargo run --release --target armv6-none-eabihf              # rpi-baremetal: Zero / Zero W
cargo run --release --target thumbv8m.main-none-eabihf      # pico-regs: Pico 2
```

The Rust runners are `picotool` (Pico in BOOTSEL mode), `probe-rs` (Nucleo
ST-Link, MSPM0 LaunchPad XDS110), `espflash` (ESP32; `esptool.py` for `esp32-regs-rust`),
`mspdebug tilib` (LaunchPad eZ-FET), `rpi-run` (Raspberry Pi over SSH) and
`rpi-boot` (Raspberry Pi SD card).

## Host-side Python and the `mcu` CLI

The `host` shell is for Python that runs on your computer: tools that talk to
a board, test scripts, image signing and other crypto. It has Python 3, uv,
Ruff and Pyright. [`examples/host/python`](examples/host/python) is a uv
project to start from (template `host-python`): its `.envrc` loads the shell
and runs `uv sync`, which creates `.venv` from `uv.lock` with pyserial,
cryptography and pytest.

```sh
uv add requests          # add a dependency (updates pyproject.toml and uv.lock)
uv run pytest            # tests
ruff check --fix . && ruff format . && pyright
```

uv uses the shell's Python (`UV_PYTHON`) and never downloads its own, because
those builds don't run on NixOS.

The project is also `mcu`, a small CLI for a board on a serial port. Every dev
shell has it:

```sh
mcu ports                          # list USB serial ports and what's on them
mcu monitor                        # terminal; -b 9600, -t timestamps, --hex, --log file
mcu send "status" --expect "OK"    # send a line, print the reply, check it
mcu send --hex "de ad be ef"       # raw bytes
mcu bootsel                        # reboot a pico-sdk Pico (USB stdio) into BOOTSEL
```

With a single board plugged in, `mcu` finds its port; otherwise pass
`-p /dev/ttyACM0` or set `MCU_PORT`. `-p loop://` is an echo port for trying
it out without hardware.

## Formatting and linting

Saving a file in VS Code formats it, and lint warnings show up as you type:

| Language | Format on save | Lint | Config |
| --- | --- | --- | --- |
| C / C++ | clang-format, through clangd | clang-tidy, through clangd | `.clang-format` (Google style), `.clang-tidy` |
| Rust | rustfmt, through rust-analyzer | clippy, on save | `rustfmt.toml` / `clippy.toml` if you add them |
| Python | Ruff | Ruff, Pylance (type checks, like `pyright`) | `pyproject.toml` |
| Nix, Markdown, shell (this repo) | nixfmt, markdownlint | nil, statix, markdownlint, ShellCheck | `.markdownlint.jsonc` |

The tools come from the dev shell, so everyone gets the same versions. The
`.clang-tidy` files turn off the checks that fight register-level code
(integer-to-pointer casts, fixed addresses, linker symbols, magic numbers);
edit them to taste.

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

### Checking the examples

[`scripts/check-examples.sh`](scripts/check-examples.sh) builds every example
(or the ones you name) in its shell, both chips for the Pico examples. It then
runs the language server, the linters (clang-tidy, clippy, Ruff, Pyright) and
the formatters' check modes from the command line, plus the Python tests. It
fails on any diagnostic VS Code would show and on any unformatted file:

```sh
scripts/check-examples.sh                      # all examples
scripts/check-examples.sh examples/pico/blink-rust
scripts/check-examples.sh examples/pico         # every example of one system
```

If VS Code still shows stale errors, run **clangd: Restart language server** or
**rust-analyzer: Restart server**.

## Working on this repo

The repo root has its own shell (`nix develop`, or direnv with the root
`.envrc`) with nixfmt, nil, statix, ShellCheck, Ruff and markdownlint for the
repo's Nix, shell, Python and Markdown files. `nix develop -c
scripts/lint-repo.sh` checks them all, and `nix fmt` formats the Nix files.

## Layout

```text
flake.nix                 dev shells, packages, templates, `nix fmt`
nix/clangd.nix            unwrapped clangd / clang-format / clang-tidy
nix/mcu.nix               the `mcu` CLI, built from examples/host/python
nix/msp430-gcc.nix        TI MSP430 GCC + device support files
nix/mspm0-sdk.nix         TI MSPM0 SDK: DriverLib, device headers, startup files, linker scripts
nix/esp-rust.nix          Espressif's Rust toolchain (Xtensa)
nix/rpi-run.nix           copy a binary to a Raspberry Pi over SSH and run it
nix/rpi-boot.nix          write a bare-metal kernel + GPU firmware + config.txt for an SD card
udev/                     udev rule for TI's eZ-FET (the other probes' come with their packages)
scripts/check-examples.sh build, lint, format and language-server check of every example
scripts/clang-tidy-cross.py  clang-tidy over cross-compiled code (used by check-examples)
scripts/lint-repo.sh      lint + format check of the repo's own Nix, shell, Python, Markdown
examples/<system>/        pico, esp32, stm32, mspm0, msp430, rpi, rpi-baremetal, host
examples/<system>/blink-<lang>/   blink-regs-<lang>/ for the register-level ones
  .envrc                  uses this repo's flake locally, the GitHub one otherwise
  .vscode/                language-server, format-on-save + direnv settings, extension recommendations
  .clang-format, .clang-tidy  (C/C++) code style and lint checks
  CMakePresets.json       (C/C++) Ninja build in build/, compile_commands.json on
  .cargo/config.toml      (Rust) target, linker flags, flash runner
  *.ld, memory.x          linker script (register-level examples; see above)
examples/host/python/     uv project + `mcu` CLI (pyproject.toml, uv.lock, src/, tests/)
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
- **Pico 2 (RP2350).** The C/C++ examples (SDK and register-level) have a
  `pico2` preset, and `pico/blink-regs-rust` builds for it with
  `--target thumbv8m.main-none-eabihf`. For a HAL-based Rust project, use
  `rp235x-hal` with that target. Only the Arm cores are covered, not the
  RISC-V Hazard3 cores.
- **Version pins.** ESP-IDF comes from
  [nixpkgs-esp-dev](https://github.com/mirrexagon/nixpkgs-esp-dev), using that
  project's own nixpkgs pin, because ESP-IDF's Python tooling breaks on newer
  nixpkgs. The Rust toolchains come from
  [rust-overlay](https://github.com/oxalica/rust-overlay), and the MSP430
  nightly is pinned through `flake.lock`. embassy-mspm0 isn't on crates.io
  yet, so `mspm0/blink-rust` takes the embassy crates from one pinned git
  commit.
- **Updating.** `nix flake update` bumps everything. The MSP430 GCC and Xtensa
  Rust toolchains and the MSPM0 SDK are pinned by URL or tag and hash in
  `nix/`. After updating, run `scripts/check-examples.sh`.
