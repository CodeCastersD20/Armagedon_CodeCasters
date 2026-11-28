class_name GateStairsTransition
extends CircleTransition
## B. Puerta y escalera: se abre una reja en el muro sur del coliseo; el jugador cruza y baja a pie
## por una escalera de caracol de catacumba (osario, antorchas, cráneos que se lanzan, la
## inscripción del Infierno). Al fondo, un umbral de luz lo devuelve a la arena del nuevo círculo
## por la misma reja, que se cierra de golpe tras él.

## Reja en el muro sur (lejos de la AgujaTrono del norte). El muro de 24 lados tiene su cara
## interior a ~24.8 m en el sur: la reja va justo delante.
const GATE_Z: float = 24.6
const GATE_WIDTH: float = 3.2
const GATE_HEIGHT: float = 4.2
const BAR_COUNT: int = 9
const DOOR_TRIGGER_Z: float = 23.7
## Escalera de bolsillo, lejos de la arena y a la misma altura (no activa la caída al vacío).
const POCKET: Vector3 = Vector3(3000.0, 0.0, 0.0)
const COLUMN_RADIUS: float = 1.1
const OUTER_RADIUS: float = 4.3
const STEPS_PER_TURN: int = 14
const STEP_COUNT: int = 36
const STEP_RISE: float = 0.27
const EXIT_TRIGGER: float = 1.8
const WALL_SHADER: Shader = preload("res://assets/shaders/catacomb_wall.gdshader")
const WALL_TEXTURE: Texture2D = preload("res://assets/textures/transitions/catacomb_wall.png")
const INSCRIPTION: String = "LASCIATE OGNE SPERANZA,\nVOI CH'INTRATE"

var _gate: Node3D
var _bars: Node3D
var _stairs: Node3D
var _exit_point: Vector3
var _safe_point: Vector3
var _bottom_y: float = 0.0
var _wall_material: ShaderMaterial
var _stone_material: StandardMaterial3D
var _iron_material: StandardMaterial3D


func prepare() -> void:
	_build_materials()
	_build_gate()


func get_seal_position() -> Vector3:
	return Vector3(0.0, 0.0, GATE_Z - 3.5)


func play() -> void:
	ctx.suspend_fall_respawn(true)
	if not await _open_gate():
		return
	if not await _descend_stairs():
		return
	await _return_through_gate()


## La reja sube entre chispas; el jugador tiene que cruzarla él mismo.
func _open_gate() -> bool:
	ctx.player.add_camera_shake(0.15, 2.2)
	var lift: Tween = create_tween()
	lift.tween_property(_bars, "position:y", GATE_HEIGHT - 0.3, 2.2).set_trans(Tween.TRANS_SINE)
	for i in 6:
		var spark := make_sprite(SPRITE_SPARK, 0.012, _gate)
		spark.position = Vector3(randf_range(-1.4, 1.4), 0.1, 0.0)
		var stw: Tween = spark.create_tween()
		stw.tween_property(spark, "position:y", randf_range(0.6, 1.4), 0.5).as_relative()
		stw.tween_callback(spark.queue_free)
	await lift.finished
	if not alive():
		return false
	var waited: float = 0.0
	while alive() and waited < cfg.max_wait_seconds:
		var pos: Vector3 = ctx.player.global_position
		if pos.z >= DOOR_TRIGGER_Z and absf(pos.x) <= GATE_WIDTH * 0.5:
			break
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not alive():
		return false
	await ctx.fade(Color.BLACK, 1.0, 0.35)
	return alive()


## Escalera de caracol en la escena de bolsillo; baja a pie hasta el umbral de luz.
func _descend_stairs() -> bool:
	_build_stairs()
	var start_angle: float = -0.4
	var start := POCKET + Vector3(cos(start_angle), 0.0, sin(start_angle)) * 2.7
	# Mira en el sentido de la bajada (tangente del caracol).
	var tangent := Vector3(-sin(start_angle), 0.0, cos(start_angle))
	_safe_point = start + Vector3.UP * 0.4
	ctx.teleport_player(_safe_point, atan2(-tangent.x, -tangent.z))
	await ctx.fade(Color.BLACK, 0.0, 0.6)
	if not alive():
		return false
	var waited: float = 0.0
	while alive() and waited < cfg.max_wait_seconds:
		if ctx.player.global_position.distance_to(_exit_point) <= EXIT_TRIGGER:
			break
		_keep_player_inside()
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not alive():
		return false
	await ctx.fade(Color(1.0, 0.85, 0.6), 1.0, 0.5)
	return alive()


## Vuelve a la arena (ya en el nuevo círculo) por la reja, que cae de golpe tras él y se hunde.
func _return_through_gate() -> void:
	ctx.swap_circle(false)
	_stairs.queue_free()
	_bars.position.y = GATE_HEIGHT - 0.3
	ctx.teleport_player(Vector3(0.0, 0.3, GATE_Z - 2.2), 0.0)
	await ctx.fade(Color(1.0, 0.85, 0.6), 0.0, 0.8)
	if not alive():
		return
	var slam: Tween = create_tween()
	slam.tween_property(_bars, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await slam.finished
	if not alive():
		return
	ctx.player.add_camera_shake(0.6, 0.3)
	dust_burst(Vector3(0.0, 0.0, GATE_Z - 0.4), 2.0, 8)
	ctx.show_banner_now()
	ctx.suspend_fall_respawn(false)
	if not await wait(1.6):
		return
	var sink: Tween = create_tween()
	sink.tween_property(_gate, "position:y", -GATE_HEIGHT - 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	await sink.finished


## Si el jugador cae o se sale de la escalera, vuelve al último punto seguro (no se queda atascado).
func _keep_player_inside() -> void:
	var player: Player = ctx.player
	var rel: Vector3 = player.global_position - POCKET
	var flat: float = Vector2(rel.x, rel.z).length()
	var inside: bool = flat < OUTER_RADIUS - 0.2 and flat > COLUMN_RADIUS
	if inside and rel.y > _bottom_y - 1.0 and player.is_on_floor():
		_safe_point = player.global_position + Vector3.UP * 0.2
	elif not inside or rel.y < _bottom_y - 3.0:
		ctx.teleport_player(_safe_point)


func cancel() -> void:
	super.cancel()
	if ctx != null and ctx.game_flow != null:
		ctx.game_flow.call("fade_screen", Color.BLACK, 0.0, 0.2)


func _build_materials() -> void:
	_wall_material = ShaderMaterial.new()
	_wall_material.shader = WALL_SHADER
	_wall_material.set_shader_parameter("wall_texture", WALL_TEXTURE)
	_stone_material = StandardMaterial3D.new()
	_stone_material.albedo_color = Color(0.36, 0.32, 0.27)
	_stone_material.roughness = 1.0
	_iron_material = StandardMaterial3D.new()
	_iron_material.albedo_color = Color(0.2, 0.18, 0.17)
	_iron_material.metallic = 0.6
	_iron_material.roughness = 0.6


## Marco de piedra, hueco negro, reja de barrotes, luz roja al otro lado y dos antorchas.
func _build_gate() -> void:
	_gate = Node3D.new()
	add_child(_gate)
	_gate.global_position = Vector3(0.0, 0.0, GATE_Z)
	_gate.rotation.y = PI  # el frente mira al centro de la arena
	var dark := MeshInstance3D.new()
	var dark_mesh := QuadMesh.new()
	dark_mesh.size = Vector2(GATE_WIDTH, GATE_HEIGHT)
	dark.mesh = dark_mesh
	dark.material_override = make_unshaded(Color(0.02, 0.01, 0.01))
	dark.position = Vector3(0.0, GATE_HEIGHT * 0.5, -0.12)
	_gate.add_child(dark)
	for side in [-1.0, 1.0]:
		_add_box(
			_gate,
			Vector3(0.6, GATE_HEIGHT + 0.6, 0.7),
			Vector3(side * (GATE_WIDTH * 0.5 + 0.3), (GATE_HEIGHT + 0.6) * 0.5, 0.0),
			_stone_material
		)
		var torch := CatacombTorch.new()
		torch.position = Vector3(side * (GATE_WIDTH * 0.5 + 0.95), 1.9, 0.25)
		_gate.add_child(torch)
	_add_box(
		_gate,
		Vector3(GATE_WIDTH + 1.2, 0.6, 0.8),
		Vector3(0.0, GATE_HEIGHT + 0.3, 0.0),
		_stone_material
	)
	_bars = Node3D.new()
	_gate.add_child(_bars)
	for i in BAR_COUNT:
		var x: float = lerpf(-GATE_WIDTH * 0.45, GATE_WIDTH * 0.45, float(i) / float(BAR_COUNT - 1))
		_add_box(
			_bars,
			Vector3(0.09, GATE_HEIGHT, 0.09),
			Vector3(x, GATE_HEIGHT * 0.5, 0.1),
			_iron_material
		)
	for y in [0.9, 2.2, 3.5]:
		_add_box(_bars, Vector3(GATE_WIDTH, 0.1, 0.1), Vector3(0.0, y, 0.12), _iron_material)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.1)
	glow.light_energy = 2.0
	glow.omni_range = 7.0
	glow.position = Vector3(0.0, 1.8, -0.8)
	_gate.add_child(glow)


## Escalera de caracol: columna central, pared exterior de osario con colisión, peldaños,
## techo, suelo del fondo, antorchas, cráneos y brazos, inscripción y el umbral de luz.
func _build_stairs() -> void:
	_stairs = Node3D.new()
	add_child(_stairs)
	_stairs.global_position = POCKET
	var depth: float = float(STEP_COUNT) * STEP_RISE
	var body := StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	_stairs.add_child(body)
	var height: float = depth + 6.0
	var outer := CylinderMesh.new()
	outer.top_radius = OUTER_RADIUS
	outer.bottom_radius = OUTER_RADIUS
	outer.height = height
	outer.radial_segments = 20
	outer.cap_top = true
	outer.cap_bottom = true
	var wall_mat := _wall_material.duplicate() as ShaderMaterial
	wall_mat.set_shader_parameter("tiles", Vector2(14.0, height / 4.0))
	var outer_mi := MeshInstance3D.new()
	outer_mi.mesh = outer
	outer_mi.material_override = wall_mat
	outer_mi.position = Vector3(0.0, 3.5 - height * 0.5, 0.0)
	_stairs.add_child(outer_mi)
	var outer_shape := CollisionShape3D.new()
	# Se camina por dentro del cilindro: la malla de colisión tiene que chocar por las dos caras
	# (por defecto solo por fuera y el jugador la atravesaba y caía).
	var outer_collision: ConcavePolygonShape3D = outer.create_trimesh_shape()
	outer_collision.backface_collision = true
	outer_shape.shape = outer_collision
	outer_shape.position = outer_mi.position
	body.add_child(outer_shape)
	var column := CylinderMesh.new()
	column.top_radius = COLUMN_RADIUS
	column.bottom_radius = COLUMN_RADIUS
	column.height = height
	column.radial_segments = 10
	var column_mat := _wall_material.duplicate() as ShaderMaterial
	column_mat.set_shader_parameter("tiles", Vector2(4.0, height / 4.0))
	var column_mi := MeshInstance3D.new()
	column_mi.mesh = column
	column_mi.material_override = column_mat
	column_mi.position = outer_mi.position
	_stairs.add_child(column_mi)
	var column_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = COLUMN_RADIUS
	cyl.height = height
	column_shape.shape = cyl
	column_shape.position = outer_mi.position
	body.add_child(column_shape)
	_build_steps(body)
	_build_stair_dressing(depth)


func _build_steps(body: StaticBody3D) -> void:
	var step_angle: float = TAU / float(STEPS_PER_TURN)
	var width: float = OUTER_RADIUS - COLUMN_RADIUS
	var mid: float = COLUMN_RADIUS + width * 0.5
	var size := Vector3(width, 0.35, OUTER_RADIUS * step_angle + 0.15)
	var step_mesh := BoxMesh.new()
	step_mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	# Rellano de arriba (dos peldaños de ancho) + peldaños que bajan girando.
	for i in range(-2, STEP_COUNT + 1):
		var ang: float = float(i) * step_angle
		var y: float = -float(maxi(i, 0)) * STEP_RISE - size.y * 0.5
		var xf := Transform3D(Basis(Vector3.UP, -ang), Vector3(cos(ang), 0.0, sin(ang)) * mid)
		xf.origin.y = y
		var mi := MeshInstance3D.new()
		mi.mesh = step_mesh
		mi.material_override = _stone_material
		mi.transform = xf
		_stairs.add_child(mi)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = xf
		body.add_child(col)


func _build_stair_dressing(depth: float) -> void:
	var step_angle: float = TAU / float(STEPS_PER_TURN)
	# Inscripción frente al rellano de arriba.
	var words := Label3D.new()
	words.text = INSCRIPTION
	words.font_size = 64
	words.outline_size = 10
	words.pixel_size = 0.006
	words.modulate = Color(0.95, 0.55, 0.35)
	words.shaded = false
	var a0: float = 0.9
	words.position = Vector3(cos(a0), 0.0, sin(a0)) * (OUTER_RADIUS - 0.08) + Vector3.UP * 1.9
	words.look_at_from_position(words.position, Vector3(0.0, 1.9, 0.0), Vector3.UP)
	words.rotate_object_local(Vector3.UP, PI)
	_stairs.add_child(words)
	for i in range(2, STEP_COUNT, 5):
		var ang: float = float(i) * step_angle + step_angle * 0.5
		var torch := CatacombTorch.new()
		torch.position = (
			Vector3(cos(ang), 0.0, sin(ang)) * (OUTER_RADIUS - 0.25)
			+ Vector3.UP * (1.3 - float(i) * STEP_RISE)
		)
		torch.light_range = 5.0
		_stairs.add_child(torch)
	for i in range(1, STEP_COUNT, 2):
		var ang: float = float(i) * step_angle + randf_range(-0.2, 0.2)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var lurker := WallLurker.new()
		lurker.kind = WallLurker.Kind.ARM if i % 6 == 5 else WallLurker.Kind.SKULL
		lurker.outward = -dir
		lurker.trigger_distance = 2.6
		lurker.lunge_distance = 0.7
		lurker.position = (
			dir * (OUTER_RADIUS - 0.25)
			+ Vector3.UP * (randf_range(0.6, 2.4) - float(i) * STEP_RISE)
		)
		_stairs.add_child(lurker)
	for i in 5:
		var soul := TransitionSoul.new()
		var ang: float = randf() * TAU
		soul.position = Vector3(cos(ang), 0.0, sin(ang)) * 2.6 + Vector3.UP * (-randf() * depth)
		_stairs.add_child(soul)
		var tw: Tween = soul.create_tween().set_loops()
		tw.tween_property(soul, "position:y", 2.5, randf_range(2.5, 4.0)).as_relative()
		tw.tween_property(soul, "position:y", -2.5, randf_range(2.5, 4.0)).as_relative()
	# Suelo del fondo y umbral de luz en la pared, después del último peldaño.
	var bottom_y: float = -depth - STEP_RISE
	_bottom_y = bottom_y
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = OUTER_RADIUS
	floor_mesh.bottom_radius = OUTER_RADIUS
	floor_mesh.height = 0.4
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 2
	floor_body.position = Vector3(0.0, bottom_y - 0.2, 0.0)
	_stairs.add_child(floor_body)
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = _stone_material
	floor_body.add_child(floor_mi)
	var floor_col := CollisionShape3D.new()
	var floor_shape := CylinderShape3D.new()
	floor_shape.radius = OUTER_RADIUS
	floor_shape.height = 0.4
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	var exit_ang: float = float(STEP_COUNT + 2) * step_angle
	var exit_dir := Vector3(cos(exit_ang), 0.0, sin(exit_ang))
	var portal := MeshInstance3D.new()
	var portal_mesh := QuadMesh.new()
	portal_mesh.size = Vector2(2.2, 3.0)
	portal.mesh = portal_mesh
	portal.material_override = make_unshaded(Color(1.0, 0.85, 0.6, 0.95), true)
	portal.position = exit_dir * (OUTER_RADIUS - 0.06) + Vector3.UP * (bottom_y + 1.5)
	_stairs.add_child(portal)
	portal.look_at(_stairs.global_position + Vector3.UP * (bottom_y + 1.5), Vector3.UP)
	var portal_light := OmniLight3D.new()
	portal_light.light_color = Color(1.0, 0.85, 0.6)
	portal_light.light_energy = 3.0
	portal_light.omni_range = 6.0
	portal_light.position = portal.position - exit_dir * 0.8
	_stairs.add_child(portal_light)
	# Se cruza al llegar al pie del umbral (a ras del suelo del fondo).
	_exit_point = _stairs.global_position + portal.position + Vector3.DOWN * 1.5


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
