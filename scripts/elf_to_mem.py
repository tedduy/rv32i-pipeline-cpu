#!/usr/bin/env python3
"""Convert a little-endian ELF32 image into sparse byte-oriented readmemh."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


ELF_HEADER_SIZE = 52
PROGRAM_HEADER_SIZE = 32
PT_LOAD = 1


class ElfError(ValueError):
    """Raised when an ELF cannot be represented by the compliance RAM."""


def load_segments(path: Path, memory_bytes: int) -> list[tuple[int, bytes]]:
    image = path.read_bytes()
    if len(image) < ELF_HEADER_SIZE or image[:4] != b"\x7fELF":
        raise ElfError(f"{path}: not an ELF file")
    if image[4] != 1:
        raise ElfError(f"{path}: ACT runner requires ELF32")
    if image[5] != 1:
        raise ElfError(f"{path}: ACT runner requires a little-endian ELF")
    machine = struct.unpack_from("<H", image, 18)[0]
    if machine != 243:
        raise ElfError(f"{path}: ELF machine {machine} is not RISC-V")

    phoff = struct.unpack_from("<I", image, 28)[0]
    phentsize = struct.unpack_from("<H", image, 42)[0]
    phnum = struct.unpack_from("<H", image, 44)[0]
    if phentsize < PROGRAM_HEADER_SIZE:
        raise ElfError(f"{path}: invalid program-header size {phentsize}")

    segments: list[tuple[int, bytes]] = []
    for index in range(phnum):
        offset = phoff + index * phentsize
        if offset + PROGRAM_HEADER_SIZE > len(image):
            raise ElfError(f"{path}: truncated program-header table")
        p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, _, _ = (
            struct.unpack_from("<IIIIIIII", image, offset)
        )
        if p_type != PT_LOAD or p_memsz == 0:
            continue
        address = p_paddr if p_paddr != 0 else p_vaddr
        if p_filesz > p_memsz or p_offset + p_filesz > len(image):
            raise ElfError(f"{path}: malformed PT_LOAD segment {index}")
        if address + p_memsz > memory_bytes:
            raise ElfError(
                f"{path}: segment {index} ends at 0x{address + p_memsz:x}, "
                f"outside {memory_bytes}-byte compliance RAM"
            )
        segments.append((address, image[p_offset : p_offset + p_filesz]))

    if not segments:
        raise ElfError(f"{path}: no loadable segments")
    return sorted(segments)


def convert(input_path: Path, output_path: Path, memory_bytes: int) -> None:
    segments = load_segments(input_path, memory_bytes)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="ascii") as output:
        for address, data in segments:
            if not data:
                continue
            output.write(f"@{address:08x}\n")
            output.writelines(f"{byte:02x}\n" for byte in data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path, help="input ACT4 self-checking ELF")
    parser.add_argument("output", type=Path, help="output byte-oriented readmemh")
    parser.add_argument("--memory-bytes", type=int, default=1024 * 1024)
    args = parser.parse_args()
    try:
        convert(args.elf, args.output, args.memory_bytes)
    except (OSError, ElfError) as error:
        parser.error(str(error))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
