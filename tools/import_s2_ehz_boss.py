#!/usr/bin/env python3
"""Phase 89: import retail Sonic 2 Emerald Hill boss/capsule art and boss/end music.

Source of truth: retail Sonic 2 disassembly supplied by the user.
The sprite renderer preserves mapping-piece order, flips, and the object's base
palette-line selection. Music reuses the Phase 87 Saxman/SMPS compiler so the
runtime consumes the same graph format as the verified EHZ song.
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image
import importlib.util
import json
import sys

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / "assets" / "objects" / "s2_ehz"
SOUND = PROJECT / "data" / "s1" / "sound"


def be16(data: bytes, off: int) -> int:
    return (data[off] << 8) | data[off + 1]


class BitReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0

    def read(self, count: int) -> int:
        v = 0
        for _ in range(count):
            b = self.data[self.pos >> 3]
            bit = 7 - (self.pos & 7)
            v = (v << 1) | ((b >> bit) & 1)
            self.pos += 1
        return v

    def peek(self, count: int) -> int:
        p = self.pos
        v = self.read(count)
        self.pos = p
        return v


def nemesis_decompress(data: bytes) -> bytes:
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
    row = pixels = rows = previous = 0
    while rows < target_rows:
        if reader.peek(6) == 0x3F:
            reader.read(6)
            value = reader.read(7)
            repeat = ((value >> 4) & 7) + 1
            pixel = value & 0xF
        else:
            idx = reader.peek(8)
            value = table[idx]
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


def genesis_color(w: int, transparent: bool = False):
    if transparent:
        return (0, 0, 0, 0)
    return (((w >> 1) & 7) * 255 // 7, ((w >> 5) & 7) * 255 // 7, ((w >> 9) & 7) * 255 // 7, 255)


def decode_line(data: bytes):
    return [genesis_color(int.from_bytes(data[i * 2:i * 2 + 2], "big"), i == 0) for i in range(16)]


def tile_pixels(raw: bytes, index: int):
    d = raw[index * 32:(index + 1) * 32]
    if len(d) != 32:
        raise ValueError(f"tile {index} out of range ({len(raw)//32} tiles)")
    rows = []
    for y in range(8):
        r = []
        for b in d[y * 4:y * 4 + 4]:
            r.extend((b >> 4, b & 15))
        rows.append(r)
    return rows


def render_frame(raw: bytes, mappings: bytes, frame: int, palettes, base_palette: int) -> Image.Image:
    off = be16(mappings, frame * 2)
    count = be16(mappings, off)
    pieces = []
    for i in range(count):
        q = mappings[off + 2 + i * 8:off + 2 + (i + 1) * 8]
        if len(q) != 8:
            raise ValueError(f"frame {frame} piece {i} truncated")
        y = int.from_bytes(q[0:1], "big", signed=True)
        size = q[1]
        attr = be16(q, 2)
        x = int.from_bytes(q[6:8], "big", signed=True)
        pieces.append((y, size, attr, x))
    im = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    px = im.load()
    ox = oy = 96
    # Earlier mapping pieces win Genesis sprite-link priority; paint backwards.
    for y, size, attr, x in reversed(pieces):
        wt = ((size >> 2) & 3) + 1
        ht = (size & 3) + 1
        base = attr & 0x7FF
        hf = bool(attr & 0x0800)
        vf = bool(attr & 0x1000)
        map_pal = (attr >> 13) & 3
        pal = palettes[(base_palette | map_pal) & 3]
        for dx in range(wt):
            for dy in range(ht):
                sx = wt - 1 - dx if hf else dx
                sy = ht - 1 - dy if vf else dy
                t = tile_pixels(raw, base + sx * ht + sy)
                for yy in range(8):
                    for xx in range(8):
                        ci = t[7 - yy if vf else yy][7 - xx if hf else xx]
                        if ci:
                            tx = ox + x + dx * 8 + xx
                            ty = oy + y + dy * 8 + yy
                            if 0 <= tx < im.width and 0 <= ty < im.height:
                                px[tx, ty] = pal[ci]
    return im


def render_bank(root: Path, folder: str, art_rel: str, map_rel: str, frame_count: int, palettes, base_palette: int):
    raw = nemesis_decompress((root / art_rel).read_bytes())
    mappings = (root / map_rel).read_bytes()
    dest = OUT / folder
    dest.mkdir(parents=True, exist_ok=True)
    for old in dest.glob("*.png"):
        old.unlink()
    for frame in range(frame_count):
        render_frame(raw, mappings, frame, palettes, base_palette).save(dest / f"{frame:02d}.png")
    return len(raw) // 32


def import_music(root: Path):
    # Reuse the exact Phase-87 decoder/compiler to avoid a second SMPS parser.
    phase87_path = PROJECT / "tools" / "import_s2_ehz_presentation.py"
    spec = importlib.util.spec_from_file_location("phase87_s2", phase87_path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)

    def compile_song(filename: str, music_id: int, name: str, prefix: str):
        old_id = mod.PORT_MUSIC_ID
        old_label = mod.label
        mod.PORT_MUSIC_ID = music_id
        mod.label = lambda kind, off: f"{prefix}_{'D' if kind == 'DAC' else ('P' if kind == 'PSG' else 'F')}_{off:04X}"
        try:
            decomp = mod.saxman_decompress((root / "sound" / "music" / filename).read_bytes())
            song = mod.parse_song(decomp)
        finally:
            mod.PORT_MUSIC_ID = old_id
            mod.label = old_label
        song["id"] = music_id
        song["name"] = name
        song["header"]["voice_label"] = prefix + "_Voices"
        # Boss/end music do not use the EHZ speed-up tempo constant. The native
        # driver changes the current tempo with speed shoes only during level BGM.
        song["header"].pop("speed_tempo", None)
        return song

    existing_path = SOUND / "s2_ehz_smps.json"
    db = json.loads(existing_path.read_text(encoding="utf-8")) if existing_path.exists() else {"music": {}}
    db.setdefault("music", {})
    boss = compile_song("Boss.bin", 0x195, "Sonic 2 - Boss", "S2BOSS")
    end = compile_song("End of level.bin", 0x196, "Sonic 2 - End of Level", "S2END")
    db["music"][str(0x195)] = boss
    db["music"][str(0x196)] = end
    existing_path.write_text(json.dumps(db, indent=2) + "\n", encoding="utf-8")

    # Event index -> (source sample number, playback delay byte). Boss adds $89/$8B;
    # end-of-level additionally uses $88. Preserve Phase-87 EHZ PCM files.
    playlist = {
        7: (5, 0x12),   # raw note $88
        8: (5, 0x15),   # $89
        10: (5, 0x1D),  # $8B
    }
    for event_id, (sample_no, delay) in playlist.items():
        raw = (root / "sound" / "DAC" / f"Sample {sample_no}.bin").read_bytes()
        decoded = mod.decode_s2_dac(raw)
        rate = 3579540.0 / (60.0 + delay * 4.0) / 2.0
        values = mod.resample_linear(decoded, rate, mod.MIX_RATE)
        mod.write_pcm16(SOUND / f"s2_ehz_dac_{event_id:02d}.pcm", values)
    return boss, end


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: import_s2_ehz_boss.py <retail Sonic 2 disassembly root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    sonic = (root / "art/palettes/SonicAndTails.bin").read_bytes()
    ehz = (root / "art/palettes/EHZ.bin").read_bytes()
    if len(sonic) != 32 or len(ehz) != 96:
        raise ValueError("unexpected EHZ active palette source sizes")
    palettes = [decode_line(sonic)] + [decode_line(ehz[i * 32:(i + 1) * 32]) for i in range(3)]

    outputs = [
        ("boss_vehicle_pal0", "art/nemesis/Eggpod.bin", "mappings/sprite/obj56_c.bin", 7, 0),
        ("boss_vehicle_pal1", "art/nemesis/Eggpod.bin", "mappings/sprite/obj56_c.bin", 7, 1),
        ("boss_ground_pal0", "art/nemesis/EHZ boss.bin", "mappings/sprite/obj56_b.bin", 8, 0),
        ("boss_ground_pal1", "art/nemesis/EHZ boss.bin", "mappings/sprite/obj56_b.bin", 8, 1),
        ("boss_propeller", "art/nemesis/Chopper blades for EHZ boss.bin", "mappings/sprite/obj56_a.bin", 7, 1),
        ("egg_prison", "art/nemesis/Egg Prison.bin", "mappings/sprite/obj3E.bin", 6, 1),
    ]
    for folder, art, mappings, frames, pal in outputs:
        tiles = render_bank(root, folder, art, mappings, frames, palettes, pal)
        print(f"{folder}: {frames} frames from {tiles} tiles, base palette {pal}")

    boss, end = import_music(root)
    print(f"Boss music: {len(boss['labels'])} graph labels, DAC {boss['source']['used_dac_ids']}")
    print(f"End music: {len(end['labels'])} graph labels, DAC {end['source']['used_dac_ids']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
