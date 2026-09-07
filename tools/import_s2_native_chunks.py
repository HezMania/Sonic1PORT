#!/usr/bin/env python3
"""Phase 77 native Sonic 2 128x128 chunk importer.

Keeps each Sonic 2 Map128 record exactly 128 bytes (8x8 16x16 words) and
emits one layout byte per source 128x128 cell.  No 2x2 -> 256x256 chunk
composition is used by the Phase 77 runtime path.
"""
from __future__ import annotations
import argparse, hashlib, importlib.util, json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def load_module(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(mod)
    return mod

retail = load_module("phase64_import", "import_sonic2_level.py")
simon = load_module("phase76_import", "import_simonwai_hpz.py")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def header_layout(width: int, height: int, body: bytes) -> bytes:
    if len(body) != width * height:
        raise ValueError(f"layout body {len(body)} != {width}x{height}")
    if width < 1 or width > 256 or height < 1 or height > 256:
        raise ValueError("header layout dimensions outside one-byte-minus-one range")
    return bytes((width - 1, height - 1)) + body


def import_ehz_native(src: Path, dst: Path) -> dict:
    map_path = src / "mappings/128x128/EHZ_HTZ.bin"
    layout_path = src / "level/layout/EHZ_1.bin"
    map128 = retail.kosinski_decompress(map_path.read_bytes())
    layout_ram = retail.kosinski_decompress(layout_path.read_bytes())
    if len(map128) != 0x8000:
        raise ValueError(f"EHZ Map128 decoded to {len(map128):#x}, expected 0x8000")
    if len(layout_ram) != 0x1000:
        raise ValueError(f"EHZ layout decoded to {len(layout_ram):#x}, expected 0x1000")
    if any(map128[:128]):
        raise ValueError("EHZ native chunk 0 is not blank")

    fg = bytearray()
    bg = bytearray()
    for row in range(16):
        base = row * 0x100
        fg += layout_ram[base:base + 0x80]
        bg += layout_ram[base + 0x80:base + 0x100]
    fg_file = header_layout(128, 16, bytes(fg))
    bg_file = header_layout(128, 16, bytes(bg))

    out = dst / "s2test"
    out.mkdir(parents=True, exist_ok=True)
    files = {
        "ehz1_map128.bin": map128,
        "ehz1_layout128.bin": fg_file,
        "ehz1_bg128.bin": bg_file,
    }
    for name, data in files.items():
        (out / name).write_bytes(data)
    return {
        "source_map128": str(map_path.relative_to(src)),
        "source_layout": str(layout_path.relative_to(src)),
        "map128_chunks": len(map128) // 128,
        "foreground_128": [128, 16],
        "background_128": [128, 16],
        "max_foreground_chunk": max(fg),
        "max_background_chunk": max(bg),
        "source_sha256": {"map128": sha(map_path.read_bytes()), "layout": sha(layout_path.read_bytes())},
        "output_sha256": {k: sha(v) for k, v in files.items()},
    }


def import_hpz_native(src: Path, dst: Path) -> dict:
    map_path = src / "mappings/128x128/HPZ.bin"
    fg_path = src / "level/layout/HPZ_1.bin"
    bg_path = src / "level/layout/HPZ_BG.bin"
    map128 = simon.kosinski_decompress(map_path.read_bytes())
    if len(map128) != 0x8000:
        raise ValueError(f"HPZ Map128 decoded to {len(map128):#x}, expected 0x8000")
    if any(map128[:128]):
        raise ValueError("HPZ native chunk 0 is not blank")
    # Simon Wai HPZ layouts are already source-native header+byte layouts.
    fw, fh, fb = simon.read_header_layout(fg_path)
    bw, bh, bb = simon.read_header_layout(bg_path)
    fg_file = fg_path.read_bytes()
    bg_file = bg_path.read_bytes()

    out = dst / "s2test"
    out.mkdir(parents=True, exist_ok=True)
    files = {
        "hpz1_map128.bin": map128,
        "hpz1_layout128.bin": fg_file,
        "hpz1_bg128.bin": bg_file,
    }
    for name, data in files.items():
        (out / name).write_bytes(data)
    return {
        "source_map128": str(map_path.relative_to(src)),
        "source_layout": str(fg_path.relative_to(src)),
        "source_background": str(bg_path.relative_to(src)),
        "map128_chunks": len(map128) // 128,
        "foreground_128": [fw, fh],
        "background_128": [bw, bh],
        "max_foreground_chunk": max(fb),
        "max_background_chunk": max(bb),
        "source_sha256": {
            "map128": sha(map_path.read_bytes()),
            "layout": sha(fg_file),
            "background": sha(bg_file),
        },
        "output_sha256": {k: sha(v) for k, v in files.items()},
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("retail_s2", type=Path)
    ap.add_argument("simon_wai_s2", type=Path)
    ap.add_argument("destination", type=Path, help="Sonic1PC data/s1 directory")
    args = ap.parse_args()
    manifest = {
        "phase": 77,
        "format": "native Sonic 2 128x128 chunks",
        "runtime_chunk_bytes": 128,
        "blocks_per_chunk": [8, 8],
        "ehz1": import_ehz_native(args.retail_s2, args.destination),
        "hpz1": import_hpz_native(args.simon_wai_s2, args.destination),
    }
    out = args.destination / "s2test" / "phase77_native_manifest.json"
    out.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
