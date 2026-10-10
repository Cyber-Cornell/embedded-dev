import sys
from pathlib import Path

import keystone
from unicorn import UC_ARCH_ARM, UC_MODE_THUMB
from unicorn.arm_const import UC_ARM_REG_R0, UC_ARM_REG_R1
from unicorn.unicorn import Uc

from lab_tools.elfinfo import describe, disassemble


def test_describe_this_python():
    # The interpreter running the tests is an ELF program for this machine.
    report = describe(Path(sys.executable).resolve())
    assert "arch     amd64, 64-bit, little-endian" in report
    assert "hardening" in report
    assert "entry point (amd64)" in report


def test_thumb_round_trip():
    # Assemble Cortex-M code with keystone, disassemble it with capstone...
    ks = keystone.Ks(keystone.KS_ARCH_ARM, keystone.KS_MODE_THUMB)
    encoding, _ = ks.asm("adds r0, r0, r1; bx lr")
    code = bytes(encoding or [])
    assert disassemble(code, "thumb") == [
        "0x00000000:  adds r0, r0, r1",
        "0x00000002:  bx lr",
    ]

    # ...and run the first instruction with unicorn.
    uc = Uc(UC_ARCH_ARM, UC_MODE_THUMB)
    uc.mem_map(0x1000, 0x1000)
    uc.mem_write(0x1000, code)
    uc.reg_write(UC_ARM_REG_R0, 40)
    uc.reg_write(UC_ARM_REG_R1, 2)
    uc.emu_start(0x1000 | 1, 0x1002)
    assert uc.reg_read(UC_ARM_REG_R0) == 42
