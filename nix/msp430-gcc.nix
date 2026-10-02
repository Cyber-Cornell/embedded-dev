# TI's prebuilt MSP430 GCC toolchain (GCC, binutils, newlib, GDB) bundled with
# TI's device headers and linker scripts. nixpkgs' pkgsCross.msp430 does not
# currently evaluate, and it would ship without TI's device support files.
{
  lib,
  stdenv,
  fetchurl,
  fetchzip,
  autoPatchelfHook,
  ncurses5,
  expat,
  zlib,
}:

let
  baseUrl = "https://dr-download.ti.com/software-development/ide-configuration-compiler-or-debugger/MD-LlCjWuAbzH/9.3.1.2";

  supportFiles = fetchzip {
    url = "${baseUrl}/msp430-gcc-support-files-1.212.zip";
    hash = "sha256-/M7g7wP+c2ul+qQ1WCp3sDPc8veSZlhyX5KAW3AyK20=";
  };

  clangShims = ''
    #if defined(__clang__)
    void __delay_cycles(unsigned long cycles);
    void __bic_SR_register_on_exit(unsigned int bits);
    void __bis_SR_register_on_exit(unsigned int bits);
    #endif
  '';
in
stdenv.mkDerivation {
  pname = "msp430-gcc-ti";
  version = "9.3.1.11";

  src = fetchurl {
    url = "${baseUrl}/msp430-gcc-9.3.1.11_linux64.tar.bz2";
    hash = "sha256-tghRthVl493SGTKYo/rFEgwkAllxdBBsxfhIK56ZhuY=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    ncurses5
    expat
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a . $out/
    # msp430-elf-gdb-py links against Python 2.7; plain msp430-elf-gdb is kept.
    rm $out/bin/msp430-elf-gdb-py
    # Device headers (msp430.h, msp430g2553.h, ...), devices.csv and the
    # per-device linker scripts go into the toolchain's default search dirs,
    # so `-mmcu=<device>` works with no extra -I/-L flags -- and clangd's
    # --query-driver discovers the headers automatically.
    cp ${supportFiles}/include/*.h ${supportFiles}/include/devices.csv $out/msp430-elf/include/
    cp ${supportFiles}/include/*.ld $out/msp430-elf/lib/

    # GCC implements a few MSP430 intrinsics as compiler builtins that clang
    # doesn't know, so clangd reports them as undeclared. Declare them for
    # clang only; GCC never sees this block.
    substituteInPlace $out/msp430-elf/include/in430.h \
      --replace-fail "#endif /* !defined _GNU_ASSEMBLER_ */" "${clangShims}
    #endif /* !defined _GNU_ASSEMBLER_ */"
    runHook postInstall
  '';

  meta = {
    description = "TI MSP430 GCC toolchain with device support files";
    homepage = "https://www.ti.com/tool/MSP430-GCC-OPENSOURCE";
    license = with lib.licenses; [
      gpl3Plus
      bsd3
    ];
    platforms = [ "x86_64-linux" ];
  };
}
