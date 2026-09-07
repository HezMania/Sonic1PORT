# Phase 3 horizontal camera bug correction

Source: `_inc/ScrollHoriz & ScrollVertical.asm`, routine `MoveScreenHoriz` / `SH_MoveCameraRight`.

The original sequence is conceptually:

```text
relative = sonic_x - screen_x
relative -= 144

if relative < 0:
	move left by max(relative, -16)
else:
	relative -= 16
	if relative >= 0:
		move right by min(relative, 16)
```

Phase 3 combined the two right-side tests but forgot the second subtraction. Its effective logic was:

```text
relative -= 144
if relative >= 16:
	move right by min(relative, 16)
```

At screen-relative X=160, `relative=16`; this incorrectly moved the camera by 16 px. At X=161 it also moved 16 px rather than 1 px.

Phase 4 subtracts the dead-zone width before applying the right cap:

```gdscript
elif d0 >= 16:
	d0 -= 16
	d0 = mini(d0, 16)
	_set_screen_x(screen_x + d0)
```

Representative results:

| Sonic screen-relative X | Camera movement |
|---:|---:|
| 143 | -1 px |
| 144 | 0 px |
| 160 | 0 px |
| 161 | +1 px |
| 168 | +8 px |
| 176 | +16 px |
| 200 | +16 px |

This restores the intended 144–160 horizontal sweet zone and symmetric fine tracking immediately outside it.
