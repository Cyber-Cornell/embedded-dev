# `rpi-boot <kernel.elf> [boot-dir]`: writes the files a Raspberry Pi boots a
# bare-metal program from: the kernel image (kernel8.img for aarch64,
# kernel.img for ARMv6), the GPU firmware and a config.txt. The boot dir
# defaults to $RPI_BOOT_DIR (e.g. a mounted FAT32 SD card), else boot/ next to
# the ELF. Writing both images to one card makes it boot on every supported Pi.
{
  writeShellApplication,
  coreutils,
  llvm,
  raspberrypifw,
}:

writeShellApplication {
  name = "rpi-boot";
  # llvm-readelf / llvm-objcopy handle both aarch64 and 32-bit Arm ELFs.
  runtimeInputs = [
    coreutils
    llvm
  ];
  text = ''
    if (($# < 1)); then
      echo "usage: rpi-boot <kernel.elf> [boot-dir]   (default: \$RPI_BOOT_DIR, else boot/ next to the ELF)" >&2
      exit 2
    fi
    elf=$1
    dir=$(realpath -m "''${2:-''${RPI_BOOT_DIR:-$(dirname "$elf")/boot}}")
    fw=${raspberrypifw}/share/raspberrypi/boot

    # Don't overwrite the kernel and config.txt of an SD card that boots Linux.
    if [[ -e $dir/cmdline.txt && -z ''${RPI_BOOT_FORCE:-} ]]; then
      echo "rpi-boot: $dir looks like a Linux boot partition (it has cmdline.txt)." >&2
      echo "          Use a separate SD card, or set RPI_BOOT_FORCE=1 to overwrite it." >&2
      exit 1
    fi

    case $(llvm-readelf --file-header "$elf" | sed -n 's/^ *Machine: *//p') in
      AArch64) image=kernel8.img ;;
      ARM) image=kernel.img ;;
      *)
        echo "rpi-boot: $elf is not an Arm ELF" >&2
        exit 1
        ;;
    esac

    mkdir -p "$dir"
    llvm-objcopy -O binary "$elf" "$dir/$image"
    # Pi Zero, Zero W, Zero 2 W and 3 boot through bootcode.bin + start.elf,
    # the Pi 4 through start4.elf. The Pi 5's firmware is in its EEPROM and
    # only reads the device tree from the card.
    cp -f --no-preserve=mode \
      "$fw"/{bootcode.bin,start.elf,fixup.dat,start4.elf,fixup4.dat} \
      "$fw"/bcm2712*-rpi-5-b.dtb "$dir"/
    cat >"$dir/config.txt" <<'EOF'
    # Written by rpi-boot: start a bare-metal kernel instead of Linux.
    # 64-bit boards run kernel8.img; the Pi Zero / Zero W (ARMv6) run kernel.img.
    arm_64bit=1
    [pi0]
    arm_64bit=0
    [pi02]
    arm_64bit=1
    [pi5]
    # Keep the PCIe link to RP1, the chip that drives the 40-pin header. By
    # default the firmware resets it before starting the kernel.
    pciex4_reset=0
    [all]
    EOF
    echo "rpi-boot: wrote $image, firmware and config.txt to $dir"
  '';
}
