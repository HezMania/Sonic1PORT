#!/usr/bin/env python3
"""Rebuild Phase 72's GHZ palette-index background from shipped Sonic 1 data.

The output is one byte per pixel (0 = transparent, otherwise CRAM index 1..63)
for the source 8192x256 GHZ background layout. Runtime palette cycling then needs
to upload only a 64x1 palette texture rather than a full RGBA background.
"""
from __future__ import annotations
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "s1"
OUT = DATA / "generated" / "ghz_background_indices.bin"

class BitReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
    def read(self, count: int) -> int:
        value = 0
        for _ in range(count):
            bit = 0
            if (self.pos >> 3) < len(self.data):
                bit = (self.data[self.pos >> 3] >> (7 - (self.pos & 7))) & 1
            value = (value << 1) | bit
            self.pos += 1
        return value
    def peek(self, count: int) -> int:
        old = self.pos
        value = self.read(count)
        self.pos = old
        return value

def enigma(data: bytes) -> bytes:
    inline, flags = data[0], data[1]
    increment = (data[2] << 8) | data[3]
    literal = (data[4] << 8) | data[5]
    reader = BitReader(data[6:])
    out = bytearray()
    def emit(value: int) -> None:
        out.extend(((value >> 8) & 0xFF, value & 0xFF))
    def inline_value() -> int:
        word = 0
        for flag_bit, target_bit in ((4,15),(3,14),(2,13),(1,12),(0,11)):
            if flags & (1 << flag_bit) and reader.read(1):
                word |= 1 << target_bit
        return (word + reader.read(inline)) & 0xFFFF
    while True:
        peek = reader.peek(7)
        if peek < 0x40:
            reader.read(6); entry = peek; repeat = peek >> 1
        else:
            reader.read(7); entry = peek; repeat = peek
        count = (repeat & 0xF) + 1
        opcode = entry >> 4
        if opcode in (0, 1):
            for _ in range(count):
                emit(increment); increment = (increment + 1) & 0xFFFF
        elif opcode in (2, 3):
            for _ in range(count): emit(literal)
        elif opcode == 4:
            value = inline_value()
            for _ in range(count): emit(value)
        elif opcode == 5:
            value = inline_value()
            for _ in range(count):
                emit(value); value = (value + 1) & 0xFFFF
        elif opcode == 6:
            value = inline_value()
            for _ in range(count):
                emit(value); value = (value - 1) & 0xFFFF
        elif opcode == 7:
            if (repeat & 0xF) == 0xF:
                break
            for _ in range(count): emit(inline_value())
    return bytes(out)

def kosinski(data: bytes) -> bytes:
    out = bytearray()
    source = 2
    descriptor = data[0] | (data[1] << 8)
    bits = 16
    def get_bit(source: int, descriptor: int, bits: int):
        value = descriptor & 1
        descriptor >>= 1
        bits -= 1
        if bits == 0:
            descriptor = data[source] | (data[source + 1] << 8)
            source += 2
            bits = 16
        return value, source, descriptor, bits
    while source < len(data):
        first, source, descriptor, bits = get_bit(source, descriptor, bits)
        if first:
            out.append(data[source]); source += 1
            continue
        second, source, descriptor, bits = get_bit(source, descriptor, bits)
        if not second:
            hi, source, descriptor, bits = get_bit(source, descriptor, bits)
            lo, source, descriptor, bits = get_bit(source, descriptor, bits)
            length = ((hi << 1) | lo) + 2
            displacement = data[source] - 0x100
            source += 1
        else:
            low, high = data[source], data[source + 1]
            source += 2
            displacement = (0xE000 | ((high & 0xF8) << 5) | low) - 0x10000
            short = high & 7
            if short:
                length = short + 2
            else:
                extra = data[source]; source += 1
                if extra == 0: break
                if extra == 1: continue
                length = extra + 1
        for _ in range(length):
            out.append(out[len(out) + displacement])
    return bytes(out)

def nemesis(data: bytes) -> bytes:
    header = (data[0] << 8) | data[1]
    xor_mode = bool(header & 0x8000)
    target_rows = (header & 0x7FFF) * 8
    table = [0] * 256
    source = 2
    marker = data[source]; source += 1
    while marker != 0xFF and source < len(data):
        palette = marker & 0xF
        while source < len(data):
            marker = data[source]; source += 1
            if marker >= 0x80: break
            length = marker & 0xF
            repeat = (marker >> 4) & 7
            code = data[source]; source += 1
            value = (length << 8) | (repeat << 4) | palette
            if length == 8:
                table[code] = value
            else:
                shift = 8 - length
                first = code << shift
                for i in range(1 << shift): table[first + i] = value
    reader = BitReader(data[source:] + b"\0\0")
    out = bytearray(); row = 0; pixels = 0; rows = 0; previous = 0
    while rows < target_rows:
        if reader.peek(6) == 0x3F:
            reader.read(6); value = reader.read(7)
            repeat = ((value >> 4) & 7) + 1; pixel = value & 0xF
        else:
            index = reader.peek(8); value = table[index]; length = (value >> 8) & 0xFF
            if not length: raise ValueError("invalid Nemesis prefix")
            reader.read(length); repeat = ((value >> 4) & 7) + 1; pixel = value & 0xF
        for _ in range(repeat):
            if rows >= target_rows: break
            row = (row << 4) | pixel; pixels += 1
            if pixels == 8:
                word = row
                if xor_mode: word ^= previous; previous = word
                out.extend(word.to_bytes(4, "big"))
                rows += 1; pixels = 0; row = 0
    return bytes(out)

def be16(data: bytes, offset: int) -> int:
    return (data[offset] << 8) | data[offset + 1]

def build() -> bytes:
    vram = bytearray(0x800 * 32)
    loads = [
        ("artnem/8x8 - GHZ1.nem", 0x000, "nem"),
        ("artnem/8x8 - GHZ2.nem", 0x1CD, "nem"),
        ("artnem/GHZ Flower Stalk.nem", 0x358, "nem"),
        ("artunc/GHZ Flower Large.unc", 0x35C, "raw"),
        ("artunc/GHZ Flower Small.unc", 0x36C, "raw"),
        ("artunc/GHZ Waterfall.unc", 0x378, "raw"),
    ]
    for relative, tile, kind in loads:
        packed = (DATA / relative).read_bytes()
        raw = nemesis(packed) if kind == "nem" else packed
        vram[tile * 32: tile * 32 + len(raw)] = raw
    blocks = enigma((DATA / "map16/GHZ.eni").read_bytes())
    chunks = kosinski((DATA / "map256/GHZ.kos").read_bytes())
    layout = (DATA / "levels/ghzbg.bin").read_bytes()
    width_chunks = layout[0] + 1
    height_chunks = layout[1] + 1
    ids = layout[2:2 + width_chunks * height_chunks]
    width = width_chunks * 256
    height = height_chunks * 256
    pixels = bytearray(width * height)
    for chunk_y in range(height_chunks):
        for chunk_x in range(width_chunks):
            chunk_id = ids[chunk_y * width_chunks + chunk_x] & 0x7F
            if chunk_id == 0: continue
            chunk_base = (chunk_id - 1) * 512
            for block_y in range(16):
                for block_x in range(16):
                    chunk_word = be16(chunks, chunk_base + (block_y * 16 + block_x) * 2)
                    block_id = chunk_word & 0x3FF
                    block_fx = bool(chunk_word & 0x0800)
                    block_fy = bool(chunk_word & 0x1000)
                    for out_y in range(2):
                        for out_x in range(2):
                            source_x = 1 - out_x if block_fx else out_x
                            source_y = 1 - out_y if block_fy else out_y
                            tile_word = be16(blocks, block_id * 8 + (source_y * 2 + source_x) * 2)
                            tile = tile_word & 0x7FF
                            palette_line = (tile_word >> 13) & 3
                            flip_x = bool(tile_word & 0x0800) ^ block_fx
                            flip_y = bool(tile_word & 0x1000) ^ block_fy
                            for py in range(8):
                                sy = 7 - py if flip_y else py
                                for px in range(8):
                                    sx = 7 - px if flip_x else px
                                    byte = vram[tile * 32 + sy * 4 + (sx >> 1)]
                                    color = ((byte >> 4) & 0xF) if (sx & 1) == 0 else (byte & 0xF)
                                    if color:
                                        x = chunk_x * 256 + block_x * 16 + out_x * 8 + px
                                        y = chunk_y * 256 + block_y * 16 + out_y * 8 + py
                                        pixels[y * width + x] = palette_line * 16 + color
    if width != 8192 or height != 256:
        raise RuntimeError(f"unexpected GHZ background size {width}x{height}")
    return bytes(pixels)

def main() -> int:
    data = build()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(data)
    print(f"wrote {OUT.relative_to(ROOT)}: {len(data)} bytes, max CRAM index {max(data)}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
