# `rpi-run <binary> [args...]`: copies a cross-compiled binary to a Raspberry
# Pi over SSH and runs it there (Ctrl-C stops it on the Pi). Cargo uses it as
# the runner; the CMake examples call it from their `run` target.
{ writeShellApplication, openssh }:

writeShellApplication {
  name = "rpi-run";
  runtimeInputs = [ openssh ];
  text = ''
    if (($# < 1)); then
      echo "usage: rpi-run <binary> [args...]   (target: \$RPI_HOST, default raspberrypi.local)" >&2
      exit 2
    fi
    host=''${RPI_HOST:-raspberrypi.local}
    bin=$1
    shift
    remote=/tmp/$(basename "$bin")
    scp -q "$bin" "$host:$remote"
    exec ssh -t "$host" "$(printf "%q " "$remote" "$@")"
  '';
}
