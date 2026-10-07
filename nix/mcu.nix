# `mcu`, the serial-port CLI from examples/host/python, so every dev shell can
# talk to a plugged-in board without setting up a Python environment.
{
  lib,
  python3Packages,
}:

let
  src = ../examples/host/python;
  inherit (lib.importTOML (src + "/pyproject.toml")) project;
in
python3Packages.buildPythonApplication {
  pname = project.name;
  inherit (project) version;
  pyproject = true;

  src = lib.fileset.toSource {
    root = src;
    fileset = lib.fileset.unions [
      (src + "/pyproject.toml")
      (src + "/src")
      (src + "/tests")
    ];
  };

  build-system = [ python3Packages.hatchling ];
  dependencies = [ python3Packages.pyserial ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  meta = {
    inherit (project) description;
    mainProgram = "mcu";
    license = lib.licenses.mit;
  };
}
