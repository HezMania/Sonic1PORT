#!/usr/bin/env python3
"""Phase 118: import retail Sonic 2 Oil Ocean Object $55 boss / Egg Prison art."""
from __future__ import annotations
from pathlib import Path
from PIL import Image
import hashlib, importlib.util, json, shutil, sys

PROJECT = Path(__file__).resolve().parents[1]
OUT = PROJECT / "assets" / "objects" / "s2_ooz"
PALOUT = PROJECT / "data" / "s1" / "palette"
DATA = PROJECT / "data" / "s1" / "s2test"

def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

bossutil = load_module("bossutil118", PROJECT / "tools" / "import_s2_ehz_boss.py")

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main() -> int:
    if len(sys.argv) != 2:
        print("usage: import_s2_ooz_boss_phase118.py <retail Sonic 2 root>", file=sys.stderr)
        return 2
    root = Path(sys.argv[1]).resolve()
    sonic = (root / "art/palettes/SonicAndTails.bin").read_bytes()
    ooz = (root / "art/palettes/OOZ.bin").read_bytes()
    boss_pal = (root / "art/palettes/OOZ Boss.bin").read_bytes()
    if len(sonic) != 32 or len(ooz) != 96 or len(boss_pal) != 32:
        raise ValueError("unexpected OOZ palette source size")
    palettes = [
        bossutil.decode_line(sonic),
        bossutil.decode_line(boss_pal),
        bossutil.decode_line(ooz[32:64]),
        bossutil.decode_line(ooz[64:96]),
    ]
    boss_raw = bossutil.nemesis_decompress((root / "art/nemesis/OOZ boss.bin").read_bytes())
    mappings = (root / "mappings/sprite/obj55.bin").read_bytes()
    parts_dir = OUT / "boss" / "parts"
    parts_dir.mkdir(parents=True, exist_ok=True)
    for p in parts_dir.glob("*.png"):
        p.unlink()
    # Obj55 uses mapping frames $00-$15. Frame 0 is blank but retaining it keeps
    # frame numbers one-to-one with the retail mapping table for validation.
    for frame in range(0x16):
        bossutil.render_frame(boss_raw, mappings, frame, palettes, 0).save(parts_dir / f"{frame:02d}.png")

    prison_raw = bossutil.nemesis_decompress((root / "art/nemesis/Egg Prison.bin").read_bytes())
    prison_maps = (root / "mappings/sprite/obj3E.bin").read_bytes()
    prison_dir = OUT / "egg_prison"
    prison_dir.mkdir(parents=True, exist_ok=True)
    for p in prison_dir.glob("*.png"):
        p.unlink()
    for frame in range(6):
        bossutil.render_frame(prison_raw, prison_maps, frame, palettes, 1).save(prison_dir / f"{frame:02d}.png")

    PALOUT.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / "art/palettes/OOZ Boss.bin", PALOUT / "S2 OOZ Boss.bin")
    outputs = sorted(parts_dir.glob("*.png")) + sorted(prison_dir.glob("*.png")) + [PALOUT / "S2 OOZ Boss.bin"]
    manifest = {
        "phase": 118,
        "boss": "Object $55",
        "boss_hits": 8,
        "boss_start": [0x2940, 0x2D0],
        "boss_art_tiles": len(boss_raw) // 32,
        "camera": {
            "oil_transition_x": 0x2668,
            "oil_y": 0x2D8,
            "arena_lock_x": 0x2880,
            "arena_max_x": 0x28C0,
            "camera_bottom": 0x1E0,
            "camera_top": 0x1D8,
            "screen_shift": 0x5A,
            "defeat_right": 0x2A20,
        },
        "laser_targets_y": [0x238, 0x230, 0x240, 0x25F],
        "egg_prison": [0x2AC0, 0x240],
        "files": {str(p.relative_to(PROJECT)): sha256(p) for p in outputs},
    }
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / "phase118_ooz_boss_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
