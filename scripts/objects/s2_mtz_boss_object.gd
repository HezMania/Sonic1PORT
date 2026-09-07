class_name S2MTZBossObject
extends Node2D

# Phase 125: retail Sonic 2 Object $54 / $53 - Metropolis boss.
# The level event owns the $2AB0 arena lock and exact $5A ScreenShift wait.
# This node translates the 8-hit Eggpod, seven orbiting shield orbs, the
# post-shield laser sweep, $EF defeat countdown and $2BF0 camera release.

const ST_DESCEND := 0
const ST_PATROL := 1
const ST_CENTER := 2
const ST_ORBIT_EXPAND := 3
const ST_ORBIT_CONTRACT := 4
const ST_HIT_RISE := 5
const ST_HIT_RECOVER := 6
const ST_LASER := 7
const ST_DEFEAT := 8
const ST_ESCAPE := 9

const BOSS_START := Vector2i(0x2B50,0x380)
const FLOOR_Y := 0x4A0
const RISE_Y := 0x470
const HIT_RISE_Y := 0x420
const LEFT_X := 0x2AD0
const RIGHT_X := 0x2BD0
const CENTER_X := 0x2B50
const LASER_LEFT_X := 0x2AF0
const LASER_RIGHT_X := 0x2BB0
const CAMERA_END := 0x2BF0
const ORB_ANGLES: Array[int] = [0x24,0x6C,0xB4,0xFC,0x48,0x90,0xD8]

var manager: SonicObjectManager
var alive := true
var state := ST_DESCEND
var hits := 8
var invulnerable_timer := 0
var hit_face_timer := 0
var boss_x_fixed := BOSS_START.x << 16
var boss_y_fixed := BOSS_START.y << 16
var vel_x := 0
var vel_y := 0x100
var float_angle := 0x40
var side_flag := false
var display_flip := false
var edge_toggle := false
var orbit_radius_x := 0x27
var orbit_radius_y := 0x27
var orbit_hold := 0
var detached_alive := 0
var laser_phase := 0
var laser_pause := 0
var laser_countdown := 0
var lasers_remaining := 0
var defeat_timer := 0
var escape_started := false
var visual_tick := 0

var vehicle_sprite: Sprite2D
var face_sprite: Sprite2D
var jet_sprite: Sprite2D
var shooter_sprite: Sprite2D
var orbs: Array[Dictionary] = []
var lasers: Array[Dictionary] = []

func setup(owner: SonicObjectManager) -> void:
	manager = owner
	position = Vector2(BOSS_START)
	vehicle_sprite = _make_part(2,2)
	face_sprite = _make_part(0x0C,3)
	jet_sprite = _make_part(0,1)
	shooter_sprite = _make_part(0x13,4)
	shooter_sprite.visible = true
	for i in range(7):
		var s := _make_part(5,3)
		orbs.append({
			"sprite":s,"angle":ORB_ANGLES[i],"zangle":ORB_ANGLES[i],
			"detached":false,"alive":true,"xf":0,"yf":0,"vx":0,"vy":0,
			"timer":0,"anim":0,"landed":false,"bounce_phase":1,"face_right":false
		})
	_update_visuals()

func tick() -> void:
	if not alive or manager == null:
		return
	visual_tick += 1
	if invulnerable_timer > 0:
		invulnerable_timer -= 1
	if hit_face_timer > 0:
		hit_face_timer -= 1
	match state:
		ST_DESCEND: _tick_descend()
		ST_PATROL: _tick_patrol()
		ST_CENTER: _tick_center()
		ST_ORBIT_EXPAND: _tick_orbit_expand()
		ST_ORBIT_CONTRACT: _tick_orbit_contract()
		ST_HIT_RISE: _tick_hit_rise()
		ST_HIT_RECOVER: _tick_hit_recover()
		ST_LASER: _tick_laser_state()
		ST_DEFEAT: _tick_defeat()
		ST_ESCAPE: _tick_escape()
	_tick_orbs()
	_tick_lasers()
	_update_visuals()
	if state < ST_DEFEAT:
		_check_boss_collision()

func _move_boss() -> void:
	boss_x_fixed += GenesisMath.s16(vel_x) << 8
	boss_y_fixed += GenesisMath.s16(vel_y) << 8

func _boss_x() -> int: return boss_x_fixed >> 16
func _boss_y() -> int: return boss_y_fixed >> 16
func _display_y() -> int:
	var y := _boss_y()
	if state == ST_PATROL or state == ST_ORBIT_EXPAND or state == ST_ORBIT_CONTRACT or state == ST_HIT_RECOVER:
		y += GenesisMath.sine(float_angle & 0xFF) >> 6
	return y

func _tick_descend() -> void:
	_move_boss()
	if _boss_y() >= FLOOR_Y:
		boss_y_fixed = FLOOR_Y << 16
		vel_y = 0
		var p := manager.player
		side_flag = p != null and p.pixel_x() >= _boss_x()
		vel_x = 0x100 if side_flag else -0x100
		state = ST_PATROL

func _tick_patrol() -> void:
	_move_boss()
	float_angle = (float_angle + 4) & 0xFF
	if not side_flag and _boss_x() < LEFT_X:
		boss_x_fixed = LEFT_X << 16
		side_flag = true; vel_x = 0x100
		if edge_toggle:
			vel_y = -0x100; state = ST_CENTER
		edge_toggle = not edge_toggle
	elif side_flag and _boss_x() >= RIGHT_X:
		boss_x_fixed = RIGHT_X << 16
		side_flag = false; vel_x = -0x100
		if edge_toggle:
			vel_y = -0x100; state = ST_CENTER
		edge_toggle = not edge_toggle

func _tick_center() -> void:
	_move_boss()
	if _boss_y() < RISE_Y:
		boss_y_fixed = RISE_Y << 16; vel_y = 0
	if not side_flag and _boss_x() >= CENTER_X:
		boss_x_fixed = CENTER_X << 16; vel_x = 0
	elif side_flag and _boss_x() < CENTER_X:
		boss_x_fixed = CENTER_X << 16; vel_x = 0
	if vel_x == 0 and vel_y == 0:
		state = ST_ORBIT_EXPAND
		orbit_radius_x = 0x27; orbit_radius_y = 0x27; orbit_hold = 0

func _tick_orbit_expand() -> void:
	float_angle = (float_angle + 4) & 0xFF
	if orbit_radius_x < 0x68:
		orbit_radius_x += 1; orbit_radius_y += 1
	else:
		orbit_radius_y -= 1
		if orbit_radius_y <= 0:
			orbit_radius_y = 0; state = ST_ORBIT_CONTRACT

func _tick_orbit_contract() -> void:
	float_angle = (float_angle + 4) & 0xFF
	if orbit_radius_x >= 0x27:
		orbit_radius_x -= 1
	else:
		orbit_radius_y += 1
		if orbit_radius_y >= 0x27:
			orbit_radius_x = 0x27; orbit_radius_y = 0x27
			vel_y = 0x100; state = ST_DESCEND; edge_toggle = false

func _tick_hit_rise() -> void:
	# Obj54 MainSubA contracts the shield while rising to $420 and waits for the
	# detached Object $53 to be cleared before selecting the recovery/laser phase.
	if orbit_radius_y > 0: orbit_radius_y -= 1
	if orbit_radius_x >= 0x27: orbit_radius_x -= 1
	_move_boss()
	if _boss_y() < HIT_RISE_Y:
		boss_y_fixed = HIT_RISE_Y << 16; vel_y = 0
	if detached_alive <= 0:
		state = ST_HIT_RECOVER

func _tick_hit_recover() -> void:
	float_angle = (float_angle + 4) & 0xFF
	if _shield_count() > 0:
		if orbit_radius_y < 0x27:
			orbit_radius_y += 1
		else:
			vel_y = 0x100; state = ST_DESCEND; edge_toggle = false
		return
	# Seven shield hits have been consumed: Object $54 enters its laser state.
	vel_y = -0x180
	vel_x = 0x100 if side_flag else -0x100
	display_flip = side_flag
	laser_phase = 0; laser_pause = 0; lasers_remaining = 0
	state = ST_LASER

func _tick_laser_state() -> void:
	if laser_pause > 0:
		laser_pause -= 1
		return
	match laser_phase:
		0:
			_move_boss()
			if _boss_y() < HIT_RISE_Y:
				boss_y_fixed = HIT_RISE_Y << 16; vel_y = 0
			if (not side_flag and _boss_x() < LASER_LEFT_X) or (side_flag and _boss_x() >= LASER_RIGHT_X):
				laser_phase = 1; vel_y = 0x180; lasers_remaining = 3; laser_countdown = 0x1E
				# Obj54 changes only the visible facing here; bit 7 (side_flag) is
				# not toggled until the pod reaches the bottom of the shot pass.
				display_flip = not side_flag
		1:
			_move_boss()
			# Source keeps the small horizontal approach only until $2AD0/$2BD0,
			# then the firing descent is vertical.
			if (not side_flag and _boss_x() < LEFT_X) or (side_flag and _boss_x() >= RIGHT_X):
				vel_x = 0
			laser_countdown -= 1
			if laser_countdown <= 0 and lasers_remaining > 0:
				_spawn_laser(); lasers_remaining -= 1; laser_countdown = 0x1E; laser_pause = 0x10
			if _boss_y() >= FLOOR_Y:
				boss_y_fixed = FLOOR_Y << 16; vel_y = -0x180; laser_phase = 2
				side_flag = not side_flag
		2:
			_move_boss()
			laser_countdown -= 1
			if laser_countdown <= 0 and lasers_remaining > 0:
				_spawn_laser(); lasers_remaining -= 1; laser_countdown = 0x1E; laser_pause = 0x10
			if _boss_y() < RISE_Y:
				vel_x = 0x100 if side_flag else -0x100
			if _boss_y() < HIT_RISE_Y:
				boss_y_fixed = HIT_RISE_Y << 16; vel_y = 0; laser_phase = 0
				display_flip = side_flag

func _spawn_laser() -> void:
	# Obj54 laser: unflipped pod fires left (-$400), flipped pod fires right.
	var vx := 0x400 if display_flip else -0x400
	var x := _boss_x() + (4 if display_flip else -4)
	var y := _boss_y() + 7
	var s := _make_part(0x12,5)
	s.flip_h = vx > 0
	lasers.append({"sprite":s,"xf":x<<16,"y":y,"vx":vx})
	SonicAudio.play_sfx(SonicAudio.SFX_ELECTRIC)

func _tick_lasers() -> void:
	for i in range(lasers.size()-1,-1,-1):
		var l: Dictionary = lasers[i]
		l["xf"] = int(l["xf"]) + (GenesisMath.s16(int(l["vx"])) << 8)
		var x: int = int(l["xf"]) >> 16; var y: int = int(l["y"])
		var raw_sp = l.get("sprite")
		if raw_sp == null or not is_instance_valid(raw_sp):
			lasers.remove_at(i); continue
		var sp: Sprite2D = raw_sp
		sp.position = Vector2(x-_boss_x(),y-_display_y())
		if x < 0x2AB0 or x >= 0x2BF0:
			sp.queue_free(); lasers.remove_at(i); continue
		_check_hazard(x,y,0x18,6)
		lasers[i]=l

func _shield_count() -> int:
	var n := 0
	for o in orbs:
		if bool(o.get("alive",false)) and not bool(o.get("detached",false)): n += 1
	return n

func _detach_one_orb() -> void:
	for i in range(orbs.size()):
		var o: Dictionary = orbs[i]
		if not bool(o.get("alive",false)) or bool(o.get("detached",false)): continue
		var sp := o["sprite"] as Sprite2D
		var wx := _boss_x()+int(round(sp.position.x)); var wy := _display_y()+int(round(sp.position.y))
		o["detached"]=true; o["xf"]=wx<<16; o["yf"]=wy<<16; o["vy"]=-0x400
		var vx := -0x80 if manager.player != null and manager.player.pixel_x() >= wx else 0x80
		if wx < 0x2AF0: vx=0x80
		if wx >= 0x2BB0: vx=-0x80
		o["vx"]=vx; o["timer"]=0x3C; o["anim"]=0
		o["landed"]=false; o["bounce_phase"]=1; o["face_right"]=vx>0
		detached_alive += 1; orbs[i]=o; return

func _tick_orbs() -> void:
	for i in range(orbs.size()):
		var o: Dictionary = orbs[i]
		if not bool(o.get("alive",false)): continue
		var raw_sp = o.get("sprite")
		if raw_sp == null or not is_instance_valid(raw_sp):
			o["alive"] = false; orbs[i] = o; continue
		var sp: Sprite2D = raw_sp
		if not bool(o.get("detached",false)):
			var a: int = int(o["angle"]) & 0xFF
			var za: int = int(o["zangle"]) & 0xFF
			var ox: int = (GenesisMath.sine(a)*orbit_radius_x)>>8
			var oy: int = (GenesisMath.sine(za)*orbit_radius_y)>>8
			sp.position = Vector2(ox,oy-4)
			# Obj53 priority is inverse to Godot Z: source priority 1 is nearest,
			# source priority 7 is farthest. Depth is the actual X-radius cosine
			# value and uses retail +/-$0C thresholds.
			var depth: int = (GenesisMath.cosine(a) * orbit_radius_x) >> 8
			if depth >= 0x0C:
				_set_part(sp,3); sp.z_index=7
			elif depth >= 0:
				_set_part(sp,4); sp.z_index=6
			elif depth >= -0x0C:
				_set_part(sp,4); sp.z_index=2
			else:
				_set_part(sp,5); sp.z_index=1
			o["angle"]=(a+4)&0xFF; o["zangle"]=(za+8)&0xFF
			_check_hazard(_boss_x()+ox,_display_y()+oy-4,8,8)
		else:
			o["timer"]=int(o["timer"])-1; o["anim"]=int(o["anim"])+1
			# Retail Obj53's breakaway balloon advances into mapping frame $B and
			# holds that fully-inflated frame for its bounce/contact phase.
			var balloon_frame: int = mini(0x0B, 5 + (int(o["anim"]) >> 2))
			_set_part(sp,balloon_frame)
			var x: int
			var y: int
			if not bool(o.get("landed",false)):
				# Obj53_BreakAway = ObjectMoveAndFall followed by -$20 gravity, for
				# an effective +$18/frame, capped at +$180. Horizontal $80 motion
				# only exists during this falling/inflating phase.
				o["xf"] = int(o["xf"]) + (GenesisMath.s16(int(o["vx"]))<<8)
				o["yf"] = int(o["yf"]) + (GenesisMath.s16(int(o["vy"]))<<8)
				o["vy"] = mini(0x180,GenesisMath.s16(int(o["vy"])+0x18))
				x=int(o["xf"])>>16; y=int(o["yf"])>>16
				if y>=0x4AC:
					y=0x4AC; o["yf"]=y<<16; o["vx"]=0; o["vy"]=0
					o["landed"]=true; o["bounce_phase"]=1
					o["face_right"]=manager.player!=null and manager.player.pixel_x()>=x
			else:
				x=int(o["xf"])>>16; y=int(o["yf"])>>16
				# Obj53_BounceAround begins only after mapping frame $B. Its sine
				# phase starts at 1; every other phase moves one pixel toward Sonic,
				# then it re-faces Sonic each time the arc returns to floor $4AC.
				if balloon_frame==0x0B:
					var phase: int=int(o.get("bounce_phase",1))&0xFF
					var bounce_y: int=0x4AC-(GenesisMath.sine(phase)>>2)
					if bounce_y>=0x4AC:
						y=0x4AC; phase=1
						o["face_right"]=manager.player!=null and manager.player.pixel_x()>=x
					else:
						y=bounce_y; phase=(phase+1)&0xFF
						if (phase&1)!=0:
							if bool(o.get("face_right",false)):x+=1
							else:x-=1
					# The retail facing target is always the player inside the locked arena;
					# keep the translated object inside those same camera walls as a guard.
					x=clampi(x,0x2AB8,0x2BE8)
					o["xf"]=x<<16; o["yf"]=y<<16; o["bounce_phase"]=phase
			sp.position=Vector2(x-_boss_x(),y-_display_y())
			if int(o["timer"])<=0:
				if _player_attacks_point(x,y,0x10,0x10):
					_rebound_player_from_attack()
					manager.spawn_boss_explosion(x,y); sp.queue_free(); o["alive"]=false; detached_alive=maxi(0,detached_alive-1)
				else:_check_hazard(x,y,0x10,0x10)
		orbs[i]=o

func _player_attacks_point(x:int,y:int,hw:int,hh:int) -> bool:
	var p:=manager.player
	if p==null or p.dead: return false
	return p.can_attack_object() and absi(p.pixel_x()-x)<=hw+p.width_radius and absi(p.pixel_y()-y)<=hh+p.height_radius

func _rebound_player_from_attack() -> void:
	var p:=manager.player
	if p==null or p.dead:return
	p.vel_y = -maxi(0x200,absi(p.vel_y)) if p.vel_y>=0 else GenesisMath.s16(-p.vel_y)

func _check_boss_collision() -> void:
	var p:=manager.player
	if p==null or p.dead or p.hurt_state: return
	var bx:=_boss_x(); var by:=_display_y()
	if absi(p.pixel_x()-bx)>0x18+p.width_radius or absi(p.pixel_y()-by)>0x18+p.height_radius: return
	if p.can_attack_object():
		_rebound_player_from_attack()
		if invulnerable_timer>0: return
		hits -= 1; invulnerable_timer=0x40; hit_face_timer=0x20
		SonicAudio.play_sfx(SonicAudio.SFX_HIT_BOSS)
		if hits<=0: _begin_defeat(); return
		if _shield_count()>0:
			_detach_one_orb(); orbit_radius_y=maxi(0,orbit_radius_y-1); vel_x=0; vel_y=-0x180; state=ST_HIT_RISE
		return
	p.apply_hazard_hit(bx)

func _check_hazard(x:int,y:int,hw:int,hh:int) -> void:
	var p:=manager.player
	if p==null or p.dead or p.hurt_state:return
	if absi(p.pixel_x()-x)<=hw+p.width_radius and absi(p.pixel_y()-y)<=hh+p.height_radius:
		p.apply_hazard_hit(x)

func _begin_defeat() -> void:
	if state>=ST_DEFEAT:return
	state=ST_DEFEAT; defeat_timer=0xEF; vel_x=0; vel_y=0
	manager.add_score(1000)
	for o in orbs:
		var raw_sp=o.get("sprite")
		if raw_sp!=null and is_instance_valid(raw_sp):
			var sp: Sprite2D=raw_sp; sp.visible=false
	for l in lasers:
		var raw_sp2=l.get("sprite")
		if raw_sp2!=null and is_instance_valid(raw_sp2):
			var sp2: Sprite2D=raw_sp2; sp2.queue_free()
	lasers.clear()
	shooter_sprite.visible=false

func _tick_defeat() -> void:
	defeat_timer -= 1
	if defeat_timer >= 0:
		if defeat_timer>=0x3C and (visual_tick&7)==0:
			manager.spawn_boss_explosion(_boss_x()+((manager.next_random_word()&0x3F)-0x20),_boss_y()+(((manager.next_random_word()>>3)&0x3F)-0x20))
		return
	state=ST_ESCAPE; escape_started=true; side_flag=true
	SonicAudio.play_music(SonicAudio.MUS_S2_MTZ,true)

func _tick_escape() -> void:
	vel_x=0x400; vel_y=-0x40; _move_boss(); float_angle=(float_angle+2)&0xFF
	manager.unlock_s2_mtz_boss_right_boundary()
	if manager.boss_limit_right>=CAMERA_END and _boss_x()>CAMERA_END+0x100:
		manager.set_boss_defeated(); alive=false; queue_free()

func _update_visuals() -> void:
	var bx:=_boss_x(); var by:=_display_y(); position=Vector2(bx,by)
	var flip: bool = display_flip if state == ST_LASER else side_flag
	vehicle_sprite.position=Vector2.ZERO; vehicle_sprite.flip_h=flip
	face_sprite.position=Vector2.ZERO; face_sprite.flip_h=flip
	jet_sprite.position=Vector2.ZERO; jet_sprite.flip_h=flip
	shooter_sprite.position=Vector2.ZERO; shooter_sprite.flip_h=flip
	_set_part(vehicle_sprite,2)
	_set_part(jet_sprite,1 if (visual_tick&4)!=0 else 0)
	if state==ST_DEFEAT or state==ST_ESCAPE:
		_set_part(face_sprite,0x11 if state==ST_ESCAPE else (0x10 if (visual_tick&8)!=0 else 0x0F))
	else:
		_set_part(face_sprite,0x0E if hit_face_timer>0 else 0x0C)
	var alpha: float = 0.45 if invulnerable_timer>0 and (visual_tick&2)==0 else 1.0
	var vc: Color=vehicle_sprite.modulate; vc.a=alpha; vehicle_sprite.modulate=vc
	var fc: Color=face_sprite.modulate; fc.a=alpha; face_sprite.modulate=fc
	var jc: Color=jet_sprite.modulate; jc.a=alpha; jet_sprite.modulate=jc
	# Child world positions were stored relative to the previous boss position.
	# Rebase transient sprites after position changes without touching their world data.
	for l in lasers:
		var raw_sp=l.get("sprite")
		if raw_sp!=null and is_instance_valid(raw_sp):
			var sp: Sprite2D=raw_sp
			sp.position=Vector2((int(l.get("xf",0))>>16)-bx,int(l.get("y",0))-by)

func _make_part(frame:int,z:int) -> Sprite2D:
	var s:=Sprite2D.new(); s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; s.centered=true; s.z_index=z; add_child(s); _set_part(s,frame); return s

func _set_part(s:Sprite2D,frame:int) -> void:
	if s==null:return
	var path: String="res://assets/objects/s2_mtz/boss/parts/%02d.png"%frame
	if ResourceLoader.exists(path):s.texture=load(path)
