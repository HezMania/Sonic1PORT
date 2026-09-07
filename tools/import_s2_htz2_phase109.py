#!/usr/bin/env python3
"""Phase 109: retail Sonic 2 Hill Top Act 2 data + Dynamic_HTZ mountain source."""
from __future__ import annotations
import hashlib, importlib.util, json, sys
from collections import Counter
from pathlib import Path

PROJECT=Path(__file__).resolve().parents[1]
TOOLS=PROJECT/'tools'; DATA=PROJECT/'data'/'s1'/'s2test'

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path); mod=importlib.util.module_from_spec(spec); assert spec.loader; spec.loader.exec_module(mod); return mod
terrain=load('terrain109',TOOLS/'import_sonic2_level.py')
bossutil=load('bossutil109',TOOLS/'import_s2_ehz_boss.py')

def be16(b,o): return (b[o]<<8)|b[o+1]
def sha(b): return hashlib.sha256(b).hexdigest()
def header(w,h,b):
    assert len(b)==w*h
    return bytes((w-1,h-1))+bytes(b)

# Exact word_3FD9C byte offsets used by retail Dynamic_HTZ. The routine selects
# six consecutive words from this transposed 8x? arrangement and DMAs four
# tiles from each source offset into VRAM $500-$517.
MOUNTAIN_DMA_OFFSETS=[
  0x0080,0x0180,0x0280,0x0580,0x0600,0x0700,
  0x0080,0x0180,0x0280,0x0580,0x0600,0x0700,
  0x0980,0x0A80,0x0B80,0x0C80,0x0D00,0x0D80,
  0x0980,0x0A80,0x0B80,0x0C80,0x0D00,0x0D80,
  0x0E80,0x1180,0x1200,0x1280,0x1300,0x1380,
  0x0E80,0x1180,0x1200,0x1280,0x1300,0x1380,
  0x1400,0x1480,0x1500,0x1580,0x1600,0x1900,
  0x1400,0x1480,0x1500,0x1580,0x1600,0x1900,
  0x1D00,0x1D80,0x1E00,0x1F80,0x2400,0x2580,
  0x1D00,0x1D80,0x1E00,0x1F80,0x2400,0x2580,
  0x2600,0x2680,0x2780,0x2B00,0x2F00,0x3280,
  0x2600,0x2680,0x2780,0x2B00,0x2F00,0x3280,
  0x3600,0x3680,0x3780,0x3C80,0x3D00,0x3F00,
  0x3600,0x3680,0x3780,0x3C80,0x3D00,0x3F00,
  0x3F80,0x4080,0x4480,0x4580,0x4880,0x4900,
  0x3F80,0x4080,0x4480,0x4580,0x4880,0x4900,
]

def main():
    if len(sys.argv)!=2: raise SystemExit('usage: import_s2_htz2_phase109.py <retail Sonic 2 root>')
    src=Path(sys.argv[1]).resolve(); DATA.mkdir(parents=True,exist_ok=True)
    layout=terrain.kosinski_decompress((src/'level/layout/HTZ_2.bin').read_bytes())
    assert len(layout)==0x1000
    fg=bytearray(); bg=bytearray()
    for row in range(16):
        off=row*0x100; fg+=layout[off:off+0x80]; bg+=layout[off+0x80:off+0x100]
    # Zone art/maps/collision are common to both retail HTZ acts. Copy the
    # already source-generated Phase-108 copies so Act 2 cannot drift from Act 1.
    common={
      'htz2_art.bin':'htz1_art.bin',
      'htz2_map16.bin':'htz1_map16.bin',
      'htz2_map128.bin':'htz1_map128.bin',
      'htz2_collision_primary.bin':'htz1_collision_primary.bin',
      'htz2_collision_secondary.bin':'htz1_collision_secondary.bin',
    }
    outputs={
      'htz2_layout128.bin':header(128,16,fg),
      'htz2_bg128.bin':header(128,16,bg),
      'htz2_objects.bin':(src/'level/objects/HTZ_2.bin').read_bytes(),
      'htz2_rings.bin':(src/'level/rings/HTZ_2.bin').read_bytes(),
      'htz2_start.bin':(src/'startpos/HTZ_2.bin').read_bytes(),
    }
    for dst,srcname in common.items(): outputs[dst]=(DATA/srcname).read_bytes()
    mountains=bossutil.nemesis_decompress((src/'art/nemesis/Dynamically reloaded cliffs in HTZ background.bin').read_bytes())
    assert len(mountains)==48*0x80, len(mountains)
    # PatchHTZTiles distributes the 48 decompressed $80-byte pieces into the
    # low-RAM addresses in every other six-word row of word_3FD9C. Recreate that
    # RAM image so Dynamic_HTZ can later DMA from the exact retail addresses.
    mountain_ram=bytearray(0x4980)
    src_off=0
    for outer in range(8):
        row=outer*12
        for inner in range(6):
            dst=MOUNTAIN_DMA_OFFSETS[row+inner]
            mountain_ram[dst:dst+0x80]=mountains[src_off:src_off+0x80]
            src_off+=0x80
    assert src_off==len(mountains)
    outputs['s2_htz_mountain_ram.bin']=bytes(mountain_ram)
    offsets=b''.join(x.to_bytes(2,'big') for x in MOUNTAIN_DMA_OFFSETS)
    outputs['s2_htz_mountain_dma_offsets.bin']=offsets
    for n,b in outputs.items(): (DATA/n).write_bytes(b)
    obj=outputs['htz2_objects.bin']; counts=Counter(obj[i+4] for i in range(0,len(obj),6))
    covered={0x03,0x14,0x16,0x18,0x1C,0x26,0x2D,0x2F,0x30,0x31,0x32,0x36,0x3E,0x41,0x74,0x79,0x84,0x92,0x95,0x96}
    coverage=sum(v for k,v in counts.items() if k in covered)
    manifest={
      'phase':109,'level':'Hill Top Zone Act 2',
      'start':[be16(outputs['htz2_start.bin'],0),be16(outputs['htz2_start.bin'],2)],
      'limits':{'left':0,'right':0x3280,'top':0,'bottom':0x720},
      'layout':[128,16],'objects':len(obj)//6,'native_placement_coverage':coverage,
      'object_counts_hex':{f'{k:02X}':v for k,v in sorted(counts.items())},
      'dynamic_htz_mountain_bytes':len(mountains),'dynamic_htz_mountain_ram_bytes':len(mountain_ram),'dynamic_htz_dma_offsets':len(MOUNTAIN_DMA_OFFSETS),
      'sha256':{k:sha(v) for k,v in outputs.items()},
    }
    (DATA/'phase109_htz2_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))
if __name__=='__main__': main()
