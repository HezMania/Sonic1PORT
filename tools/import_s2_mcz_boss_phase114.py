#!/usr/bin/env python3
"""Phase 114: import retail Sonic 2 Mystic Cave boss / falling-rock / Egg Prison art.

Source of truth: the retail Sonic 2 disassembly supplied by the user.
Object $57 uses ArtNem_MCZBoss at VRAM tile $3C0 while its Eggman/Eggpod face
pieces address ArtNem_Eggpod at tile $500.  The mapper therefore sees a $140
tile-relative Eggpod base.  Recreate that exact gap before rendering obj57.bin.
"""
from __future__ import annotations
from pathlib import Path
from PIL import Image
import hashlib
import importlib.util
import json
import shutil
import sys

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / "assets" / "objects" / "s2_mcz"
PALOUT = PROJECT / "data" / "s1" / "palette"
DATA = PROJECT / "data" / "s1" / "s2test"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


bossutil = load_module("bossutil114", PROJECT / "tools" / "import_s2_ehz_boss.py")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render_mapping(raw: bytes, mappings: bytes, frame: int, palettes, base_palette: int = 0) -> Image.Image:
    return bossutil.render_frame(raw, mappings, frame, palettes, base_palette)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: import_s2_mcz_boss_phase114.py <retail Sonic 2 root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()

    sonic = (root / "art/palettes/SonicAndTails.bin").read_bytes()
    mcz = (root / "art/palettes/MCZ.bin").read_bytes()
    boss_pal = (root / "art/palettes/MCZ Boss.bin").read_bytes()
    if len(sonic) != 32 or len(mcz) != 96 or len(boss_pal) != 32:
        raise ValueError("unexpected MCZ palette source size")

    # PalID_MCZ_B replaces Normal_palette_line2 only. Lines 2/3 remain the
    # ordinary MCZ palette and line 0 remains Sonic/Tails.
    palettes = [
        bossutil.decode_line(sonic),
        bossutil.decode_line(boss_pal),
        bossutil.decode_line(mcz[32:64]),
        bossutil.decode_line(mcz[64:96]),
    ]

    boss_raw = bossutil.nemesis_decompress((root / "art/nemesis/MCZ boss.bin").read_bytes())
    eggpod_raw = bossutil.nemesis_decompress((root / "art/nemesis/Eggpod.bin").read_bytes())
    boss_tiles = len(boss_raw) // 32
    eggpod_tiles = len(eggpod_raw) // 32
    if boss_tiles != 0xCC or eggpod_tiles != 0x60:
        raise ValueError(f"unexpected MCZ/Eggpod tile counts: {boss_tiles:#x}/{eggpod_tiles:#x}")

    # ArtTile_ArtNem_MCZBoss=$3C0, ArtTile_ArtNem_Eggpod_4=$500 => +$140.
    eggpod_relative_tile = 0x140
    if boss_tiles > eggpod_relative_tile:
        raise ValueError("MCZ boss art overlaps Eggpod relative tile base")
    combined = boss_raw + bytes((eggpod_relative_tile - boss_tiles) * 32) + eggpod_raw
    mappings = (root / "mappings/sprite/obj57.bin").read_bytes()

    parts_dir = OUT / "boss" / "parts"
    parts_dir.mkdir(parents=True, exist_ok=True)
    for p in parts_dir.glob("*.png"):
        p.unlink()
    # Frames $0-$C and $E-$13 belong to the boss art/Eggpod bank. $D/$14 are
    # the separate uncompressed falling rock / stalactite frames.
    boss_frames = [i for i in range(0x14) if i != 0x0D]
    for frame in boss_frames:
        render_mapping(combined, mappings, frame, palettes, 0).save(parts_dir / f"{frame:02d}.png")

    falling_raw = (root / "art/uncompressed/Falling rocks and stalactites from MCZ.bin").read_bytes()
    if len(falling_raw) // 32 != 8:
        raise ValueError("unexpected falling-rock tile count")
    falling_dir = OUT / "boss" / "falling"
    falling_dir.mkdir(parents=True, exist_ok=True)
    for p in falling_dir.glob("*.png"):
        p.unlink()
    for frame in (0x0D, 0x14):
        render_mapping(falling_raw, mappings, frame, palettes, 0).save(falling_dir / f"{frame:02d}.png")

    prison_raw = bossutil.nemesis_decompress((root / "art/nemesis/Egg Prison.bin").read_bytes())
    prison_maps = (root / "mappings/sprite/obj3E.bin").read_bytes()
    prison_dir = OUT / "egg_prison"
    prison_dir.mkdir(parents=True, exist_ok=True)
    for p in prison_dir.glob("*.png"):
        p.unlink()
    for frame in range(6):
        render_mapping(prison_raw, prison_maps, frame, palettes, 1).save(prison_dir / f"{frame:02d}.png")

    PALOUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "art/palettes/MCZ Boss.bin", PALOUT / "S2 MCZ Boss.bin")

    outputs = sorted(parts_dir.glob("*.png")) + sorted(falling_dir.glob("*.png")) + sorted(prison_dir.glob("*.png"))
    outputs.append(PALOUT / "S2 MCZ Boss.bin")
    manifest = {
        "phase": 114,
        "boss": "Object $57",
        "boss_hits": 8,
        "boss_start": [0x21A0, 0x560],
        "boss_art_tiles": boss_tiles,
        "eggpod_tiles": eggpod_tiles,
        "eggpod_relative_tile": eggpod_relative_tile,
        "falling_art_tiles": len(falling_raw) // 32,
        "camera": {
            "prelude_x": 0x2080,
            "lock_x": 0x20F0,
            "bottom": 0x5D0,
            "top": 0x5C8,
            "screen_shift": 0x5A,
            "escape_right": 0x2240,
        },
        "arena": {"left_patrol": 0x2120, "right_patrol": 0x2200, "bottom_y": 0x660},
        "egg_prison": [0x22E0, 0x660],
        "files": {str(p.relative_to(PROJECT)): sha256(p) for p in outputs},
    }
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / "phase114_mcz_boss_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
