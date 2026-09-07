#!/usr/bin/env python3
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_s2_cpz_traversal_phase91 import nemesis_decode, palette_line, render_mapping, be16

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / 'assets/objects/s2_cnz'

def frame_count(mapping: bytes) -> int:
    if len(mapping) < 2:
        return 0
    return be16(mapping, 0) // 2

def main():
    if len(sys.argv) != 2:
        raise SystemExit('usage: import_s2_cnz_traversal_phase100.py <retail Sonic 2 source root>')
    src = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)
    sonic = (src / 'art/palettes/SonicAndTails.bin').read_bytes()
    cnz = (src / 'art/palettes/CNZ.bin').read_bytes()
    palettes = [palette_line(sonic)] + [palette_line(cnz[i*32:(i+1)*32]) for i in range(3)]
    banks = [
        ('round_bumper', 'Round bumper from CNZ.bin', 'obj44.bin', 2),
        ('launcher_vertical', 'Vertical impulse spring.bin', 'obj85_a.bin', 0),
        ('launcher_diagonal', 'Diagonal impulse spring from CNZ.bin', 'obj85_b.bin', 0),
        ('flipper', 'Flippers.bin', 'obj86.bin', 2),
        ('big_block', 'Moving block from CNZ and CPZ.bin', 'objD4.bin', 2),
        ('elevator', 'CNZ elevator.bin', 'objD5.bin', 2),
        ('hex_bumper', 'Hexagonal bumper from CNZ.bin', 'objD7.bin', 2),
    ]
    for folder, art_name, map_name, base_palette in banks:
        raw = nemesis_decode((src / 'art/nemesis' / art_name).read_bytes())
        mapping = (src / 'mappings/sprite' / map_name).read_bytes()
        target = OUT / folder
        target.mkdir(parents=True, exist_ok=True)
        count = frame_count(mapping)
        for i in range(count):
            render_mapping(raw, mapping, i, palettes, base_palette).save(target / f'{i:02d}.png')
        print(folder, count)

if __name__ == '__main__': main()
