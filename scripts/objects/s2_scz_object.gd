class_name S2SCZObject
extends GenesisLevelObject

# Phase 126: zone-local adapters for Sky Chase's six authored object families.
# Their numeric IDs overlap unrelated zones, so SCZ routes them explicitly.

# ObjB2_Animate_Pilot / Tails_pilot_frames. Values are remapped by the importer
# to the five 24x16 pilot images used by the Tornado mapping piece.
const TAILS_PILOT_SEQUENCE: Array[int] = [
	0,0,0,0, 1,2,3,2,1,1,
	0,0,0,0, 1,2,3,2,1,1,
	4,4,1,1,
]

var sprite: Sprite2D
var rider: Sprite2D
var pilot: Sprite2D
var state := 0
var timer := 0
var frame_counter := 0
var vx := 0
var vy := 0
var fixed_x := 0
var fixed_y := 0
var projectiles: Array[Dictionary] = []
var plane_y_fixed := 0
var rider_destroyed := false

func initialize_object() -> void:
	fixed_x = spawn_x << 16; fixed_y = spawn_y << 16; plane_y_fixed = fixed_y
	match object_id:
		0xB2: _init_tornado()
		0xB3: _init_cloud()
		0xB4: _init_vprop()
		0xB5: _init_hprop()
		0xAC: _init_balkiry()
		0x99: _init_nebula()
		0x9A: _init_turtloid()

func tick() -> void:
	if not alive:return
	frame_counter += 1
	match object_id:
		0xB2: _tick_tornado()
		0xB3: _tick_cloud()
		0xB4: _tick_vprop()
		0xB5: _tick_hprop()
		0xAC: _tick_balkiry()
		0x99: _tick_nebula()
		0x9A: _tick_turtloid()
	_tick_projectiles()

func suppress_central_despawn() -> bool:
	return object_id == 0xB2

func central_despawn_x() -> int:
	return int(position.x) if object_id in [0x99,0x9A,0xAC,0xB3] else spawn_x

func _new_sprite(folder:String, frame:int, z:int=2) -> Sprite2D:
	var s:=Sprite2D.new(); s.centered=true; s.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; s.z_index=z; add_child(s); _set_frame(s,folder,frame); return s

func _set_frame(s:Sprite2D,folder:String,frame:int) -> void:
	if s==null:return
	var path:="res://assets/objects/s2_scz/%s/%02d.png"%[folder,frame]
	if ResourceLoader.exists(path):s.texture=load(path)

func _player_overlap(x:int,y:int,hw:int,hh:int) -> bool:
	var p:=player(); if p==null or p.dead:return false
	return absi(p.pixel_x()-x)<=hw+p.width_radius and absi(p.pixel_y()-y)<=hh+p.height_radius

func _badnik_contact(x:int,y:int,hw:int,hh:int) -> bool:
	var p:=player(); if p==null or p.dead:return false
	if not _player_overlap(x,y,hw,hh):return false
	if p.can_attack_object():
		# Retail enemy collision only applies the enemy-bounce when Sonic is
		# descending. An upward hit (notably Balkiry from below) keeps its rise.
		if p.vel_y >= 0:
			p.vel_y=-maxi(0x200,absi(p.vel_y))
		manager.spawn_badnik_destruction(x,y,0); manager.add_score(100); request_delete(respawn_enabled); return true
	p.apply_hazard_hit(x); return false

func _hazard(x:int,y:int,hw:int,hh:int) -> void:
	var p:=player(); if p==null or p.dead or p.hurt_state:return
	if _player_overlap(x,y,hw,hh):p.apply_hazard_hit(x)

# Object $B2 - Tornado. The source makes the plane a $1B x 9 solid platform,
# follows Sonic horizontally, lets Up/Down steer it vertically while ridden,
# and owns the SCZ forced-right finish after Camera_X reaches $1400.
func _init_tornado() -> void:
	active_width=0x1B
	sprite=_new_sprite("tornado",0,2); sprite.flip_h=x_flip
	# ObjB2's mapping has a 3x2 dynamic-VRAM Tails piece at (-$30,-8).
	# Phase126 left that bank transparent; Hotfix1 reconstructs the exact first
	# DPLC packet for the pilot frames and overlays it at the mapping location.
	pilot=_new_sprite("pilot",0,4); pilot.position=Vector2(-36,0)

func _clamp_scz_player_to_camera(p:SonicPlayer) -> void:
	var cam_x:=manager.current_screen_x
	var vw:=int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var px:=p.pixel_x()
	var nx:=maxi(px,cam_x+0x11)
	# ObjB2 constrains Sonic horizontally relative to Camera_X. Retail SCZ does
	# NOT clamp Sonic to the visible camera corridor vertically; only the Tornado
	# itself is constrained to Camera_Y+$34..+$A8 by ObjB2_Vertical_limit.
	if cam_x < 0x1400:
		nx=mini(nx,cam_x+vw-0x11)
	if nx!=px:
		p.force_set_pixel_position(nx,p.pixel_y())

func _tick_tornado() -> void:
	var p:=player(); if p==null:return
	var old_y:=int(round(position.y))
	var standing:=p.standing_on_object and p.support_record_index==record_index
	# loc_36776: the Tornado participates in the same world displacement as the
	# auto-scrolling camera. Without the +1 Y leg, Down could never catch the
	# descending camera and the plane drifted toward the top of the viewport.
	plane_y_fixed += manager.s2_scz_scroll_vy << 16
	if standing:
		var steer:=0
		if p.input_up and not p.input_down:steer=-0x80
		elif p.input_down and not p.input_up:steer=0x80
		plane_y_fixed += steer << 8
	var cam_y:=manager.current_screen_y
	plane_y_fixed=clampi(plane_y_fixed,(cam_y+0x34)<<16,(cam_y+0xA8)<<16)
	_clamp_scz_player_to_camera(p)
	# Source follows Sonic horizontally while he rides the Tornado. Clamp that
	# follow point to the visible camera corridor during normal SCZ flight.
	var cam_x:=manager.current_screen_x
	var vw:=int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var plane_x:=p.pixel_x()
	if cam_x < 0x1400:
		plane_x=clampi(plane_x,cam_x+0x11,cam_x+vw-0x11)
	else:
		plane_x=maxi(plane_x,cam_x+0x11)
	position.x=plane_x
	position.y=float(plane_y_fixed)/65536.0
	var ny:=int(round(position.y)); var nx:=int(round(position.x))
	if standing:p.move_with_supported_object(record_index,0,ny-old_y,nx-0x1B,nx+0x1B,ny-9)
	p.resolve_solid_box_contact(nx,ny,0x1B,9,true,record_index)
	_clamp_scz_player_to_camera(p)
	_set_frame(sprite,"tornado",(frame_counter>>2)&3)
	if pilot!=null:
		# objoff_37 starts at zero, so ObjB2_Animate_Pilot loads entry 1 on its
		# first call and advances every nine frames thereafter.
		var pilot_step: int=(1+int((frame_counter-1)/9))%TAILS_PILOT_SEQUENCE.size()
		_set_frame(pilot,"pilot",TAILS_PILOT_SEQUENCE[pilot_step])
	# ObjB2 forces Right after the auto-scroll stops, then hands off to WFZ at $1568.
	if manager.current_screen_x>=0x1400:
		if p.pixel_x()<0x1568:
			p.control_locked=true; p.control_lock_direction=1; p.input_right=true; p.input_left=false
		else:
			p.control_locked=false; p.control_lock_direction=0
			manager.request_level_transition(LevelCatalog.ZONE_S2_WFZ_TEST,1)

# Object $B3 - three cloud speeds selected by subtype $5E/$60/$62.
func _init_cloud() -> void:
	var i:=clampi((subtype-0x5E)>>1,0,2); vx=[-0x80,-0x40,-0x20][i]; sprite=_new_sprite("cloud",i,-1)
func _tick_cloud() -> void:
	# ObjB3 adds Tornado_Velocity_X only after ObjectMove.
	fixed_x += vx<<8; fixed_x += manager.s2_scz_scroll_vx<<16
	position.x=float(fixed_x)/65536.0

func _init_vprop() -> void:
	sprite=_new_sprite("vprop",0,2); sprite.flip_h=x_flip
func _tick_vprop() -> void:
	_set_frame(sprite,"vprop",(frame_counter>>1)%3)
	# SCZ's placed vertical propeller has render bit 1 set and source clears collision.
	if not y_flip:_hazard(int(position.x),int(position.y),8,0x20)

func _init_hprop() -> void:
	sprite=_new_sprite("hprop",0,2); sprite.flip_h=x_flip
func _tick_hprop() -> void:
	_set_frame(sprite,"hprop",(frame_counter>>1)%6)
	# Subtype $68 selects ObjB5 routine 4 in SCZ: animation only, no player force.

func _init_balkiry() -> void:
	# ObjAC consumes render bit 1 (the placement Y-flip bit) as its fast-speed
	# flag, clears it, and uses -$500 instead of -$300. It is not a visual flip.
	vx=-0x500 if y_flip else -0x300; sprite=_new_sprite("balkiry",1,3); sprite.flip_h=x_flip
func _tick_balkiry() -> void:
	fixed_x+=vx<<8
	fixed_x+=manager.s2_scz_scroll_vx<<16; fixed_y+=manager.s2_scz_scroll_vy<<16
	position=Vector2(float(fixed_x)/65536.0,float(fixed_y)/65536.0)
	_set_frame(sprite,"balkiry",(frame_counter>>2)&1); _badnik_contact(int(position.x),int(position.y),0x18,0x10)

func _init_nebula() -> void:
	vx=-0xC0; sprite=_new_sprite("nebula",0,3); sprite.flip_h=x_flip
func _tick_nebula() -> void:
	var p:=player(); if p==null:return
	if state==0 and absi(p.pixel_x()-int(position.x))<0x80:
		state=1; vy=-0xA0
	if state==1:
		vy=mini(0x180,vy+1)
		if timer==0 and absi(p.pixel_x()-int(position.x))<0x10:
			timer=1; _spawn_nebula_bomb()
	fixed_x+=vx<<8; fixed_y+=vy<<8
	# loc_36776 keeps SCZ badnik world motion synchronized to Tornado scroll.
	fixed_x+=manager.s2_scz_scroll_vx<<16; fixed_y+=manager.s2_scz_scroll_vy<<16
	position=Vector2(float(fixed_x)/65536.0,float(fixed_y)/65536.0)
	_set_frame(sprite,"nebula",(frame_counter>>2)&3); _badnik_contact(int(position.x),int(position.y),0x10,8)

func _spawn_nebula_bomb() -> void:
	var s:=_new_sprite("nebula",4,2); var x:=int(position.x);var y:=int(position.y)+0x18
	s.position=Vector2(0,0x18); projectiles.append({"kind":0,"sprite":s,"xf":x<<16,"yf":y<<16,"vx":0,"vy":0})

func _init_turtloid() -> void:
	vx=-0x80; sprite=_new_sprite("turtloid",0,3); rider=_new_sprite("turtloid",2,4); rider.position=Vector2(4,-0x18)
	rider_destroyed=false

func _turtloid_rider_contact() -> void:
	if rider_destroyed or rider==null:return
	var p:=player(); if p==null or p.dead:return
	var x:=int(position.x)+4; var y:=int(position.y)-0x18
	if not _player_overlap(x,y,0x0C,0x0C):return
	if p.can_attack_object():
		if p.vel_y>=0:p.vel_y=-maxi(0x200,absi(p.vel_y))
		manager.spawn_badnik_destruction(x,y,0); manager.add_score(100)
		rider_destroyed=true; rider.queue_free(); rider=null
		# Obj9A itself has collision_flags=0 and survives when its Obj9B rider
		# is destroyed. Resume its harmless leftward platform motion.
		state=4; vx=-0x80; _set_frame(sprite,"turtloid",0)
	else:
		p.apply_hazard_hit(x)

func _tick_turtloid() -> void:
	var p:=player(); if p==null:return
	# Obj9A's state routine executes before ObjectMove/loc_36776 every frame.
	if not rider_destroyed:
		if state==0:
			if p.pixel_x()<int(position.x) and int(position.x)-p.pixel_x()<0x80:
				state=1;timer=4;vx=0;_set_frame(sprite,"turtloid",1)
		elif state==1:
			timer-=1
			if timer<0:state=2;timer=8;_set_frame(rider,"turtloid",3)
		elif state==2:
			timer-=1
			if timer<0:
				_spawn_turtloid_shot();state=3;timer=8
		elif state==3:
			timer-=1
			if timer<0:state=4;vx=-0x80;_set_frame(sprite,"turtloid",0);_set_frame(rider,"turtloid",2)
	var old_x:=int(round(position.x)); var old_y:=int(round(position.y))
	var standing:=p.standing_on_object and p.support_record_index==record_index
	fixed_x+=vx<<8
	fixed_x+=manager.s2_scz_scroll_vx<<16; fixed_y+=manager.s2_scz_scroll_vy<<16
	position=Vector2(float(fixed_x)/65536.0,float(fixed_y)/65536.0)
	var nx:=int(round(position.x)); var ny:=int(round(position.y))
	# Retail Obj9A passes its saved old X in d4 to PlatformObject. Preserve the
	# same old->new displacement so Sonic remains attached to the moving shell.
	if standing:
		p.move_with_supported_object(record_index,nx-old_x,ny-old_y,nx-0x18,nx+0x18,ny-0x0E)
	# Only separate Obj9B is a badnik; the turtle is a $18 x $0E ride platform.
	p.resolve_solid_box_contact(nx,ny,0x18,0x0E,true,record_index)
	_turtloid_rider_contact()

func _spawn_turtloid_shot() -> void:
	var s:=_new_sprite("turtloid",4,2);var x:=int(position.x)-0x14;var y:=int(position.y)+0x0A
	s.position=Vector2(-0x14,0x0A);projectiles.append({"kind":1,"sprite":s,"xf":x<<16,"yf":y<<16,"vx":-0x100,"vy":0,"anim":0})

func _tick_projectiles() -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var q:=projectiles[i]; var raw=q.get("sprite")
		if raw==null or not is_instance_valid(raw):projectiles.remove_at(i);continue
		var s:Sprite2D=raw
		if int(q["kind"])==0:q["vy"]=mini(0x400,int(q["vy"])+0x18)
		q["xf"]=int(q["xf"])+(GenesisMath.s16(int(q["vx"]))<<8);q["yf"]=int(q["yf"])+(GenesisMath.s16(int(q["vy"]))<<8)
		var x:=int(q["xf"])>>16;var y:=int(q["yf"])>>16;s.position=Vector2(x-position.x,y-position.y)
		if int(q["kind"])==1:
			q["anim"]=int(q.get("anim",0))+1;_set_frame(s,"turtloid",4+((int(q["anim"])>>1)&1))
		_hazard(x,y,8,8)
		if x<manager.current_screen_x-0x80 or y>manager.current_screen_y+0x300:s.queue_free();projectiles.remove_at(i);continue
		projectiles[i]=q
