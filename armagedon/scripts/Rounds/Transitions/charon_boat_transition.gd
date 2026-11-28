class_name CharonBoatTransition
extends CircleTransition
## C. Barca de Caronte: al romper el sello se abre en el muro oeste un paso de niebla con el
## farol de Caronte; al cruzarlo, el jugador va de pie en su barca por un río negro entre
## columnas de roca. Caronte rema, salen brazos y almas del agua (se les puede disparar), el
## nombre del círculo asoma en la niebla y suena la campana. En la orilla, un arco de luz lo
## devuelve a la arena del nuevo círculo por el mismo paso. Se puede mirar y disparar.

## Paso de niebla en el muro oeste (lejos del sur de la escalera y de la AgujaTrono del norte).
const MIST_X: float = -24.6
const MIST_WIDTH: float = 3.4
const MIST_HEIGHT: float = 4.4
const MIST_TRIGGER_X: float = -23.7
## Río de bolsillo, lejos de la arena y a la misma altura (no activa la caída al vacío).
const POCKET: Vector3 = Vector3(5000.0, 0.0, 0.0)
const RIVER_LENGTH: float = 120.0
const RIVER_WIDTH: float = 26.0
const DECK_HEIGHT: float = 0.6
const SWAY_DEGREES: float = 2.5
const STROKE_SECONDS: float = 1.6
const RIVER_SHADER: Shader = preload("res://assets/shaders/river.gdshader")
const SFX_OAR: AudioStream = preload("res://assets/audio/sfx/transitions/SFX_Water_Oar.ogg")

var _mist: Node3D
var _river: Node3D
var _boat: AnimatableBody3D
var _oar: Node3D
## Parte visual de la barca (casco, Caronte, farol): se balancea; el cuerpo físico no.
var _hull: Node3D
var _wood: StandardMaterial3D
var _robe: StandardMaterial3D
## Mientras va en la barca, el jugador se mantiene en su sitio respecto a ella (la física de la
## plataforma móvil no lo arrastra en horizontal y se caía por la popa).
var _riding: bool = false
var _ride_offset: Vector3 = Vector3(0.0, 0.0, 1.9)


func prepare() -> void:
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.24, 0.15, 0.08)
	_wood.roughness = 1.0
	_robe = StandardMaterial3D.new()
	_robe.albedo_color = Color(0.05, 0.045, 0.05)
	_robe.roughness = 1.0
	_build_mist_passage()


func get_seal_position() -> Vector3:
	return Vector3(MIST_X + 4.0, 0.0, 0.0)


func play() -> void:
	ctx.suspend_fall_respawn(true)
	if not await _enter_mist():
		return
	if not await _cross_river():
		return
	await _step_out()


## El paso de niebla se abre y el jugador lo cruza él mismo (o sigue solo tras max_wait_seconds).
func _enter_mist() -> bool:
	var open: Tween = create_tween()
	open.tween_property(_mist, "scale", Vector3.ONE, 1.2).set_trans(Tween.TRANS_BACK)
	play_sfx(SFX_SOUL, -14.0)
	await open.finished
	var waited: float = 0.0
	while alive() and waited < cfg.max_wait_seconds:
		var pos: Vector3 = ctx.player.global_position
		if pos.x <= MIST_TRIGGER_X and absf(pos.z) <= MIST_WIDTH * 0.5:
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not alive():
		return false
	await ctx.fade(Color(0.05, 0.08, 0.08), 1.0, 0.5)
	return alive()


## Río: el jugador de pie en la barca; Caronte rema, salen brazos y almas, campana y nombre.
func _cross_river() -> bool:
	ctx.lock_movement(true)
	_build_river()
	_build_boat()
	ctx.teleport_player(_boat.global_position + Vector3(0.0, DECK_HEIGHT + 0.3, 1.9), 0.0)
	_riding = true
	await ctx.fade(Color(0.05, 0.08, 0.08), 0.0, 0.8)
	if not alive():
		return false
	var travel: float = maxf(cfg.travel_seconds, 4.0)
	var move: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var end: Vector3 = _boat.global_position + Vector3.FORWARD * (RIVER_LENGTH - 30.0)
	move.tween_property(_boat, "global_position", end, travel).set_trans(Tween.TRANS_SINE)
	# Balanceo solo del casco visual: girar el cuerpo físico con otro tween lo dejaba quieto.
	var sway: Tween = _hull.create_tween().set_loops()
	sway.tween_property(_hull, "rotation:z", deg_to_rad(SWAY_DEGREES), 1.7).set_trans(
		Tween.TRANS_SINE
	)
	sway.tween_property(_hull, "rotation:z", deg_to_rad(-SWAY_DEGREES), 1.7).set_trans(
		Tween.TRANS_SINE
	)
	_row_loop()
	_spawn_river_events(travel)
	if not await wait(travel):
		return false
	await ctx.fade(Color(1.0, 0.9, 0.7), 1.0, 0.6)
	return alive()


## De vuelta en la arena (ya en el nuevo círculo), saliendo del paso de niebla, que se cierra.
func _step_out() -> void:
	_riding = false
	ctx.swap_circle(false)
	_river.queue_free()
	ctx.lock_movement(false)
	ctx.teleport_player(Vector3(MIST_X + 2.2, 0.3, 0.0), -PI * 0.5)
	await ctx.fade(Color(1.0, 0.9, 0.7), 0.0, 0.9)
	if not alive():
		return
	ctx.show_banner_now()
	ctx.suspend_fall_respawn(false)
	var close: Tween = create_tween()
	close.tween_property(_mist, "scale", Vector3(0.01, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE)
	await close.finished


func _physics_process(_delta: float) -> void:
	if not _riding or not is_instance_valid(_boat):
		return
	var player: Player = ctx.player
	var anchor: Vector3 = _boat.global_transform * _ride_offset
	var deck_y: float = _boat.global_position.y + DECK_HEIGHT
	player.global_position.x = anchor.x
	player.global_position.z = anchor.z
	if player.global_position.y < deck_y - 0.2:
		player.global_position.y = deck_y + 0.05
		player.velocity.y = 0.0


func cancel() -> void:
	_riding = false
	super.cancel()
	if ctx != null and ctx.game_flow != null:
		ctx.game_flow.call("fade_screen", Color.BLACK, 0.0, 0.2)


## Arco de niebla verdosa con el farol de Caronte colgando y una luz fría.
func _build_mist_passage() -> void:
	_mist = Node3D.new()
	add_child(_mist)
	_mist.global_position = Vector3(MIST_X, 0.0, 0.0)
	_mist.rotation.y = -PI * 0.5  # el frente (+Z) mira al centro de la arena (+X)
	_mist.scale = Vector3(0.01, 1.0, 1.0)
	var veil := MeshInstance3D.new()
	var veil_mesh := QuadMesh.new()
	veil_mesh.size = Vector2(MIST_WIDTH, MIST_HEIGHT)
	veil.mesh = veil_mesh
	veil.material_override = make_unshaded(Color(0.35, 0.6, 0.55, 0.55), true)
	veil.position = Vector3(0.0, MIST_HEIGHT * 0.5, -0.1)
	_mist.add_child(veil)
	var core := MeshInstance3D.new()
	var core_mesh := QuadMesh.new()
	core_mesh.size = Vector2(MIST_WIDTH * 0.7, MIST_HEIGHT * 0.85)
	core.mesh = core_mesh
	core.material_override = make_unshaded(Color(0.02, 0.05, 0.05))
	core.position = Vector3(0.0, MIST_HEIGHT * 0.45, -0.15)
	_mist.add_child(core)
	for i in 8:
		var wisp := make_sprite(SPRITE_DUST, 0.06, _mist)
		wisp.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		wisp.modulate = Color(0.5, 0.85, 0.8, 0.45)
		wisp.position = Vector3(randf_range(-1.6, 1.6), randf_range(0.3, 3.8), 0.1)
		var drift: Tween = wisp.create_tween().set_loops()
		drift.tween_property(wisp, "position:x", 0.6, randf_range(1.5, 2.5)).as_relative()
		drift.tween_property(wisp, "position:x", -0.6, randf_range(1.5, 2.5)).as_relative()
	var lantern := _make_lantern()
	lantern.position = Vector3(MIST_WIDTH * 0.5 + 0.3, 3.2, 0.3)
	_mist.add_child(lantern)


## Farol de Caronte: caja con luz verdosa que oscila.
func _make_lantern() -> Node3D:
	var lantern := Node3D.new()
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.22, 0.32, 0.22)
	box.mesh = box_mesh
	box.material_override = make_unshaded(Color(0.75, 1.0, 0.55))
	lantern.add_child(box)
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 1.0, 0.55)
	light.light_energy = 2.2
	light.omni_range = 8.0
	lantern.add_child(light)
	var swing: Tween = lantern.create_tween().set_loops()
	swing.tween_property(lantern, "rotation:z", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
	swing.tween_property(lantern, "rotation:z", -0.25, 1.1).set_trans(Tween.TRANS_SINE)
	return lantern


## Río de bolsillo: agua negra, columnas de roca en ambas orillas y la orilla final con un arco
## de luz.
func _build_river() -> void:
	_river = Node3D.new()
	add_child(_river)
	_river.global_position = POCKET
	var water := MeshInstance3D.new()
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(RIVER_WIDTH * 3.0, RIVER_LENGTH)
	water.mesh = water_mesh
	var water_mat := ShaderMaterial.new()
	water_mat.shader = RIVER_SHADER
	water.material_override = water_mat
	water.position = Vector3(0.0, 0.0, -RIVER_LENGTH * 0.5 + 10.0)
	_river.add_child(water)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.12, 0.1, 0.09)
	rock_mat.roughness = 1.0
	var z: float = 6.0
	while z > -RIVER_LENGTH + 8.0:
		for side in [-1.0, 1.0]:
			var rock := MeshInstance3D.new()
			var rock_mesh := BoxMesh.new()
			var h: float = randf_range(5.0, 16.0)
			rock_mesh.size = Vector3(randf_range(1.5, 4.0), h, randf_range(1.5, 4.0))
			rock.mesh = rock_mesh
			rock.material_override = rock_mat
			rock.position = Vector3(
				side * randf_range(RIVER_WIDTH * 0.35, RIVER_WIDTH * 0.6), h * 0.5 - 1.0, z
			)
			rock.rotation = Vector3(randf_range(-0.1, 0.1), randf() * TAU, randf_range(-0.12, 0.12))
			_river.add_child(rock)
			if randf() < 0.3:
				var skull := WallLurker.new()
				skull.outward = Vector3(-side, 0.0, 0.0)
				skull.trigger_distance = 7.0
				skull.lunge_distance = 0.8
				skull.position = rock.position + Vector3(-side * 1.4, randf_range(-1.0, 2.0), 0.0)
				_river.add_child(skull)
		z -= randf_range(5.0, 9.0)
	var shore_z: float = -RIVER_LENGTH + 18.0
	var arch := MeshInstance3D.new()
	var arch_mesh := QuadMesh.new()
	arch_mesh.size = Vector2(5.0, 6.0)
	arch.mesh = arch_mesh
	arch.material_override = make_unshaded(Color(1.0, 0.88, 0.65, 0.9), true)
	arch.position = Vector3(0.0, 3.0, shore_z - 4.0)
	_river.add_child(arch)
	var arch_light := OmniLight3D.new()
	arch_light.light_color = Color(1.0, 0.85, 0.6)
	arch_light.light_energy = 3.0
	arch_light.omni_range = 20.0
	arch_light.position = Vector3(0.0, 3.0, shore_z - 2.0)
	_river.add_child(arch_light)
	var title := Label3D.new()
	title.text = ctx.next_circle_name()
	title.font_size = 200
	title.outline_size = 30
	title.pixel_size = 0.03
	title.modulate = ctx.next_circle_fog_color().lightened(0.5)
	title.outline_modulate = Color(0.03, 0.0, 0.0)
	title.shaded = false
	title.position = Vector3(0.0, 9.0, -RIVER_LENGTH * 0.55)
	_river.add_child(title)


## Barca de madera (cuerpo con colisión para ir de pie) con Caronte encapuchado y su remo.
func _build_boat() -> void:
	_boat = AnimatableBody3D.new()
	_boat.collision_layer = 2
	_boat.collision_mask = 0
	_river.add_child(_boat)
	_boat.position = Vector3(0.0, 0.0, 4.0)
	_hull = Node3D.new()
	_boat.add_child(_hull)
	# Casco con proa en punta levantada; la cubierta plana es lo que pisa el jugador.
	var hull_mesh := MeshInstance3D.new()
	hull_mesh.mesh = _hull_mesh()
	var hull_mat := _wood.duplicate() as StandardMaterial3D
	hull_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull_mesh.material_override = hull_mat
	_hull.add_child(hull_mesh)
	var deck_size := Vector3(2.2, 0.12, 6.2)
	var deck_wood := _wood.duplicate() as StandardMaterial3D
	deck_wood.albedo_color = Color(0.32, 0.21, 0.12)
	_add_box(_hull, deck_size, Vector3(0.0, DECK_HEIGHT - 0.06, 0.2), deck_wood)
	var post := _add_box(
		_hull, Vector3(0.16, 1.3, 0.16), Vector3(0.0, DECK_HEIGHT + 0.85, -4.2), _wood
	)
	post.rotation.x = -0.35
	for bench_z in [-0.8, 2.4]:
		_add_box(_hull, Vector3(2.0, 0.1, 0.35), Vector3(0.0, DECK_HEIGHT + 0.3, bench_z), _wood)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.3, 6.6)
	col.shape = shape
	col.position = Vector3(0.0, DECK_HEIGHT - 0.15, 0.2)
	_boat.add_child(col)
	for side in [-1.0, 1.0]:
		var rail_col := CollisionShape3D.new()
		var rail := BoxShape3D.new()
		rail.size = Vector3(0.18, 1.6, 6.6)
		rail_col.shape = rail
		rail_col.position = Vector3(side * 1.25, DECK_HEIGHT + 0.6, 0.2)
		_boat.add_child(rail_col)
	# Caronte: túnica, capucha y farol en la proa, mirando adelante.
	var charon := Node3D.new()
	charon.position = Vector3(0.45, DECK_HEIGHT, -2.5)
	_hull.add_child(charon)
	var robe := MeshInstance3D.new()
	var robe_mesh := CylinderMesh.new()
	robe_mesh.top_radius = 0.28
	robe_mesh.bottom_radius = 0.6
	robe_mesh.height = 2.0
	robe_mesh.radial_segments = 8
	robe.mesh = robe_mesh
	robe.material_override = _robe
	robe.position = Vector3(0.0, 1.0, 0.0)
	charon.add_child(robe)
	var hood := MeshInstance3D.new()
	var hood_mesh := CylinderMesh.new()
	hood_mesh.top_radius = 0.0
	hood_mesh.bottom_radius = 0.38
	hood_mesh.height = 0.75
	hood_mesh.radial_segments = 8
	hood.mesh = hood_mesh
	hood.material_override = _robe
	hood.position = Vector3(0.0, 2.25, 0.0)
	charon.add_child(hood)
	for side in [-0.1, 0.1]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.035
		eye_mesh.height = 0.07
		eye.mesh = eye_mesh
		eye.material_override = make_unshaded(Color(0.6, 1.0, 0.5))
		eye.position = Vector3(side, 2.12, 0.33)
		charon.add_child(eye)
	_oar = Node3D.new()
	_oar.position = Vector3(0.55, 1.3, 0.0)
	charon.add_child(_oar)
	var oar_pole := _add_box(_oar, Vector3(0.08, 3.4, 0.08), Vector3(0.6, -1.2, 0.0), _wood)
	oar_pole.rotation.z = 0.5
	var lantern := _make_lantern()
	lantern.position = Vector3(0.0, DECK_HEIGHT + 2.0, -4.3)
	_hull.add_child(lantern)


## Casco de la barca: contorno con popa recta y proa en punta, paredes inclinadas (más ancho
## arriba) y la punta de la proa levantada como las barcas de río antiguas.
static func _hull_mesh() -> ArrayMesh:
	var top: Array[Vector3] = [
		Vector3(-1.25, 1.05, 3.4),
		Vector3(1.25, 1.05, 3.4),
		Vector3(1.35, 1.0, 0.6),
		Vector3(1.15, 1.05, -2.2),
		Vector3(0.55, 1.25, -3.7),
		Vector3(0.0, 1.7, -4.6),
		Vector3(-0.55, 1.25, -3.7),
		Vector3(-1.15, 1.05, -2.2),
		Vector3(-1.35, 1.0, 0.6),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom: Array[Vector3] = []
	for p in top:
		bottom.append(Vector3(p.x * 0.6, -0.2, clampf(p.z * 0.88, -3.9, 3.1)))
	var count: int = top.size()
	for i in count:
		var j: int = (i + 1) % count
		for v in [top[i], top[j], bottom[j], top[i], bottom[j], bottom[i]]:
			st.add_vertex(v)
	for i in range(1, count - 1):
		for v in [bottom[0], bottom[i + 1], bottom[i]]:
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


## Caronte rema: el remo barre hacia atrás y vuelve, con chapoteo en cada golpe.
func _row_loop() -> void:
	while alive() and is_instance_valid(_oar):
		var stroke: Tween = _oar.create_tween()
		stroke.tween_property(_oar, "rotation:x", 0.7, STROKE_SECONDS * 0.55).set_trans(
			Tween.TRANS_SINE
		)
		stroke.tween_property(_oar, "rotation:x", -0.4, STROKE_SECONDS * 0.45).set_trans(
			Tween.TRANS_SINE
		)
		play_sfx(SFX_OAR, -10.0)
		await stroke.finished


## Brazos que salen del agua junto a la barca y almas que cruzan gritando.
func _spawn_river_events(travel: float) -> void:
	var count: int = maxi(cfg.soul_count, 0)
	for i in count:
		if not await wait(travel / float(count + 1)):
			return
		var ahead: Vector3 = _boat.global_position + Vector3.FORWARD * randf_range(8.0, 16.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		if i % 3 == 2:
			var soul := TransitionSoul.new()
			add_child(soul)
			soul.global_position = ahead + Vector3(side * 5.0, 2.0, 0.0)
			var cross: Tween = soul.create_tween()
			cross.tween_property(soul, "global_position:x", -side * 10.0, 3.5).as_relative()
			cross.tween_callback(soul.queue_free)
			play_sfx(SFX_SOUL, -16.0)
		else:
			for k in 3:
				var arm := make_sprite(SPRITE_ARM, 0.05)
				arm.global_position = (
					ahead + Vector3(side * randf_range(2.2, 4.0), -1.5, randf_range(-2, 2))
				)
				var rise: Tween = arm.create_tween()
				rise.tween_interval(k * 0.25)
				rise.tween_property(arm, "global_position:y", 1.4, 0.7).as_relative().set_trans(
					Tween.TRANS_BACK
				)
				rise.tween_interval(1.4)
				rise.tween_property(arm, "global_position:y", -1.6, 0.9).as_relative()
				rise.tween_callback(arm.queue_free)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
