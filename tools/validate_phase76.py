#!/usr/bin/env python3
"""Static Phase 76 validator.

Checks the shipped HPZ import structurally without requiring Godot. With an
optional Simon Wai source path it also regenerates the conversion in a temporary
directory and byte-compares every derived HPZ asset.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import tempfile
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data" / "s1"


def be16(b: bytes, o: int) -> int:
    return (b[o] << 8) | b[o+1]


def load_importer():
    path = ROOT / "tools" / "import_simonwai_hpz.py"
    spec = importlib.util.spec_from_file_location("hpzimp", path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod


def check(condition: bool, text: str, results: list[str]) -> None:
    if not condition:
        raise AssertionError(text)
    results.append("PASS: " + text)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", type=Path, help="optional Simon Wai disassembly root")
    args = ap.parse_args()
    r: list[str] = []
    s2 = DATA / "s2test"
    manifest = json.loads((s2 / "hpz1_manifest.json").read_text())

    expected = {
        "hpz1_art.bin": 0x800 * 32,
        "hpz1_map16.bin": 0x1800,
        "hpz1_map256.bin": 139 * 512,
        "hpz1_layout.bin": 2 + 64 * 8,
        "hpz1_bg.bin": 2 + 4 * 5,
        "hpz1_collision_primary.bin": 0x300,
        "hpz1_collision_secondary.bin": 0x300,
        "hpz_collision_normal.bin": 0x1000,
        "hpz_collision_rotated.bin": 0x1000,
        "hpz_angle_map.bin": 0x100,
        "hpz1_start.bin": 4,
    }
    for name, size in expected.items():
        p = s2 / name
        check(p.is_file(), f"{name} exists", r)
        check(p.stat().st_size == size, f"{name} size = {size}", r)

    layout = (s2 / "hpz1_layout.bin").read_bytes()
    bg = (s2 / "hpz1_bg.bin").read_bytes()
    chunks = (s2 / "hpz1_map256.bin").read_bytes()
    blocks = (s2 / "hpz1_map16.bin").read_bytes()
    art = (s2 / "hpz1_art.bin").read_bytes()
    check((layout[0]+1, layout[1]+1) == (64,8), "HPZ foreground converts to 64x8 256px chunks", r)
    check((bg[0]+1, bg[1]+1) == (4,5), "HPZ background converts to 4x5 256px chunks", r)
    max_id = max(layout[2:] + bg[2:])
    check(max_id == 139, "HPZ exercises full 8-bit imported layout IDs through chunk $8B", r)
    check(max_id * 512 <= len(chunks), "every HPZ layout ID addresses a shipped 256px chunk", r)

    block_ids = []
    for o in range(0, len(chunks), 2):
        block_ids.append(be16(chunks, o) & 0x3FF)
    check(max(block_ids) == 0x2FF, "highest referenced HPZ block is source block $2FF", r)
    check((max(block_ids)+1) * 8 <= len(blocks), "every referenced HPZ block exists", r)

    tile_ids = []
    for block_id in set(block_ids):
        off = block_id * 8
        for slot in range(4):
            tile_ids.append(be16(blocks, off + slot*2) & 0x7FF)
    check(max(tile_ids) == 0x2FF, "highest referenced HPZ tile is source tile $2FF", r)
    check((max(tile_ids)+1) * 32 <= len(art), "every referenced HPZ tile fits the seeded VRAM image", r)
    check(any(art[0x2E8*32:0x300*32]), "source pulsing-orb art is populated at tiles $2E8-$2FF", r)

    start = (s2 / "hpz1_start.bin").read_bytes()
    check((be16(start,0), be16(start,2)) == (560,428), "HPZ source start position is (560, 428)", r)
    check((DATA / "palette" / "S2 Simon Wai Hidden Palace Zone.bin").stat().st_size == 96, "HPZ source palette is 48 colors/96 bytes", r)

    level_data = (ROOT / "scripts/data/ghz_level_data.gd").read_text()
    renderer = (ROOT / "scripts/render/ghz_renderer.gd").read_text()
    catalog = (ROOT / "scripts/data/level_catalog.gd").read_text()
    main = (ROOT / "scripts/main.gd").read_text()
    check('func decode_layout_chunk_id' in level_data and '== "s2"' in level_data, "runtime distinguishes Sonic 2 full-byte layout IDs", r)
    check('level.decode_layout_chunk_id' in renderer, "foreground renderer uses data-defined layout-ID semantics", r)
    check('ZONE_S2_HPZ_TEST := 8' in catalog and '_get_sonic2_hpz_test' in catalog, "HPZ uses a dedicated opt-in catalog slot", r)
    check('KEY_J' in main and 'ZONE_S2_HPZ_TEST' in main, "J debug shortcut enters HPZ without changing H/EHZ", r)
    check('"full_gameplay_support": false' in catalog[catalog.index('static func _get_sonic2_hpz_test'):], "HPZ remains outside normal Sonic 1 progression", r)

    # Confirm generated hashes match the embedded provenance manifest.
    for name, digest in manifest["output_sha256"].items():
        got = hashlib.sha256((s2 / name).read_bytes()).hexdigest()
        check(got == digest, f"manifest SHA-256 matches {name}", r)
    pal_digest = hashlib.sha256((DATA / "palette" / "S2 Simon Wai Hidden Palace Zone.bin").read_bytes()).hexdigest()
    check(pal_digest == manifest["palette_sha256"], "manifest SHA-256 matches HPZ palette", r)

    if args.source:
        imp = load_importer()
        with tempfile.TemporaryDirectory() as td:
            temp_data = Path(td) / "data" / "s1"
            regenerated = imp.convert_hpz1(args.source, temp_data)
            for name in expected:
                check((temp_data / "s2test" / name).read_bytes() == (s2 / name).read_bytes(), f"source regeneration matches {name} byte-for-byte", r)
            check((temp_data / "palette" / "S2 Simon Wai Hidden Palace Zone.bin").read_bytes() == (DATA / "palette" / "S2 Simon Wai Hidden Palace Zone.bin").read_bytes(), "source regeneration matches HPZ palette byte-for-byte", r)
            check(regenerated["converted_unique_256_chunks"] == 139, "source regeneration yields 139 unique converted chunks", r)

    print("Phase 76 static validation")
    print("==========================")
    for line in r:
        print(line)
    print(f"\n{len(r)}/{len(r)} checks passed")


if __name__ == "__main__":
    main()
