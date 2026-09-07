#!/usr/bin/env python3
"""Phase 99: reconstruct the deferred retail Aquatic Ruin object art."""
from pathlib import Path
import importlib.util, sys

PROJECT = Path(__file__).resolve().parents[1]
TOOLS = PROJECT / 'tools'
OUT = PROJECT / 'assets' / 'objects' / 's2_arz'

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec); assert spec.loader
    spec.loader.exec_module(mod); return mod
trav = load('trav', TOOLS / 'import_s2_cpz_traversal_phase91.py')

def mapping_blob(frames):
    # Sonic 2 8-byte mapping format: offset table, count word, pieces.
    count = len(frames)
    table = bytearray(count * 2)
    body = bytearray()
    for fi, pieces in enumerate(frames):
        off = count * 2 + len(body)
        table[fi*2:fi*2+2] = off.to_bytes(2, 'big')
        body += len(pieces).to_bytes(2, 'big')
        for y, size, attr, aux, x in pieces:
            body += bytes((y & 0xFF, size & 0xFF))
            body += (attr & 0xFFFF).to_bytes(2, 'big')
            body += (aux & 0xFFFF).to_bytes(2, 'big')
            body += (x & 0xFFFF).to_bytes(2, 'big')
    return bytes(table + body)


def be16(data, off):
    return (data[off] << 8) | data[off+1]

def s8(v):
    return v - 0x100 if v & 0x80 else v

def s16(v):
    return v - 0x10000 if v & 0x8000 else v

def mapping_pieces(maps, frame):
    off = be16(maps, frame * 2)
    count = be16(maps, off)
    out = []
    for i in range(count):
        q = off + 2 + i * 8
        out.append((s8(maps[q]), maps[q+1], be16(maps,q+2), be16(maps,q+4), s16(be16(maps,q+6))))
    return out

def save_piece_bank(raw, maps, folder, frame, palettes, base):
    dest = OUT / folder; dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob('*.png'): old.unlink()
    pieces = mapping_pieces(maps, frame)
    for i, piece in enumerate(pieces):
        trav.render_mapping(raw, mapping_blob([[piece]]), 0, palettes, base).save(dest / f'{i:02d}.png')
    print(folder, len(pieces))

def save_bank(raw, maps, folder, frames, palettes, base):
    dest = OUT / folder; dest.mkdir(parents=True, exist_ok=True)
    for p in dest.glob('*.png'): p.unlink()
    for i in range(frames):
        trav.render_mapping(raw, maps, i, palettes, base).save(dest / f'{i:02d}.png')
    print(folder, frames)

def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: import_s2_arz_objects_phase99.py <retail Sonic 2 root>')
    src = Path(sys.argv[1]).resolve()
    sonic = (src/'art/palettes/SonicAndTails.bin').read_bytes()
    zone = (src/'art/palettes/ARZ.bin').read_bytes()
    palettes = [trav.palette_line(sonic)] + [trav.palette_line(zone[i*32:(i+1)*32]) for i in range(3)]
    level_art = (PROJECT/'data/s1/s2test/arz1_art.bin').read_bytes()

    # Resident level-art mappings.
    for folder, map_name, base, frames in [
        ('collapse', 'obj1F_d.bin', 2, 2),
        ('falling_pillar', 'obj23.bin', 1, 3),
        ('rising_pillar', 'obj2B.bin', 1, 14),
        ('platform82', 'obj82.bin', 0, 2),
        ('swing', 'obj83.bin', 0, 4),
    ]:
        save_bank(level_art, (src/'mappings/sprite'/map_name).read_bytes(), folder, frames, palettes, base)

    # Per-piece breakup frames preserve the original mappings and let the
    # runtime reproduce Obj1F/Obj2B's staggered fragment motion.
    collapse_maps = (src/'mappings/sprite/obj1F_d.bin').read_bytes()
    rise_maps = (src/'mappings/sprite/obj2B.bin').read_bytes()
    save_piece_bank(level_art, collapse_maps, 'collapse_fragments', 1, palettes, 2)
    save_piece_bank(level_art, rise_maps, 'rising_fragments', 13, palettes, 1)

    # Dedicated Nemesis banks.
    for folder, art_name, map_name, base, frames in [
        ('arrow', 'Arrow shooter and arrow from ARZ.bin', 'obj22.bin', 0, 5),
        ('leaves', 'Leaves in ARZ.bin', 'obj2C.bin', 3, 4),
        ('whisp', 'Blowfly from ARZ.bin', 'obj8C.bin', 1, 2),
        ('chopchop', 'Shark from ARZ.bin', 'obj91.bin', 1, 2),
    ]:
        raw = trav.nemesis_decode((src/'art/nemesis'/art_name).read_bytes())
        save_bank(raw, (src/'mappings/sprite'/map_name).read_bytes(), folder, frames, palettes, base)

    # Grounder's mappings are inline in s2.asm; reproduce them byte-for-byte.
    ground_frames = [
        [(-12,0,0,0,-8),(-4,6,1,0,-16),(-12,0,0x800,0x800,0),(-4,6,0x801,0x800,0)],
        [(-20,0,7,3,-8),(-12,7,8,4,-16),(-20,0,0x807,0x803,0),(-12,7,0x808,0x804,0)],
        [(-20,15,0x10,8,-16),(12,12,0x20,0x10,-16)],
        [(-20,15,0x10,8,-16),(12,12,0x24,0x12,-16)],
        [(-20,15,0x10,8,-16),(12,12,0x28,0x14,-16)],
    ]
    ground_raw = trav.nemesis_decode((src/'art/nemesis/Grounder from ARZ.bin').read_bytes())
    save_bank(ground_raw, mapping_blob(ground_frames), 'grounder', 5, palettes, 1)

    # Grounder wall cover (Obj8F) and rock debris (Obj90) are inline mappings.
    wall_frames = [[(-8,5,0x4093,0x4049,-16),(-8,5,0x4097,0x404B,0)]]
    save_bank(level_art, mapping_blob(wall_frames), 'grounder_wall', 1, palettes, 0)
    rock_frames = [[(-8,5,0x2C,0x16,-8)],[(-4,0,0x30,0x18,-4)],[(-4,0,0x31,0x18,-4)]]
    save_bank(ground_raw, mapping_blob(rock_frames), 'grounder_rocks', 3, palettes, 1)

    # Obj24's generator uses the inline $E/$F mappings over the BigBubbles bank.
    # These are the two visible generator frames from word_1FCA2/word_1FCAC.
    bubble_frames = [[(-8,5,0,0,-8)],[(-8,5,4,2,-8)]]
    bubble_raw = trav.nemesis_decode((src/'art/nemesis/Bubble generator.bin').read_bytes())
    save_bank(bubble_raw, mapping_blob(bubble_frames), 'bubble_generator', 2, palettes, 0)

if __name__ == '__main__': main()
