#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from PIL import Image
import hashlib, json, sys

PROJECT = Path(__file__).resolve().parents[1]
DATA_OUT = PROJECT / 'data/s1/s2test'
ART_OUT = PROJECT / 'assets/objects/s2_rings'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def be16(data: bytes, offset: int) -> int:
    return (data[offset] << 8) | data[offset + 1]


class BitReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
    def read(self, count: int) -> int:
        value = 0
        for _ in range(count):
            byte = self.data[self.pos >> 3]
            bit = 7 - (self.pos & 7)
            value = (value << 1) | ((byte >> bit) & 1)
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

def genesis_color(word: int, transparent: bool = False):
    if transparent:
        return (0, 0, 0, 0)
    return (((word >> 1) & 7) * 255 // 7,
            ((word >> 5) & 7) * 255 // 7,
            ((word >> 9) & 7) * 255 // 7, 255)


def decode_palette_line(data: bytes) -> list[tuple[int,int,int,int]]:
    if len(data) < 32:
        raise ValueError('palette line is truncated')
    out=[]
    for i in range(16):
        w=int.from_bytes(data[i*2:i*2+2],'big')
        out.append(genesis_color(w, i == 0))
    return out


def tile_pixels(raw: bytes, index: int) -> list[list[int]]:
    d=raw[index*32:(index+1)*32]
    if len(d) != 32:
        raise ValueError(f'tile {index} out of range')
    rows=[]
    for y in range(8):
        row=[]
        for b in d[y*4:y*4+4]: row += [b >> 4, b & 0x0F]
        rows.append(row)
    return rows


def render_retail_ring_frames(art_raw: bytes, mappings: bytes, palette: list[tuple[int,int,int,int]]) -> list[Image.Image]:
    # Retail MapUnc_Rings is the compact BuildRings form: 8 word offsets followed
    # directly by one 8-byte mapping piece per frame (no piece-count word).
    frames=[]
    for frame in range(8):
        off=int.from_bytes(mappings[frame*2:frame*2+2], 'big')
        piece=mappings[off:off+8]
        if len(piece) != 8:
            raise ValueError('ring mapping frame truncated')
        y=int.from_bytes(piece[0:1], 'big', signed=True)
        size=piece[1]
        attr=int.from_bytes(piece[2:4], 'big')
        x=int.from_bytes(piece[6:8], 'big', signed=True)
        wt=((size >> 2) & 3) + 1
        ht=(size & 3) + 1
        base=attr & 0x7FF
        hf=bool(attr & 0x0800); vf=bool(attr & 0x1000)
        im=Image.new('RGBA', (96,96), (0,0,0,0)); px=im.load(); ox=48; oy=48
        for tx in range(wt):
            for ty in range(ht):
                t=tile_pixels(art_raw, base + tx*ht + ty)
                for yy in range(8):
                    for xx in range(8):
                        ci=t[7-yy if vf else yy][7-xx if hf else xx]
                        if ci:
                            px[ox+x+tx*8+xx, oy+y+ty*8+yy]=palette[ci]
        frames.append(im)
    return frames


def parse_ring_groups(data: bytes):
    groups=[]; off=0; terminated=False
    while off + 1 < len(data):
        x=int.from_bytes(data[off:off+2], 'big'); off += 2
        if x & 0x8000:
            terminated=True
            break
        if off + 1 >= len(data):
            raise ValueError('truncated S2 ring descriptor')
        yd=int.from_bytes(data[off:off+2], 'big'); off += 2
        vertical=bool(yd & 0x8000)
        count=((yd >> 12) & 7) + 1
        y=yd & 0x0FFF
        groups.append({'x':x,'y':y,'vertical':vertical,'count':count,'raw_y':yd})
    if not terminated:
        raise ValueError('S2 ring list has no negative X terminator')
    return groups


def expanded_count(groups) -> int:
    return sum(g['count'] for g in groups)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit('usage: import_s2_rings.py <retail-s2-root> <simon-wai-root>')
    retail=Path(sys.argv[1]); beta=Path(sys.argv[2])
    DATA_OUT.mkdir(parents=True, exist_ok=True); ART_OUT.mkdir(parents=True, exist_ok=True)
    sources={
        'ehz1_rings': retail/'level/rings/EHZ_1.bin',
        'hpz1_rings': beta/'level/rings/HPZ_1.bin',
        'ring_art': retail/'art/nemesis/Ring.bin',
        'retail_ring_map': retail/'mappings/sprite/Rings.bin',
        'beta_ring_map': beta/'mappings/sprite/obj25.bin',
        'ehz_palette': retail/'art/palettes/EHZ.bin',
        'hpz_palette': beta/'art/palettes/HPZ.bin',
    }
    for k,p in sources.items():
        if not p.is_file(): raise FileNotFoundError(f'{k}: {p}')

    ehz=sources['ehz1_rings'].read_bytes(); hpz=sources['hpz1_rings'].read_bytes()
    (DATA_OUT/'ehz1_rings.bin').write_bytes(ehz)
    (DATA_OUT/'hpz1_rings.bin').write_bytes(hpz)
    eg=parse_ring_groups(ehz); hg=parse_ring_groups(hpz)

    raw=nemesis_decompress(sources['ring_art'].read_bytes())
    retail_map=sources['retail_ring_map'].read_bytes(); beta_map=sources['beta_ring_map'].read_bytes()
    # Simon Wai stores the same one-piece records with a piece-count word. Confirm
    # the actual frame pieces are identical before sharing the generated PNG bank.
    for fr in range(8):
        ro=int.from_bytes(retail_map[fr*2:fr*2+2], 'big'); rp=retail_map[ro:ro+8]
        bo=int.from_bytes(beta_map[fr*2:fr*2+2], 'big'); count=int.from_bytes(beta_map[bo:bo+2], 'big'); bp=beta_map[bo+2:bo+10]
        if count != 1 or rp != bp:
            raise ValueError(f'Beta/final ring mapping frame {fr} is not visually identical')
    epal=decode_palette_line(sources['ehz_palette'].read_bytes())
    hpal=decode_palette_line(sources['hpz_palette'].read_bytes())
    used=set()
    for b in raw: used.update((b >> 4, b & 0x0F))
    for ci in used - {0}:
        if epal[ci] != hpal[ci]:
            raise ValueError(f'EHZ/HPZ ring-used palette index {ci} differs')
    frames=render_retail_ring_frames(raw, retail_map, epal)
    for i,im in enumerate(frames): im.save(ART_OUT/f'{i:02d}.png')

    manifest={
        'phase':80,
        'format':'source-native Sonic 2 ring descriptors',
        'sources':{k:{'path':str(p.relative_to(retail if str(p).startswith(str(retail)) else beta)),'sha256':sha(p.read_bytes())} for k,p in sources.items()},
        'outputs':{
            'ehz1_rings.bin':{'sha256':sha(ehz),'groups':len(eg),'expanded_rings':expanded_count(eg)},
            'hpz1_rings.bin':{'sha256':sha(hpz),'groups':len(hg),'expanded_rings':expanded_count(hg)},
            's2_ring_frames':{f'{i:02d}.png':sha((ART_OUT/f'{i:02d}.png').read_bytes()) for i in range(8)},
        },
        'runtime_translation':{'horizontal_spacing':24,'vertical_spacing':24,'max_group_count':8}
    }
    (DATA_OUT/'phase80_rings_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f"EHZ1: {len(eg)} source descriptors -> {expanded_count(eg)} rings")
    print(f"HPZ1: {len(hg)} source descriptors -> {expanded_count(hg)} rings")
    print('Generated 8 source-faithful S2 ring/sparkle frames')

if __name__=='__main__': main()
