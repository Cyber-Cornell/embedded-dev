"""elfinfo: a first look at a program or firmware image.

Prints an ELF file's architecture, entry point, segments and hardening flags
(a Linux program or a cross-compiled firmware .elf), then disassembles the
first instructions at the entry point.

    elfinfo build/blink.elf
    elfinfo /bin/ls -n 16
"""

from __future__ import annotations

import argparse
import os
from pathlib import Path

import capstone

# Keep pwntools from taking over the terminal (colors, progress spinners).
os.environ.setdefault("PWNLIB_NOTERM", "1")
from pwnlib.elf.elf import ELF

# pwntools' architecture name -> capstone architecture and mode.
_CAPSTONE: dict[str, tuple[int, int]] = {
    "amd64": (capstone.CS_ARCH_X86, capstone.CS_MODE_64),
    "i386": (capstone.CS_ARCH_X86, capstone.CS_MODE_32),
    "arm": (capstone.CS_ARCH_ARM, capstone.CS_MODE_ARM),
    "thumb": (capstone.CS_ARCH_ARM, capstone.CS_MODE_THUMB | capstone.CS_MODE_MCLASS),
    "aarch64": (capstone.CS_ARCH_ARM64, capstone.CS_MODE_ARM),
    "riscv32": (
        capstone.CS_ARCH_RISCV,
        capstone.CS_MODE_RISCV32 | capstone.CS_MODE_RISCVC,
    ),
    "riscv64": (
        capstone.CS_ARCH_RISCV,
        capstone.CS_MODE_RISCV64 | capstone.CS_MODE_RISCVC,
    ),
}


def disassemble(code: bytes, arch: str, address: int = 0, count: int = 0) -> list[str]:
    """Disassembles `code` for a pwntools architecture name ("thumb" for Thumb)."""
    if arch not in _CAPSTONE:
        raise ValueError(f"no disassembler for {arch}")
    md = capstone.Cs(*_CAPSTONE[arch])
    return [
        f"{insn.address:#010x}:  {insn.mnemonic} {insn.op_str}".rstrip()
        for insn in md.disasm(code, address, count)
    ]


def describe(path: Path, count: int = 8) -> str:
    """Returns the report elfinfo prints for one ELF file."""
    elf = ELF(str(path), checksec=False)
    # On 32-bit Arm, bit 0 of a code address selects Thumb (all of Cortex-M).
    arch = str(elf.arch)
    entry = elf.entry
    if arch == "arm" and entry & 1:
        arch, entry = "thumb", entry & ~1

    lines = [
        f"{path}",
        f"  arch     {arch}, {elf.bits}-bit, {elf.endian}-endian",
        f"  type     {elf.elftype}",
        f"  entry    {elf.entry:#x}",
        "  segments",
    ]
    lines += [
        f"    {seg.header.p_type:<14} {seg.header.p_vaddr:#010x} "
        f"{seg.header.p_memsz:#8x} {_flags(seg.header.p_flags)}"
        for seg in elf.iter_segments()
    ]
    lines.append("  hardening")
    lines += [
        f"    {line.strip()}"
        for line in (elf.checksec(banner=False, color=False) or "").splitlines()
    ]
    lines.append(f"  entry point ({arch})")
    try:
        code = elf.read(entry, 4 * count)
        lines += [f"    {insn}" for insn in disassemble(code, arch, entry, count)]
    except ValueError as err:
        lines.append(f"    ({err})")
    return "\n".join(lines)


def _flags(p_flags: int) -> str:
    return "".join(
        c if p_flags & bit else "-" for c, bit in (("r", 4), ("w", 2), ("x", 1))
    )


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="A first look at a program or firmware image."
    )
    parser.add_argument("elf", type=Path, nargs="+", help="ELF file(s) to describe")
    parser.add_argument(
        "-n", "--count", type=int, default=8, help="instructions to show"
    )
    args = parser.parse_args(argv)
    print("\n\n".join(describe(path, args.count) for path in args.elf))


if __name__ == "__main__":
    main()
