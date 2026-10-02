# Espressif's Rust toolchain fork (what `espup` installs), needed for the
# Xtensa-based ESP32 / ESP32-S2 / ESP32-S3. The Xtensa core library is built
# from the bundled rust-src via `-Zbuild-std`. RISC-V ESP32 chips (C3, C6, H2,
# ...) work with upstream Rust as well.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}:

let
  version = "1.97.0.0";
  baseUrl = "https://github.com/esp-rs/rust-build/releases/download/v${version}";

  rustSrc = fetchurl {
    url = "${baseUrl}/rust-src-${version}.tar.xz";
    hash = "sha256-Vo1oi5+PMy7E0EZXVE+tI+mc4R6ebPWDWXnmiijGi3M=";
  };
in
stdenv.mkDerivation {
  pname = "esp-rust";
  inherit version;

  src = fetchurl {
    url = "${baseUrl}/rust-${version}-x86_64-unknown-linux-gnu.tar.xz";
    hash = "sha256-qZv+5pIh6f9thjiPaBHuaIzUBeagQAo80XhOjUY+nZk=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    patchShebangs install.sh
    ./install.sh --prefix=$out --without=rust-docs,rust-docs-json-preview --disable-ldconfig

    mkdir rust-src && tar -xJf ${rustSrc} -C rust-src --strip-components=1
    patchShebangs rust-src/install.sh
    rust-src/install.sh --prefix=$out --disable-ldconfig
    runHook postInstall
  '';

  meta = {
    description = "Rust toolchain with Xtensa support for ESP32 chips";
    homepage = "https://github.com/esp-rs/rust-build";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [ "x86_64-linux" ];
  };
}
