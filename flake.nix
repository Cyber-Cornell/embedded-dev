{
  description = "Per-target embedded C/C++/Rust dev shells (RP2040/RP2350, ESP32, STM32, TI MSPM0, TI MSP430, Raspberry Pi Linux and bare metal), a plain-PC base shell, a Python shell for host-side tools and an embedded-security lab shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Deliberately keeps its own nixpkgs pin: ESP-IDF's Python tooling is tied
    # to the nixpkgs release esp-dev tests against.
    esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # pwndbg left nixpkgs; its own flake builds it (with its own gdb and
    # Python pins, so it keeps its own nixpkgs). Pinned to a release tag.
    pwndbg.url = "github:pwndbg/pwndbg/2026.09.15";
  };

  outputs =
    {
      self,
      nixpkgs,
      esp-dev,
      rust-overlay,
      pwndbg,
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
          # TI's MSP Debug Stack (libmsp430.so) is freely redistributable but unfree.
          config.allowUnfreePredicate = pkg: nixpkgs.lib.getName pkg == "msp-debug-stack-bin";
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          msp430-gcc = pkgs.callPackage ./nix/msp430-gcc.nix { };
          mspm0-sdk = pkgs.callPackage ./nix/mspm0-sdk.nix { };
          clangd = pkgs.callPackage ./nix/clangd.nix { };
          esp-rust = pkgs.callPackage ./nix/esp-rust.nix { };
          rpi-run = pkgs.callPackage ./nix/rpi-run.nix { };
          rpi-boot = pkgs.callPackage ./nix/rpi-boot.nix { };
          mcu = pkgs.callPackage ./nix/mcu.nix { };
        }
      );

      # `nix fmt` formats the Nix files.
      formatter = forAllSystems (system: (pkgsFor system).nixfmt);

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (self.packages.${system})
            msp430-gcc
            mspm0-sdk
            clangd
            esp-rust
            rpi-run
            rpi-boot
            mcu
            ;

          # Stable Rust for every Cortex-M flavour (RP2040 = thumbv6m,
          # STM32F4 = thumbv7em-hf, RP2350 = thumbv8m.main-hf, ...). Thumb
          # targets link with the bundled rust-lld, so no extra linker is needed.
          rustCortexM = pkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
            targets = [
              "thumbv6m-none-eabi"
              "thumbv7m-none-eabi"
              "thumbv7em-none-eabi"
              "thumbv7em-none-eabihf"
              "thumbv8m.main-none-eabihf"
            ];
          };

          # Tier-3 targets (msp430-none-elf, armv6-none-eabihf): nightly, core
          # built from source. Pinned through flake.lock like everything else.
          rustNightly = pkgs.rust-bin.selectLatestNightlyWith (
            toolchain:
            toolchain.default.override {
              extensions = [
                "rust-src"
                "rust-analyzer"
              ];
            }
          );

          # Linux userspace on Raspberry Pi boards. musl targets link statically,
          # so binaries run on any Raspberry Pi OS (or other distro) release.
          rustRpi = pkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
            targets = [
              "aarch64-unknown-linux-musl" # Pi 3/4/5, Zero 2 W (64-bit OS)
              "arm-unknown-linux-musleabihf" # Pi Zero/Zero W, or any Pi on a 32-bit OS (ARMv6 + VFP)
            ];
          };

          # Stable Rust for programs that run on this computer.
          rustHost = pkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rust-analyzer"
            ];
          };

          # Python for uv projects: uv uses this interpreter instead of
          # downloading its own (those builds don't run on NixOS).
          python = pkgs.python3;
          pythonTools = [
            python
            pkgs.uv
            pkgs.ruff
            pkgs.pyright
          ];
          uvEnv = {
            UV_PYTHON = "${python}/bin/python3";
            UV_PYTHON_DOWNLOADS = "never";
          };

          # Tools every target shell gets: build system, editor tooling, serial
          # (`mcu` from examples/host/python, and picocom).
          # (mkShell also provides a host C compiler, which Cargo build scripts
          # need; CMake toolchain files pick the cross compilers explicitly.)
          common = with pkgs; [
            cmake
            ninja
            gnumake
            clangd
            bear # `bear -- make` produces compile_commands.json for Makefile projects
            picocom
            mcu
            python3
          ];

          mkTargetShell =
            {
              name,
              packages,
              env ? { },
              shellHook ? "",
            }:
            pkgs.mkShell {
              inherit name env;
              # Target packages come first so their tools shadow the common ones
              # (e.g. ESP-IDF's esp-clang clangd over the generic clangd).
              packages = packages ++ common;
              shellHook = ''
                ${shellHook}
                echo "embedded-dev: ${name} shell"
              '';
            };
        in
        {
          # Raspberry Pi Pico / Pico W / Pico 2 (RP2040, RP2350 Arm cores).
          pico =
            let
              # Submodules carry tinyusb, cyw43-driver (Pico W), lwip, btstack.
              pico-sdk = pkgs.pico-sdk.override { withSubmodules = true; };
            in
            mkTargetShell {
              name = "pico";
              packages = with pkgs; [
                gcc-arm-embedded
                picotool
                openocd
                probe-rs-tools
                rustCortexM
              ];
              env = {
                PICO_SDK_PATH = "${pico-sdk}/lib/pico-sdk";
                PICO_TOOLCHAIN_PATH = "${pkgs.gcc-arm-embedded}";
              };
            };

          # ESP32 family. C/C++ via ESP-IDF, whose esp-idf-full includes the
          # Xtensa and RISC-V GCC toolchains plus esp-clang (a clangd that
          # understands Xtensa). Rust via Espressif's Xtensa-enabled rustc and
          # esp-hal; it links with the ESP-IDF GCC toolchains.
          esp32 = mkTargetShell {
            name = "esp32";
            packages = [
              esp-dev.packages.${system}.esp-idf-full
              esp-rust
              pkgs.rust-analyzer
              pkgs.espflash
            ];
          };

          # STM32 (and any other Cortex-M part: TI TM4C, nRF, SAMD, ...).
          stm32 = mkTargetShell {
            name = "stm32";
            packages = with pkgs; [
              gcc-arm-embedded
              openocd
              stlink
              probe-rs-tools
              rustCortexM
            ];
          };

          # TI MSPM0 (Cortex-M0+; LaunchPads such as LP-MSPM0L2228). The SDK
          # supplies device headers, DriverLib, startup files and linker
          # scripts; probe-rs flashes through the LaunchPad's XDS110 (OpenOCD
          # 0.12 has no MSPM0 flash driver).
          mspm0 = mkTargetShell {
            name = "mspm0";
            packages = with pkgs; [
              gcc-arm-embedded
              probe-rs-tools
              rustCortexM
            ];
            env.MSPM0_SDK_PATH = "${mspm0-sdk}";
          };

          # TI MSP430 (LaunchPads such as MSP-EXP430G2ET, MSP-EXP430FR2433).
          ti = mkTargetShell {
            name = "ti";
            packages = [
              msp430-gcc
              # tilib driver = TI MSP Debug Stack, needed for eZ-FET LaunchPads.
              (pkgs.mspdebug.override {
                enableMspds = true;
                mspds = pkgs.mspds-bin; # the source build is broken against current Boost
              })
              rustNightly
            ];
          };

          # Raspberry Pi 3, 4, 5, Zero, Zero W, Zero 2 W (Linux userspace).
          # Static musl cross compilers: a Nix-built glibc binary would need a
          # /nix/store dynamic loader and a newer glibc than Raspberry Pi OS has.
          # ARMv6 hard-float code also runs on every newer Pi with a 32-bit OS.
          rpi = mkTargetShell {
            name = "rpi";
            packages = [
              pkgs.pkgsCross.aarch64-multiplatform-musl.buildPackages.gcc
              pkgs.pkgsCross.muslpi.buildPackages.gcc
              rustRpi
              rpi-run
              pkgs.openssh
            ];
          };

          # Raspberry Pi 3, 4, 5, Zero, Zero W, Zero 2 W without an OS. The GPU
          # firmware boots kernel8.img (aarch64: Pi 3, 4, 5, Zero 2 W) or
          # kernel.img (ARMv6: Pi Zero / Zero W) from the SD card; `rpi-boot`
          # assembles those files. Rust builds core from source for both targets
          # (armv6-none-eabihf has no prebuilt one).
          rpi-baremetal = mkTargetShell {
            name = "rpi-baremetal";
            packages = [
              pkgs.pkgsCross.aarch64-embedded.buildPackages.gcc
              pkgs.gcc-arm-embedded
              rustNightly
              rpi-boot
            ];
          };

          # Working on this repo itself: formatters and linters for its Nix,
          # shell, Python and Markdown files (scripts/lint-repo.sh runs them).
          default = pkgs.mkShell {
            name = "embedded-dev";
            packages = with pkgs; [
              nixfmt
              nil
              statix
              shellcheck
              ruff
              markdownlint-cli2
            ];
          };

          # Host-side Python: tools that talk to the boards, scripts, crypto.
          host = mkTargetShell {
            name = "host";
            packages = pythonTools;
            env = uvEnv;
          };

          # Plain programs for this computer in C, C++, Rust and Python: no
          # board, no cross compiler. (mkShell's own GCC builds the C/C++.)
          base = mkTargetShell {
            name = "base";
            packages =
              (with pkgs; [
                gdb
                valgrind
                rustHost
              ])
              ++ pythonTools;
            env = uvEnv;
          };

          # Embedded-security lab (eCTF and the like): reverse engineering,
          # debugging, firmware analysis, emulation and logic-analyzer
          # captures, plus a uv project of Python tools (examples/lab/python).
          lab =
            let
              # pwndbg runs its own Python (3.13); the shell's PYTHONPATH,
              # which points at the shell Python's site-packages, would break it.
              pwndbg-cmd = pkgs.writeShellScriptBin "pwndbg" ''
                unset PYTHONPATH
                exec ${pwndbg.packages.${system}.pwndbg}/bin/pwndbg "$@"
              '';
            in
            mkTargetShell {
              name = "lab";
              packages =
                (with pkgs; [
                  # Reverse engineering and binary inspection
                  ghidra
                  radare2
                  imhex # hex editor with pattern language
                  binwalk # carve and identify firmware images
                  hexyl
                  file
                  checksec
                  patchelf
                  # Debugging and emulation. nixpkgs' gdb is multi-arch (Arm,
                  # RISC-V, x86, ...); pwndbg is its own `pwndbg` command.
                  gdb
                  pwndbg-cmd
                  strace
                  qemu # qemu-system-arm etc. and qemu-<arch> user mode
                  # Talking to Cortex-M targets: arm-none-eabi binutils/GCC
                  # (also lets pwntools assemble Arm), debug probes.
                  gcc-arm-embedded
                  openocd
                  probe-rs-tools
                  # Logic analyzers (fx2lafw: SparkFun / Saleae-clone 8-channel
                  # boards; libsigrok bundles the firmware).
                  pulseview
                  sigrok-cli
                  # Network services
                  socat
                  netcat-openbsd
                ])
                ++ pythonTools;
              env = uvEnv // {
                # Binary wheels from PyPI (numpy, lief, z3, angr, keystone, ...)
                # expect the C++ runtime and zlib in the usual system places,
                # which NixOS doesn't have.
                LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
                  pkgs.stdenv.cc.cc.lib
                  pkgs.zlib
                ];
              };
            };
        }
      );

      # One template per example, named <system>-<example> without "blink-"
      # or "hello-": examples/pico/blink-regs-c is
      # `nix flake init -t <this flake>#pico-regs-c`, examples/base/hello-c is
      # #base-c, examples/host/python is #host-python.
      templates =
        let
          inherit (nixpkgs) lib;
          dirsIn =
            path: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
          descriptions = {
            host-python = "Host-side Python project (uv, ruff, pyright, pyserial)";
            lab-python = "Embedded-security Python tools (uv: pwntools, capstone, unicorn, marimo, ...)";
          };
          example =
            system: dir:
            let
              lang = lib.removePrefix "hello-" (lib.removePrefix "blink-" dir);
              name = "${system}-${lang}";
            in
            {
              inherit name;
              value = {
                path = ./examples/${system}/${dir};
                description =
                  descriptions.${name} or (
                    if lib.hasPrefix "hello-" dir then
                      "Hello world for this computer: ${lang}"
                    else
                      "Blink example for ${system}: ${lang}"
                  );
              };
            };
        in
        lib.listToAttrs (
          lib.concatMap (system: map (example system) (dirsIn ./examples/${system})) (dirsIn ./examples)
        );
    };
}
