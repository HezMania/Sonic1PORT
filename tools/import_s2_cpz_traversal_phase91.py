#!/usr/bin/env python3
from pathlib import Path
from PIL import Image
import json, re, sys

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / "assets/objects/s2_cpz"
DATA = PROJECT / "data/s1/s2test/cpz_spin_tube_paths.json"

def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off + 1]

class BitReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
    def read(self, count: int) -> int:
        value = 0
        for _ in range(count):
            b = self.data[self.pos >> 3]
            bit = 7 - (self.pos & 7)
            value = (value << 1) | ((b >> bit) & 1)
            self.pos += 1
        return value
    def peek(self, count: int) -> int:
        old = self.pos
        value = self.read(count)
        self.pos = old
        return value

def nemesis_decode(data: bytes) -> bytes:
    header = be16(data, 0)
    xor_mode = bool(header & 0x8000)
    rows_needed = (header & 0x7FFF) * 8
    table = [0] * 256
    pos = 2
    marker = data[pos]
    pos += 1
    while marker != 0xFF:
        palette_index = marker & 0x0F
        while True:
            marker = data[pos]
            pos += 1
            if marker >= 0x80:
                break
            bit_len = marker & 0x0F
            repeat = (marker >> 4) & 7
            code = data[pos]
            pos += 1
            packed = (bit_len << 8) | (repeat << 4) | palette_index
            if bit_len == 8:
                table[code] = packed
            else:
                shift = 8 - bit_len
                first = code << shift
                for i in range(1 << shift):
                    table[first + i] = packed
    reader = BitReader(data[pos:] + b"\0\0")
    out = bytearray()
    row = pixels = finished = previous = 0
    while finished < rows_needed:
        if reader.peek(6) == 0x3F:
            reader.read(6)
            value = reader.read(7)
            repeat = ((value >> 4) & 7) + 1
            palette_index = value & 0x0F
        else:
            index = reader.peek(8)
            packed = table[index]
            bit_len = (packed >> 8) & 0xFF
            if not bit_len:
                raise ValueError("Bad Nemesis prefix")
            reader.read(bit_len)
            repeat = ((packed >> 4) & 7) + 1
            palette_index = packed & 0x0F
        for _ in range(repeat):
            if finished >= rows_needed:
                break
            row = (row << 4) | palette_index
            pixels += 1
            if pixels == 8:
                value = row
                if xor_mode:
                    value ^= previous
                    previous = value
                out.extend(value.to_bytes(4, "big"))
                finished += 1
                row = pixels = 0
    return bytes(out)

def genesis_color(word: int, transparent: bool = False):
    if transparent:
        return (0, 0, 0, 0)
    return (((word >> 1) & 7) * 255 // 7,
            ((word >> 5) & 7) * 255 // 7,
            ((word >> 9) & 7) * 255 // 7,
            255)

def palette_line(data: bytes):
    return [genesis_color(int.from_bytes(data[i*2:i*2+2], "big"), i == 0) for i in range(16)]

def tile_pixels(raw: bytes, tile_index: int):
    tile = raw[tile_index*32:(tile_index+1)*32]
    rows = []
    for y in range(8):
        row = []
        for b in tile[y*4:y*4+4]:
            row.extend([b >> 4, b & 0x0F])
        rows.append(row)
    return rows

def render_mapping(raw: bytes, mappings: bytes, frame: int, palettes, base_palette: int) -> Image.Image:
    offset = be16(mappings, frame * 2)
    count = be16(mappings, offset)
    pieces = []
    for i in range(count):
        q = mappings[offset + 2 + i*8: offset + 10 + i*8]
        y = int.from_bytes(q[0:1], "big", signed=True)
        size = q[1]
        attr = be16(q, 2)
        x = int.from_bytes(q[6:8], "big", signed=True)
        pieces.append((y, size, attr, x))
    canvas = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    pix = canvas.load()
    origin_x = origin_y = 96
    # Genesis sprite-builder ordering is back-to-front for these mapping lists.
    for y, size, attr, x in reversed(pieces):
        w_tiles = ((size >> 2) & 3) + 1
        h_tiles = (size & 3) + 1
        base_tile = attr & 0x7FF
        hflip = bool(attr & 0x0800)
        vflip = bool(attr & 0x1000)
        mapping_palette = (attr >> 13) & 3
        pal = palettes[(base_palette | mapping_palette) & 3]
        for dx in range(w_tiles):
            for dy in range(h_tiles):
                sx = w_tiles - 1 - dx if hflip else dx
                sy = h_tiles - 1 - dy if vflip else dy
                tp = tile_pixels(raw, base_tile + sx*h_tiles + sy)
                for yy in range(8):
                    for xx in range(8):
                        ci = tp[7-yy if vflip else yy][7-xx if hflip else xx]
                        if ci == 0:
                            continue
                        px = origin_x + x + dx*8 + xx
                        py = origin_y + y + dy*8 + yy
                        if 0 <= px < 192 and 0 <= py < 192:
                            pix[px, py] = pal[ci]
    return canvas

def parse_obj1e_paths(path: Path):
    text = path.read_text()
    groups = []
    current = None
    for line in text.splitlines():
        if re.match(r"word_[0-9A-Fa-f]+:\s*obj1E67Size", line):
            current = []
            groups.append(current)
            continue
        if current is not None:
            if re.match(r"word_[0-9A-Fa-f]+_End", line):
                current = None
                continue
            m = re.search(r"dc\.w\s+\$([0-9A-Fa-f]+),\s*\$([0-9A-Fa-f]+)", line)
            if m:
                current.append([int(m.group(1), 16), int(m.group(2), 16)])
    return groups

def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: import_s2_cpz_traversal_phase91.py <retail Sonic 2 source root>")
    source = Path(sys.argv[1])
    OUT.mkdir(parents=True, exist_ok=True)

    sonic = (source / "art/palettes/SonicAndTails.bin").read_bytes()
    cpz = (source / "art/palettes/CPZ.bin").read_bytes()
    palettes = [palette_line(sonic)] + [palette_line(cpz[i*32:(i+1)*32]) for i in range(3)]

    banks = [
        ("tipping", "Small yellow moving platform from CPZ.bin", "obj0B.bin", 3, 5),
        ("platform", "Large moving platform from CNZ.bin", "obj19.bin", 3, 1),
        ("booster", "Speed booster from CPZ.bin", "obj1B.bin", 3, 3),
        ("barrier", "Stripy blocks from CPZ.bin", "obj2D.bin", 1, 1),
        ("breakblock", "CPZ large moving platform blocks.bin", "obj32_b.bin", 3, 1),
        ("stair", "Moving block from CPZ.bin", "obj6B.bin", 3, 1),
        ("tube_spring", "CPZ spintube exit cover.bin", "obj7B.bin", 0, 5),
    ]
    for folder, art_name, mapping_name, base_palette, frame_count in banks:
        raw = nemesis_decode((source / "art/nemesis" / art_name).read_bytes())
        mappings = (source / "mappings/sprite" / mapping_name).read_bytes()
        dest = OUT / folder
        dest.mkdir(parents=True, exist_ok=True)
        for old in dest.glob("*.png"):
            old.unlink()
        for frame in range(frame_count):
            render_mapping(raw, mappings, frame, palettes, base_palette).save(dest / f"{frame:02d}.png")
        print(folder, frame_count)

    entry_paths = parse_obj1e_paths(source / "misc/obj1E_a.asm")
    unique_main = parse_obj1e_paths(source / "misc/obj1E_b.asm")
    # off_22E88 has 15 selectors: entries 0 and 1 both point at word_22EA6.
    main_paths = [unique_main[0], unique_main[0]] + unique_main[1:]
    continue_map = [
        2,1,0,0, -1,3,0,0, 4,-2,0,0, -3,-4,0,0,
        -5,-5,0,0, 7,6,0,0, -7,-6,0,0, 8,9,0,0,
        -8,-9,0,0, 11,10,0,0, 12,0,0,0, -11,-10,0,0,
        -12,0,0,0, 0,13,0,0, -13,14,0,0, 0,-14,0,0,
    ]
    payload = {"entry": entry_paths, "main": main_paths, "continue_map": continue_map}
    DATA.write_text(json.dumps(payload, separators=(",", ":")) + "\n")
    print("paths", len(entry_paths), len(main_paths), len(continue_map))

if __name__ == "__main__":
    main()
