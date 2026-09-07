#!/usr/bin/env python3
from pathlib import Path
from collections import Counter
import hashlib, json, subprocess, sys

PROJECT=Path(__file__).resolve().parents[1]
DATA=PROJECT/'data/s1/s2test'
checks=[]
def check(ok,msg):
    ok=bool(ok); checks.append((ok,msg)); print(('PASS' if ok else 'FAIL')+': '+msg)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

catalog=(PROJECT/'scripts/data/level_catalog.gd').read_text()
main=(PROJECT/'scripts/main.gd').read_text()
manager=(PROJECT/'scripts/objects/object_manager.gd').read_text()
adapter=(PROJECT/'scripts/objects/s2_signpost_adapter.gd').read_text()
manifest=json.loads((DATA/'phase88_ehz2_manifest.json').read_text())

check('return _get_sonic2_ehz_test(act)' in catalog and 'clampi(requested_act, 1, 2)' in catalog,
      'S2 EHZ catalog preserves the requested act and clamps to retail acts 1-2')
check('"layout": "s2test/%s_layout128.bin" % suffix' in catalog and '"s2_objects": "s2test/%s_objects.bin" % suffix' in catalog and '"s2_rings": "s2test/%s_rings.bin" % suffix' in catalog,
      'EHZ terrain, object and ring paths select Act 1/2 source-native data independently')
check('"limit_right": 0x29A0 if act == 1 else 0x2940' in catalog and '"limit_bottom": 0x320 if act == 1 else 0x420' in catalog,
      'EHZ2 uses retail initial camera bounds $0000-$2940 / $0000-$0420')
check('Vector2i(ZONE_S2_TEST, 2) if act < 2' in catalog,
      'EHZ1 end-of-act LevelOrder now advances to imported EHZ2')
check('KEY_I:' in main and '_debug_warp(LevelCatalog.ZONE_S2_TEST, 2)' in main,
      'I provides a direct EHZ2 runtime test shortcut while H remains EHZ1')

expected={
 'ehz2_layout128.bin':'8914b4f03d3ed343f275e2100c5d04b0892520762499d4b8a8ad6752ca885495',
 'ehz2_bg128.bin':'ecec9d4bc99370675f9c22ee7fef5444d592d1376854bc88029a7ad1b9d88fea',
 'ehz2_objects.bin':'085597aa4015fe5dae207643369b59373953e247d412c705abd03026b42f8671',
 'ehz2_rings.bin':'67fce4ab9ae55f77f347cee6af6bdb2966d740f59786c2dc3479cacfa00f12b7',
 'ehz2_start.bin':'6e6080c037d444f8d69061e19234cdc56677505a07ea9f0aa330d66d34b8d647',
}
for name,h in expected.items():
    check((DATA/name).is_file() and sha(DATA/name)==h, f'{name} matches deterministic retail S2 source import')

lay=(DATA/'ehz2_layout128.bin').read_bytes(); bg=(DATA/'ehz2_bg128.bin').read_bytes()
check(lay[:2]==bytes((127,15)) and len(lay)==2050, 'EHZ2 foreground is native 128x16 128px-chunk layout with two-byte header')
check(bg[:2]==bytes((127,15)) and len(bg)==2050, 'EHZ2 background is native 128x16 128px-chunk layout with two-byte header')
check(max(lay[2:]) < 0x100 and max(bg[2:]) < 0x100, 'all EHZ2 layout cells remain exact one-byte native chunk IDs')
check((DATA/'ehz2_start.bin').read_bytes()==bytes.fromhex('006002af'), 'EHZ2 starts at retail position ($0060,$02AF)')

obj=(DATA/'ehz2_objects.bin').read_bytes(); counts=Counter(obj[i+4] for i in range(0,len(obj),6))
check(len(obj)==948 and len(obj)//6==158, 'EHZ2 preserves all 158 six-byte retail object records')
expected_counts={0x03:34,0x06:4,0x0D:1,0x11:7,0x18:11,0x1C:14,0x26:12,0x36:20,0x3E:1,0x41:12,0x49:8,0x4B:12,0x5C:8,0x79:5,0x9D:9}
check(dict(counts)==expected_counts, 'EHZ2 object ID/count distribution matches retail source exactly')
supported={0x03,0x06,0x0D,0x11,0x18,0x1C,0x26,0x36,0x41,0x49,0x4B,0x5C,0x79,0x9D}
check(sum(counts[x] for x in supported)==157 and counts[0x3E]==1, '157/158 placed EHZ2 records use implemented runtime classes; only Egg Prison $3E is deferred')
check('0x0D: return S2SignpostAdapterClass.new()' in manager and 'int(owner.level_definition.get("act", 1)) != 1' in adapter and 'request_delete(false)' in adapter,
      'retail Obj0D act guard deletes the shared signpost placement in single-player EHZ2')
check('0x3E' not in manager[manager.index('if bool(level_definition.get("experimental_sonic2", false)):'):manager.index('\tmatch id:', manager.index('if bool(level_definition.get("experimental_sonic2", false)):')+1)],
      'S2 Egg Prison does not fall through to the unrelated S1 namespace before its dedicated boss pass')
check(manifest['object_records']==158 and manifest['start']==[0x60,0x2AF] and manifest['limits']['right']==0x2940,
      'Phase 88 provenance manifest records the retail EHZ2 source geometry and limits')

# Previous verified baseline must stay intact.
r=subprocess.run([sys.executable,str(PROJECT/'tools/validate_phase87_hotfix1.py')],cwd=PROJECT,capture_output=True,text=True)
check(r.returncode==0,'Phase 87 Hotfix 1 and the complete chained regression baseline still pass')

# Optional byte-for-byte regeneration against the supplied retail checkout.
if len(sys.argv)>1:
    src=Path(sys.argv[1]).resolve()
    before={name:sha(DATA/name) for name in expected}
    rr=subprocess.run([sys.executable,str(PROJECT/'tools/import_s2_ehz2.py'),str(src)],cwd=PROJECT,capture_output=True,text=True)
    after={name:sha(DATA/name) for name in expected}
    check(rr.returncode==0 and before==after, 'Phase 88 importer regenerates all EHZ2 runtime data byte-for-byte from retail source')

passed=sum(ok for ok,_ in checks); total=len(checks)
text='\n'.join(('PASS' if ok else 'FAIL')+': '+msg for ok,msg in checks)+f'\n\n{passed}/{total} checks passed\n'
(PROJECT/'PHASE88_VALIDATION_RESULTS.txt').write_text(text)
print(f'\n{passed}/{total} checks passed')
if passed!=total: raise SystemExit(1)
