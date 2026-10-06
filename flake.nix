{
  description = "Per-target embedded C/C++/Rust dev shells (RP2040/RP2350, ESP32, STM32, TI MSP430, Raspberry Pi Linux and bare metal)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Deliberately keeps its own nixpkgs pin: ESP-IDF's Python tooling is tied
    # to the nixpkgs release esp-dev tests against.
    esp-dev.url = "github:mirrexagon/nixpkgs-esp-dev";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      esp-dev,
      rust-overlay,
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

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
          clangd = pkgs.callPackage ./nix/clangd.nix { };
          esp-rust = pkgs.callPackage ./nix/esp-rust.nix { };
          rpi-run = pkgs.callPackage ./nix/rpi-run.nix { };
          rpi-boot = pkgs.callPackage ./nix/rpi-boot.nix { };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          inherit (self.packages.${system}) msp430-gcc clangd esp-rust rpi-run rpi-boot;

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

          # Tools every target shell gets: build system, editor tooling, serial.
          # (mkShell also provides a host C compiler, which Cargo build scripts
          # need; CMake toolchain files pick the cross compilers explicitly.)
          common = with pkgs; [
            cmake
            ninja
            gnumake
            clangd
            bear # `bear -- make` produces compile_commands.json for Makefile projects
            picocom
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

          # STM32 (and any other Cortex-M part: TI MSPM0/TM4C, nRF, SAMD, ...).
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
        }
      );

      # One template per example: `nix flake init -t <this flake>#pico-rust`.
      templates = nixpkgs.lib.mapAttrs' (
        dir: _:
        nixpkgs.lib.nameValuePair (nixpkgs.lib.removePrefix "blink-" dir) {
          path = ./examples/${dir};
          description = "Blink example: ${nixpkgs.lib.removePrefix "blink-" dir}";
        }
      ) (nixpkgs.lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./examples));
    };
}
