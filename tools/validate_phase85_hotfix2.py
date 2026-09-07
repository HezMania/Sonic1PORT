from pathlib import Path
import subprocess, sys
root = Path(__file__).resolve().parents[1]
main = (root/'scripts/main.gd').read_text()
player = (root/'scripts/player/sonic_player.gd').read_text()
visual = (root/'scripts/player/sonic_visual.gd').read_text()
catalog = (root/'scripts/data/level_catalog.gd').read_text()
checks=[]
def check(name, ok):
    checks.append(bool(ok)); print(('PASS' if ok else 'FAIL') + ': ' + name)
check('authoritative Sonic 1 bottom-death check runs in main loop', 'Phase 85 Hotfix 2: Sonic 1 Sonic_LevelBound uses the live lower camera' in main)
check('S1 check uses target/current lower-boundary maximum plus dynamic viewport height', 'maxi(sonic_camera.target_bottom, sonic_camera.current_bottom) + int(ProjectSettings.get_setting("display/window/size/viewport_height"))' in main)
check('S1 check excludes experimental Sonic 2 levels', 'not bool(level.definition.get("experimental_sonic2", false))' in main)
check('S1 check guards dead/drowning/debug states', 'not player.dead and not player.drowning and not player.debug_free_mode' in main)
check('crossing the S1 bottom boundary enters normal kill routine', 'if player.pixel_y() > s1_bottom_death_y:\n' in main and '\t\t\tplayer.kill()' in main)
check('late SBZ2 boundary retains hidden LZ4 transition', 'if sbz2_transition_act and player.pixel_x() >= 0x2000:' in main and '_load_level(LevelCatalog.ZONE_LZ, 4, true)' in main)
check('Sonic kill routine applies source -$700 death launch', 'vel_y = -0x700' in player and 'dead = true' in player and 'vel_x = 0' in player and 'inertia = 0' in player)
check('S1 visual controller selects death frame while dead', 'if player.dead:\n\t\tmode = 5' in visual and '_set_s1_static(FRAME_DEATH, player)' in visual)
check('SBZ1 retains source initial lower boundary $720', 'd["limit_bottom"] = [0x720, 0x800][act - 1]' in catalog)
# Hotfix 1 + Phase 85 suites must remain green.
proc = subprocess.run([sys.executable, str(root/'tools/validate_phase85_hotfix1.py')], cwd=root, text=True, capture_output=True)
print(proc.stdout.rstrip())
if proc.returncode != 0: print(proc.stderr.rstrip())
check('Phase 85 Hotfix 1 and earlier regressions still pass', proc.returncode == 0)
print(f'\n{sum(checks)}/{len(checks)} checks passed')
sys.exit(0 if all(checks) else 1)
