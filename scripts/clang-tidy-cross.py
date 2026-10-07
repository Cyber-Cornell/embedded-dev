#!/usr/bin/env python3
"""Runs clang-tidy over cross-compiled sources the way clangd sees them.

clangd learns a GCC cross compiler's target and system headers through
--query-driver and drops flags clang rejects (the `Remove` list in .clangd).
clang-tidy can do neither, so this script rewrites build/compile_commands.json
into a temporary copy that has the same fixes, then runs clang-tidy on it.

Usage (from an example directory): clang-tidy-cross.py FILE...
Prints clang-tidy's warnings; exits non-zero if there are any.
"""

import fnmatch
import json
import re
import shlex
import subprocess
import sys
import tempfile
from functools import cache
from pathlib import Path


def removed_flags() -> list[str]:
    """Flag patterns listed under CompileFlags: Remove: in .clangd, if any."""
    clangd = Path(".clangd")
    if not clangd.exists():
        return []
    text = clangd.read_text()
    block = re.search(r"Remove:\n((?:\s+-\s+\S+\n?)+)", text)
    return re.findall(r"-\s+(\S+)", block.group(1)) if block else []


@cache
def driver_flags(compiler: str, lang: str) -> list[str]:
    """--target and -isystem flags for a GCC cross compiler, like --query-driver."""
    target = subprocess.run(
        [compiler, "-dumpmachine"], capture_output=True, text=True, check=True
    )
    probe = subprocess.run(
        [compiler, f"-x{lang}", "-E", "-v", "-"],
        input="",
        capture_output=True,
        text=True,
        check=True,
    )
    dirs, inside = [], False
    for line in probe.stderr.splitlines():
        if line.startswith("#include <...> search starts here:"):
            inside = True
        elif line.startswith("End of search list."):
            inside = False
        elif inside:
            dirs.append(line.strip())
    return [f"--target={target.stdout.strip()}"] + [f"-isystem{d}" for d in dirs]


def main() -> int:
    files = {str(Path(f).resolve()) for f in sys.argv[1:]}
    remove = removed_flags()
    entries = []
    for entry in json.loads(Path("build/compile_commands.json").read_text()):
        path = str((Path(entry["directory"]) / entry["file"]).resolve())
        if path not in files:
            continue
        args = entry.get("arguments") or shlex.split(entry["command"])
        lang = "c++" if path.endswith((".cpp", ".cc", ".cxx")) else "c"
        kept = [a for a in args[1:] if not any(fnmatch.fnmatch(a, p) for p in remove)]
        entries.append(
            {
                "directory": entry["directory"],
                "file": path,
                "arguments": ["clang", *driver_flags(args[0], lang), *kept],
            }
        )
    if not entries:
        return 0
    with tempfile.TemporaryDirectory() as db:
        (Path(db) / "compile_commands.json").write_text(json.dumps(entries))
        result = subprocess.run(
            ["clang-tidy", "--quiet", "-p", db, *(e["file"] for e in entries)],
            capture_output=True,
            text=True,
            check=False,  # findings are reported below
        )
    # clang-tidy also prints "N warnings generated" summaries; keep the findings.
    findings = [
        line
        for line in result.stdout.splitlines()
        if re.search(r": (warning|error): ", line) or line.startswith(" ")
    ]
    print("\n".join(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
