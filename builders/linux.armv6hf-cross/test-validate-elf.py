#!/usr/bin/env python3
"""Validator contracts only; these are not target compilation/runtime proof."""
from pathlib import Path
import runpy

validate = runpy.run_path(str(Path(__file__).with_name("validate-elf")))["validate"]
header = "Class: ELF32\nData: 2's complement, little endian\nMachine: ARM\nFlags: hard-float ABI\n"
segments = "LOAD\nGNU_STACK\n"
attributes = "Tag_CPU_arch: v6KZ\nTag_FP_arch: VFPv2\nTag_ABI_VFP_args: VFP registers\n"
validate(header, segments, attributes)
cases = [
    (header.replace("ELF32", "ELF64"), segments, attributes),
    (header.replace("Machine: ARM", "Machine: AArch64"), segments, attributes),
    (header.replace("little endian", "big endian"), segments, attributes),
    (header.replace("hard-float ABI", "soft-float ABI"), segments, attributes),
    (header, segments + "INTERP\n", attributes),
    (header, segments + "DYNAMIC\n", attributes),
    (header, segments, attributes.replace("v6KZ", "v7")),
    (header, segments, attributes.replace("v6KZ", "v8")),
    (header, segments, attributes.replace("VFPv2", "VFPv3")),
    (header, segments, attributes.replace("VFP registers", "Base AAPCS")),
    (header, segments, attributes + "Tag_Advanced_SIMD_arch: NEONv1\n"),
    (header, segments, ""),
]
for candidate in cases:
    try:
        validate(*candidate)
    except ValueError:
        continue
    raise AssertionError(candidate)
print("PASS 13 ELF validator contracts (not native qualification)")
