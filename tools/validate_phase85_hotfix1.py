from pathlib import Path
import subprocess, sys
root = Path(__file__).resolve().parents[1]
main = (root/'scripts/main.gd').read_text()
player = (root/'scripts/player/sonic_player.gd').read_text()
checks=[]
def check(name, ok):
    checks.append(ok)
    print(('PASS' if ok else 'FAIL') + ': ' + name)
check('authoritative S2 bottom-death check runs in main loop', 'Phase 85 Hotfix 1: keep the Sonic 2 bottom-death test at the level-loop' in main)
check('check is immediately downstream of player simulation', 'player.simulate_tick()\n\n\t# Phase 85 Hotfix 1' in main)
check('check uses live camera bottom plus dynamic viewport height', 'sonic_camera.current_bottom + int(ProjectSettings.get_setting("display/window/size/viewport_height"))' in main)
check('check is scoped to experimental Sonic 2 levels', 'bool(level.definition.get("experimental_sonic2", false))' in main)
check('debug/dead/drowning states are guarded', 'not player.dead and not player.drowning and not player.debug_free_mode' in main)
check('crossing the boundary calls the normal kill routine', 'if player.pixel_y() > s2_bottom_death_y:\n\t\t\tplayer.kill()' in main)
check('player-side normal boundary check remains as an early-path backup', 'bottom_death_y = int(level.definition.get("limit_bottom", bottom_death_y)) + int(ProjectSettings.get_setting("display/window/size/viewport_height"))' in player)
# Re-run the previous phase regression suite.
proc = subprocess.run([sys.executable, str(root/'tools/validate_phase85.py')], cwd=root, text=True, capture_output=True)
print(proc.stdout.rstrip())
if proc.returncode != 0:
    print(proc.stderr.rstrip())
check('Phase 85 regressions still pass', proc.returncode == 0)
print(f'\n{sum(checks)}/{len(checks)} checks passed')
sys.exit(0 if all(checks) else 1)
