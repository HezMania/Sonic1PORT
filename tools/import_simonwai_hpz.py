#!/usr/bin/env python3
"""Phase 76 Simon Wai Hidden Palace -> Sonic1PC terrain converter.

Uses only source assets from the user-supplied Sonic 2 Simon Wai disassembly.
The runtime target remains the existing Sonic1PC 256x256-chunk renderer, so each
2x2 group of prototype 128x128 chunks is composed losslessly into one container
chunk while retaining every original 16-bit Sonic 2 block word.

Phase 76 intentionally imports terrain, palette, start position, primary and
secondary collision, and a source-faithful initial animated-orb VRAM image.
Objects, rings, HPZ music, palette cycling, scanline deformation and live orb DMA
remain later compatibility layers.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

TILE_BYTES = 32
MAX_TILES = 0x800


def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off + 1]


def put16(buf: bytearray, value: int) -> None:
    buf.extend(((value >> 8) & 0xFF, value & 0xFF))


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


def nemesis_decompress(data: bytes) -> bytes:
    if len(data) < 3:
        return b""
    header = be16(data, 0)
    xor_mode = bool(header & 0x8000)
    target_rows = (header & 0x7FFF) * 8
    table = [0] * 256
    source = 2
    marker = data[source]
    source += 1
    while marker != 0xFF and source < len(data):
        palette = marker & 0xF
        while source < len(data):
            marker = data[source]
            source += 1
            if marker >= 0x80:
                break
            length = marker & 0xF
            repeat = (marker >> 4) & 7
            if source >= len(data):
                raise ValueError("truncated Nemesis code table")
            code = data[source]
            source += 1
            value = (length << 8) | (repeat << 4) | palette
            if length == 8:
                table[code] = value
            else:
                shift = 8 - length
                first = code << shift
                for i in range(1 << shift):
                    table[first + i] = value
    reader = BitReader(data[source:] + b"\0\0")
    out = bytearray()
    row = 0
    pixels = 0
    rows = 0
    previous = 0
    while rows < target_rows:
        if reader.peek(6) == 0x3F:
            reader.read(6)
            value = reader.read(7)
            repeat = ((value >> 4) & 7) + 1
            pixel = value & 0xF
        else:
            index = reader.peek(8)
            value = table[index]
            length = (value >> 8) & 0xFF
            if not length:
                raise ValueError("invalid Nemesis prefix")
            reader.read(length)
            repeat = ((value >> 4) & 7) + 1
            pixel = value & 0xF
        for _ in range(repeat):
            if rows >= target_rows:
                break
            row = (row << 4) | pixel
            pixels += 1
            if pixels == 8:
                word = row
                if xor_mode:
                    word ^= previous
                    previous = word
                out.extend(word.to_bytes(4, "big"))
                rows += 1
                pixels = 0
                row = 0
    return bytes(out)


def kosinski_decompress(data: bytes) -> bytes:
    out = bytearray()
    if len(data) < 2:
        return bytes(out)
    src = 2
    descriptor = data[0] | (data[1] << 8)
    bits_left = 16

    def get_bit():
        nonlocal src, descriptor, bits_left
        bit = descriptor & 1
        descriptor >>= 1
        bits_left -= 1
        if bits_left == 0:
            if src + 1 < len(data):
                descriptor = data[src] | (data[src + 1] << 8)
                src += 2
                bits_left = 16
        return bit

    while src < len(data):
        if get_bit():
            if src >= len(data):
                break
            out.append(data[src])
            src += 1
            continue
        if get_bit() == 0:
            length = ((get_bit() << 1) | get_bit()) + 2
            if src >= len(data):
                break
            displacement = data[src] - 0x100
            src += 1
        else:
            if src + 1 >= len(data):
                break
            low, high = data[src], data[src + 1]
            src += 2
            displacement = (0xE000 | ((high & 0xF8) << 5) | low) - 0x10000
            short_length = high & 7
            if short_length:
                length = short_length + 2
            else:
                if src >= len(data):
                    break
                extra = data[src]
                src += 1
                if extra == 0:
                    break
                if extra == 1:
                    continue
                length = extra + 1
        for _ in range(length):
            idx = len(out) + displacement
            if idx < 0 or idx >= len(out):
                raise ValueError(f"invalid Kosinski back-reference {idx}/{len(out)}")
            out.append(out[idx])
    return bytes(out)


def source_chunk_words(chunk_data: bytes, chunk_id: int) -> list[int]:
    if chunk_id == 0:
        return [0] * 64
    off = chunk_id * 128
    if off + 128 > len(chunk_data):
        raise ValueError(f"chunk ${chunk_id:02X} outside {len(chunk_data)//128} decoded chunks")
    return [be16(chunk_data, off + i * 2) for i in range(64)]


def compose_256(chunk_data: bytes, ids: tuple[int, int, int, int]) -> bytes:
    quads = [source_chunk_words(chunk_data, i) for i in ids]
    out = bytearray()
    for by in range(16):
        qy = 0 if by < 8 else 2
        ly = by & 7
        for bx in range(16):
            q = qy + (1 if bx >= 8 else 0)
            put16(out, quads[q][ly * 8 + (bx & 7)])
    if len(out) != 512:
        raise AssertionError("256x256 chunk was not 512 bytes")
    return bytes(out)


def read_header_layout(path: Path) -> tuple[int, int, bytes]:
    raw = path.read_bytes()
    if len(raw) < 2:
        raise ValueError(f"layout is truncated: {path}")
    width = raw[0] + 1
    height = raw[1] + 1
    expected = width * height
    body = raw[2:]
    if len(body) != expected:
        raise ValueError(f"layout {path.name}: {len(body)} data bytes, expected {expected}")
    return width, height, body


def seed_hpz_art(src_root: Path, main_art: bytes) -> tuple[bytes, dict]:
    # s2b.asm Dynamic_Normal writes three independent 8-tile windows from the
    # 24-tile Pulsing orb source to VRAM $5D00/$5E00/$5F00. At phase zero those
    # are source tiles 0..7, 8..15 and 16..23 respectively.
    vram = bytearray(MAX_TILES * TILE_BYTES)
    vram[:len(main_art)] = main_art
    orb_path = src_root / "art/uncompressed/Pulsing orb (HPZ).bin"
    orb = orb_path.read_bytes()
    if len(orb) != 24 * TILE_BYTES:
        raise ValueError(f"unexpected HPZ pulsing-orb size: {len(orb)}")
    windows = [(0x2E8, 0), (0x2F0, 8), (0x2F8, 16)]
    seeded = []
    for dst_tile, src_tile in windows:
        piece = orb[src_tile*TILE_BYTES:(src_tile+8)*TILE_BYTES]
        vram[dst_tile*TILE_BYTES:(dst_tile+8)*TILE_BYTES] = piece
        seeded.append({"destination_tile": dst_tile, "source_tile": src_tile, "tiles": 8})
    return bytes(vram), {"source": str(orb_path.relative_to(src_root)), "windows": seeded}


def build_map16(src_root: Path) -> tuple[bytes, dict]:
    base_path = src_root / "mappings/16x16/HPZ.bin"
    patch_path = src_root / "SonLVL INI Files/HPZ/AnimatedBlocks.bin"
    base = base_path.read_bytes()
    packed_patch = patch_path.read_bytes()
    if len(packed_patch) < 4:
        raise ValueError("HPZ AnimatedBlocks.bin is truncated")
    destination = be16(packed_patch, 0)
    word_count_minus_one = be16(packed_patch, 2)
    patch = packed_patch[4:]
    expected = (word_count_minus_one + 1) * 2
    if len(patch) != expected:
        raise ValueError(f"HPZ animated block patch: {len(patch)} bytes, expected {expected}")
    out = bytearray(0x1800)
    if len(base) > len(out):
        raise ValueError("HPZ base map16 is larger than source Block_Table")
    out[:len(base)] = base
    if destination + len(patch) > len(out):
        raise ValueError("HPZ animated block patch exceeds Block_Table")
    out[destination:destination + len(patch)] = patch
    return bytes(out), {
        "base_bytes": len(base),
        "destination": destination,
        "bytes": len(patch),
        "first_block": destination // 8,
        "last_block": (destination + len(patch) - 1) // 8,
    }


def convert_planes(map128: bytes, fg: tuple[int, int, bytes], bg: tuple[int, int, bytes]):
    combo_to_id: dict[tuple[int, int, int, int], int] = {(0, 0, 0, 0): 0}

    def id_for(combo: tuple[int, int, int, int]) -> int:
        if combo not in combo_to_id:
            new_id = len(combo_to_id)
            if new_id > 0xFF:
                raise ValueError("converted HPZ exceeds 8-bit layout chunk IDs")
            combo_to_id[combo] = new_id
        return combo_to_id[combo]

    def plane(layout: tuple[int, int, bytes]) -> tuple[int, int, bytes]:
        width, height, body = layout
        out_w = (width + 1) // 2
        out_h = (height + 1) // 2
        ids = bytearray()
        def at(x: int, y: int) -> int:
            return body[y * width + x] if x < width and y < height else 0
        for cy in range(out_h):
            sy = cy * 2
            for cx in range(out_w):
                sx = cx * 2
                combo = (at(sx, sy), at(sx+1, sy), at(sx, sy+1), at(sx+1, sy+1))
                ids.append(id_for(combo))
        return out_w, out_h, bytes((out_w - 1, out_h - 1)) + bytes(ids)

    fg_out = plane(fg)
    bg_out = plane(bg)
    chunks = bytearray((len(combo_to_id) - 1) * 512)
    for combo, cid in combo_to_id.items():
        if cid == 0:
            continue
        blob = compose_256(map128, combo)
        off = (cid - 1) * 512
        chunks[off:off+512] = blob
    return fg_out, bg_out, bytes(chunks), combo_to_id


def convert_hpz1(src_root: Path, dst_root: Path) -> dict:
    required = {
        "art": src_root / "art/nemesis/HPZ primary.bin",
        "orb": src_root / "art/uncompressed/Pulsing orb (HPZ).bin",
        "map16": src_root / "mappings/16x16/HPZ.bin",
        "map16_patch": src_root / "SonLVL INI Files/HPZ/AnimatedBlocks.bin",
        "map128": src_root / "mappings/128x128/HPZ.bin",
        "layout": src_root / "level/layout/HPZ_1.bin",
        "background": src_root / "level/layout/HPZ_BG.bin",
        "colp": src_root / "level/collision/HPZ primary 16x16 collision index.bin",
        "cols": src_root / "level/collision/HPZ secondary 16x16 collision index.bin",
        "coln": src_root / "level/collision/Collision array 1.bin",
        "colr": src_root / "level/collision/Collision array 2.bin",
        "angle": src_root / "level/collision/Curve and resistance mappings.bin",
        "pal": src_root / "art/palettes/HPZ.bin",
        "start": src_root / "level/startpos/HPZ_1.bin",
    }
    missing = [str(path) for path in required.values() if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing Simon Wai HPZ source files:\n" + "\n".join(missing))

    main_art = nemesis_decompress(required["art"].read_bytes())
    if len(main_art) != 0x2D5 * TILE_BYTES:
        raise ValueError(f"HPZ primary art decoded to {len(main_art)} bytes, expected {0x2D5*TILE_BYTES}")
    art, seeded_art = seed_hpz_art(src_root, main_art)
    map16, block_patch = build_map16(src_root)
    map128 = kosinski_decompress(required["map128"].read_bytes())
    if len(map128) != 0x100 * 128:
        raise ValueError(f"HPZ map128 decoded to {len(map128)} bytes, expected 32768")
    fg_src = read_header_layout(required["layout"])
    bg_src = read_header_layout(required["background"])
    fg, bg, map256, combo_to_id = convert_planes(map128, fg_src, bg_src)

    colp = required["colp"].read_bytes()
    cols = required["cols"].read_bytes()
    coln = required["coln"].read_bytes()
    colr = required["colr"].read_bytes()
    angle = required["angle"].read_bytes()
    pal = required["pal"].read_bytes()
    start = required["start"].read_bytes()
    if len(colp) != 0x300 or len(cols) != 0x300:
        raise ValueError("HPZ collision-index tables are not 0x300 bytes")
    if len(coln) != 0x1000 or len(colr) != 0x1000 or len(angle) != 0x100:
        raise ValueError("shared Simon Wai collision arrays have unexpected sizes")
    if len(pal) != 96 or len(start) != 4:
        raise ValueError("HPZ palette/start data has unexpected size")

    outdir = dst_root / "s2test"
    outdir.mkdir(parents=True, exist_ok=True)
    files = {
        "hpz1_art.bin": art,
        "hpz1_map16.bin": map16,
        "hpz1_map256.bin": map256,
        "hpz1_layout.bin": fg[2],
        "hpz1_bg.bin": bg[2],
        "hpz1_collision_primary.bin": colp,
        "hpz1_collision_secondary.bin": cols,
        "hpz_collision_normal.bin": coln,
        "hpz_collision_rotated.bin": colr,
        "hpz_angle_map.bin": angle,
        "hpz1_start.bin": start,
    }
    for name, blob in files.items():
        (outdir / name).write_bytes(blob)

    paldir = dst_root / "palette"
    paldir.mkdir(parents=True, exist_ok=True)
    palette_name = "S2 Simon Wai Hidden Palace Zone.bin"
    (paldir / palette_name).write_bytes(pal)

    # Provenance/structural checks useful for later compatibility passes.
    source_words = [be16(map128, i) for i in range(0, len(map128), 2)]
    max_block = max(word & 0x3FF for word in source_words)
    used_blocks = {word & 0x3FF for word in source_words}
    used_tiles = set()
    for block_id in used_blocks:
        off = block_id * 8
        for slot in range(4):
            used_tiles.add(be16(map16, off + slot*2) & 0x7FF)

    manifest = {
        "source": "user-supplied Sonic 2 Simon Wai prototype disassembly",
        "level": "Hidden Palace Zone Act 1",
        "source_layout_128": {"foreground": [fg_src[0], fg_src[1]], "background": [bg_src[0], bg_src[1]]},
        "converted_layout_256": {"foreground": [fg[0], fg[1]], "background": [bg[0], bg[1]]},
        "decoded_sizes": {
            "main_art": len(main_art), "seeded_vram_art": len(art), "map16": len(map16),
            "map128": len(map128), "map256": len(map256), "primary_collision_index": len(colp),
            "secondary_collision_index": len(cols),
        },
        "animated_block_patch": block_patch,
        "seeded_animated_art": seeded_art,
        "source_128_chunks": len(map128) // 128,
        "converted_unique_256_chunks": len(combo_to_id) - 1,
        "highest_converted_chunk_id": max(combo_to_id.values()),
        "highest_source_block_id": max_block,
        "highest_used_tile_id": max(used_tiles),
        "start": [be16(start, 0), be16(start, 2)],
        "source_level_bounds": {"left": 0, "right": 0x3FFF, "top": 0, "bottom": 0x720},
        "deferred": ["objects", "rings", "HPZ music", "palette cycle", "scanline deformation", "live pulsing-orb DMA"],
        "source_sha256": {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in required.items()},
        "output_sha256": {name: hashlib.sha256(blob).hexdigest() for name, blob in files.items()},
        "palette_sha256": hashlib.sha256(pal).hexdigest(),
    }
    (outdir / "hpz1_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path, help="root of Sonic 2 Simon Wai disassembly")
    ap.add_argument("destination", type=Path, help="Sonic1PC data/s1 destination")
    args = ap.parse_args()
    print(json.dumps(convert_hpz1(args.source, args.destination), indent=2))


if __name__ == "__main__":
    main()
