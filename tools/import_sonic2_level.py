#!/usr/bin/env python3
"""Phase 64 Sonic 2 -> Sonic1PC terrain converter.

Converts Sonic 2 final-format level terrain into the existing Sonic1PC 256x256
chunk container without altering block/collision semantics.  The runtime keeps
an explicit `chunk_word_format = "s2"` flag so collision can select the proper
Sonic 2 primary/secondary solidity pair.

Phase 64 ships an EHZ1 conversion from the user-supplied Sonic 2 disassembly.
Hidden Palace in that retail disassembly is intentionally incomplete: its
terrain BINCLUDEs are commented out/missing, so this tool refuses to invent it.
"""
from __future__ import annotations
import argparse, hashlib, json
from pathlib import Path


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
            out.append(data[src]); src += 1
            continue
        if get_bit() == 0:
            length = ((get_bit() << 1) | get_bit()) + 2
            if src >= len(data): break
            displacement = data[src] - 0x100; src += 1
        else:
            if src + 1 >= len(data): break
            low, high = data[src], data[src + 1]; src += 2
            displacement = (0xE000 | ((high & 0xF8) << 5) | low) - 0x10000
            short_length = high & 7
            if short_length:
                length = short_length + 2
            else:
                if src >= len(data): break
                extra = data[src]; src += 1
                if extra == 0: break
                if extra == 1: continue
                length = extra + 1
        for _ in range(length):
            idx = len(out) + displacement
            if idx < 0 or idx >= len(out):
                raise ValueError(f"invalid Kosinski back-reference {idx}/{len(out)}")
            out.append(out[idx])
    return bytes(out)


def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off + 1]


def put16(buf: bytearray, value: int) -> None:
    buf += bytes(((value >> 8) & 0xFF, value & 0xFF))


def source_chunk_words(chunk_data: bytes, chunk_id: int) -> list[int]:
    # Sonic 2: 128x128 chunk = 8x8 16x16 block words = 128 bytes.
    if chunk_id == 0:
        return [0] * 64
    off = chunk_id * 128
    if off + 128 > len(chunk_data):
        # ID zero is a real all-zero chunk in retail data; IDs beyond decoded
        # data are invalid and should be visible during conversion.
        raise ValueError(f"chunk ${chunk_id:02X} outside {len(chunk_data)//128} decoded chunks")
    return [be16(chunk_data, off + i * 2) for i in range(64)]


def compose_256(chunk_data: bytes, ids: tuple[int,int,int,int]) -> bytes:
    # TL, TR, BL, BR 128x128 chunks -> one 16x16-block 256x256 chunk.
    quads = [source_chunk_words(chunk_data, i) for i in ids]
    out = bytearray()
    for by in range(16):
        qy = 0 if by < 8 else 2
        ly = by & 7
        for bx in range(16):
            q = qy + (1 if bx >= 8 else 0)
            word = quads[q][ly * 8 + (bx & 7)]
            put16(out, word)
    assert len(out) == 512
    return bytes(out)


def extract_apm_ehz(src_root: Path) -> tuple[int, bytes]:
    """Recover the retail EHZ animated 16x16 block patch from this exact build.

    The split source keeps APM_EHZ assembled in s2built.bin rather than as a
    standalone mapping file.  Parse the listing so the converter remains tied
    to the user's build instead of hard-coding copied mapping words.
    """
    lst_path = src_root / "s2.lst"
    rom_path = src_root / "s2built.bin"
    if not lst_path.is_file() or not rom_path.is_file():
        raise FileNotFoundError("EHZ animated block patch requires s2.lst and s2built.bin")
    import re
    text = lst_path.read_text(errors="replace")
    m_start = re.search(r"(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_EHZ label \*", text)
    m_end = re.search(r"(?m)^.*?/\s*([0-9A-Fa-f]+)\s*:.*APM_EHZ_End:", text)
    if not m_start or not m_end:
        raise ValueError("Could not locate APM_EHZ in Sonic 2 listing")
    start = int(m_start.group(1), 16)
    end = int(m_end.group(1), 16)
    rom = rom_path.read_bytes()
    if start + 4 > len(rom) or end > len(rom) or end <= start + 4:
        raise ValueError("APM_EHZ listing addresses are outside s2built.bin")
    dest = be16(rom, start)
    word_count_minus_one = be16(rom, start + 2)
    patch = rom[start + 4:end]
    expected = (word_count_minus_one + 1) * 2
    if len(patch) != expected:
        raise ValueError(f"APM_EHZ length mismatch: {len(patch):#x} != {expected:#x}")
    if dest + len(patch) != 0x1800:
        raise ValueError(f"APM_EHZ does not terminate at Block_Table+$1800: {dest:#x}+{len(patch):#x}")
    return dest, patch


def seed_ehz_animated_art(src_root: Path, art: bytes) -> tuple[bytes, dict]:
    """Build an initial EHZ VRAM art image using the first retail animation frames.

    Main level art is Kosinski-loaded at tile 0. Dynamic_Normal subsequently
    DMAs the flower/pulse tiles to their fixed VRAM destinations.  Seed those
    destinations so the imported test has the same meaningful first-frame art
    before a Sonic-2 animation driver is ported.
    """
    tile_bytes = 32
    vram = bytearray(0x800 * tile_bytes)
    vram[:min(len(art), len(vram))] = art[:len(vram)]
    entries = [
        ("art/uncompressed/EHZ and HTZ flowers - 1.bin", 0x394, 0),
        ("art/uncompressed/EHZ and HTZ flowers - 2.bin", 0x396, 2),
        ("art/uncompressed/EHZ and HTZ flowers - 3.bin", 0x398, 0),
        ("art/uncompressed/EHZ and HTZ flowers - 4.bin", 0x39A, 0),
        ("art/uncompressed/Pulsing ball against checkered background (EHZ).bin", 0x39C, 0),
    ]
    seeded = {}
    for rel, dst_tile, src_tile in entries:
        path = src_root / rel
        if not path.is_file():
            raise FileNotFoundError(path)
        raw = path.read_bytes()
        src_off = src_tile * tile_bytes
        piece = raw[src_off:src_off + 2 * tile_bytes]
        if len(piece) != 2 * tile_bytes:
            raise ValueError(f"Animated art frame is truncated: {rel}")
        dst_off = dst_tile * tile_bytes
        vram[dst_off:dst_off + len(piece)] = piece
        seeded[rel] = {"destination_tile": dst_tile, "source_tile": src_tile, "bytes": len(piece)}
    return bytes(vram), seeded


def convert_ehz1(src_root: Path, dst_root: Path) -> dict:
    required = {
        "art": src_root / "art/kosinski/EHZ_HTZ.bin",
        "map16": src_root / "mappings/16x16/EHZ.bin",
        "map128": src_root / "mappings/128x128/EHZ_HTZ.bin",
        "layout": src_root / "level/layout/EHZ_1.bin",
        "colp": src_root / "collision/EHZ and HTZ primary 16x16 collision index.bin",
        "cols": src_root / "collision/EHZ and HTZ secondary 16x16 collision index.bin",
        "coln": src_root / "collision/Collision array 1.bin",
        "colr": src_root / "collision/Collision array 2.bin",
        "angle": src_root / "collision/Curve and resistance mapping.bin",
        "pal": src_root / "art/palettes/EHZ.bin",
        "start": src_root / "startpos/EHZ_1.bin",
    }
    missing = [str(p) for p in required.values() if not p.is_file()]
    if missing:
        raise FileNotFoundError("Missing Sonic 2 source files:\n" + "\n".join(missing))

    main_art = kosinski_decompress(required["art"].read_bytes())
    art, seeded_art = seed_ehz_animated_art(src_root, main_art)
    base_map16 = kosinski_decompress(required["map16"].read_bytes())
    apm_dest, apm_patch = extract_apm_ehz(src_root)
    map16_buf = bytearray(0x1800)
    map16_buf[:len(base_map16)] = base_map16
    map16_buf[apm_dest:apm_dest + len(apm_patch)] = apm_patch
    map16 = bytes(map16_buf)
    map128 = kosinski_decompress(required["map128"].read_bytes())
    layout = kosinski_decompress(required["layout"].read_bytes())
    colp = kosinski_decompress(required["colp"].read_bytes())
    cols = kosinski_decompress(required["cols"].read_bytes())
    if len(layout) != 0x1000:
        raise ValueError(f"EHZ1 layout decoded to {len(layout):#x}, expected 0x1000")
    if len(map128) % 128:
        raise ValueError("128x128 mapping size is not chunk-aligned")

    # Final Sonic 2 layout RAM is 16 rows of 0x100 bytes: FG columns 0..127,
    # BG columns 128..255. Pair 2x2 128px chunks so the current renderer can
    # consume them as its native 256px chunks.
    combo_to_id: dict[tuple[int,int,int,int], int] = {(0,0,0,0): 0}
    combo_order: list[tuple[int,int,int,int]] = []
    def id_for(combo):
        if combo not in combo_to_id:
            new_id = len(combo_to_id)
            if new_id > 0x7F:
                raise ValueError("Converted level exceeds Sonic1PC 7-bit chunk-ID test limit")
            combo_to_id[combo] = new_id
            combo_order.append(combo)
        return combo_to_id[combo]

    planes = {}
    for name, xoff in (("fg",0), ("bg",0x80)):
        ids = []
        for cy in range(8):
            sy = cy * 2
            for cx in range(64):
                sx = cx * 2
                combo = (
                    layout[sy * 0x100 + xoff + sx],
                    layout[sy * 0x100 + xoff + sx + 1],
                    layout[(sy + 1) * 0x100 + xoff + sx],
                    layout[(sy + 1) * 0x100 + xoff + sx + 1],
                )
                ids.append(id_for(combo))
        planes[name] = bytes([63,7]) + bytes(ids)

    chunks = bytearray(len(combo_order) * 512)
    for combo, cid in combo_to_id.items():
        if cid == 0: continue
        blob = compose_256(map128, combo)
        off = (cid - 1) * 512
        chunks[off:off+512] = blob

    outdir = dst_root / "s2test"
    outdir.mkdir(parents=True, exist_ok=True)
    files = {
        "ehz1_art.bin": art,
        "ehz1_map16.bin": map16,
        "ehz1_map256.bin": bytes(chunks),
        "ehz1_layout.bin": planes["fg"],
        "ehz1_bg.bin": planes["bg"],
        "ehz1_collision_primary.bin": colp,
        "ehz1_collision_secondary.bin": cols,
        "collision_normal.bin": required["coln"].read_bytes(),
        "collision_rotated.bin": required["colr"].read_bytes(),
        "angle_map.bin": required["angle"].read_bytes(),
        "ehz1_start.bin": required["start"].read_bytes(),
        "empty_objects.bin": b"\xff\xff\x00\x00\x00\x00",
    }
    for name, blob in files.items():
        (outdir / name).write_bytes(blob)
    # Zone palette is 48 colors. Sonic1PC intentionally retains its Sonic 1
    # player palette line 0 while using the exact Sonic 2 EHZ lines 1-3.
    paldir = dst_root / "palette"
    paldir.mkdir(parents=True, exist_ok=True)
    (paldir / "S2 Emerald Hill Zone.bin").write_bytes(required["pal"].read_bytes())

    manifest = {
        "source": "user-supplied Sonic 2 retail disassembly",
        "level": "Emerald Hill Zone Act 1",
        "decoded_sizes": {"main_art":len(main_art),"seeded_vram_art":len(art),"base_map16":len(base_map16),"map16_with_apm":len(map16),"map128":len(map128),"layout":len(layout),"colp":len(colp),"cols":len(cols)},
        "animated_block_patch": {"destination": apm_dest, "bytes": len(apm_patch), "first_block": apm_dest // 8, "last_block": (apm_dest + len(apm_patch) - 1) // 8},
        "seeded_animated_art": seeded_art,
        "converted_unique_256_chunks": len(combo_to_id)-1,
        "layout_256": [64,8],
        "start": [be16(files["ehz1_start.bin"],0), be16(files["ehz1_start.bin"],2)],
        "source_sha256": {k: hashlib.sha256(p.read_bytes()).hexdigest() for k,p in required.items()},
        "output_sha256": {name: hashlib.sha256(blob).hexdigest() for name,blob in files.items()},
    }
    (outdir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def check_hpz(src_root: Path) -> list[str]:
    expected = [
        "art/kosinski/HPZ.bin",
        "mappings/16x16/HPZ.bin",
        "mappings/128x128/HPZ.bin",
        "level/layout/HPZ_1.bin",
        "collision/HPZ primary 16x16 collision index.bin",
        "collision/HPZ secondary 16x16 collision index.bin",
    ]
    return [p for p in expected if not (src_root / p).is_file()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source", type=Path, help="root of Sonic 2 disassembly")
    ap.add_argument("destination", type=Path, help="Sonic1PC data/s1 destination")
    ap.add_argument("--level", default="EHZ1", choices=["EHZ1"])
    args = ap.parse_args()
    missing_hpz = check_hpz(args.source)
    if missing_hpz:
        print("HPZ terrain unavailable in this retail disassembly:")
        for p in missing_hpz: print("  -", p)
    manifest = convert_ehz1(args.source, args.destination)
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()
