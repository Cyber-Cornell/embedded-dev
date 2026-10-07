# TI's MSPM0 SDK, cut down to what a GCC project needs: device headers
# (ti/devices/msp), DriverLib sources (ti/driverlib), the GCC startup files and
# linker scripts, and the CMSIS core headers. The SDK's examples, middleware
# and prebuilt IDE libraries are left out. Projects find it via MSPM0_SDK_PATH,
# which the `mspm0` dev shell exports.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "mspm0-sdk";
  version = "2.11.00.07";

  src = fetchFromGitHub {
    owner = "TexasInstruments";
    repo = "mspm0-sdk";
    tag = "mspm0_sdk_${lib.replaceStrings [ "." ] [ "_" ] finalAttrs.version}";
    sparseCheckout = [
      "source/ti/devices/msp"
      "source/ti/driverlib"
      "source/third_party/CMSIS/Core/Include"
    ];
    hash = "sha256-zip0hWIZAPMssIHGFUdHqCDLE8vi+hDmQDUiH6arln0=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r source license_*.txt $out/
    # Prebuilt DriverLib archives for every compiler (~56 MB); projects
    # compile the DriverLib sources they use instead.
    rm -r $out/source/ti/driverlib/lib
    runHook postInstall
  '';

  meta = {
    description = "TI MSPM0 SDK device headers, DriverLib, startup files and linker scripts";
    homepage = "https://github.com/TexasInstruments/mspm0-sdk";
    license = with lib.licenses; [
      bsd3
      asl20 # CMSIS
    ];
    platforms = lib.platforms.all;
  };
})
