class_name ArenaCollapseTransition
extends ElevatorTransition
## D. La arena se hunde: con el jugador sobre la plataforma central (pilar), el suelo de la arena
## se resquebraja y cae por anillos de fuera hacia dentro sobre un abismo rojo. El pilar baja por
## el pozo de catacumba y, tras un fundido, EMERGE desde abajo por el hueco central en la arena
## del nuevo círculo (al revés que el elevador, que llega colgado desde arriba).

## Anillos del suelo falso (radios) y sectores por anillo.
const RING_RADII: Array[float] = [5.0, 9.0, 13.5, 18.5, 25.0]
const SECTORS: int = 12
const FLOOR_THICKNESS: float = 1.6
const RING_DELAY: float = 0.85
const FALL_SECONDS: float = 1.3
const RUMBLE_SECONDS: float = 1.4
const ABYSS_Y: float = -16.0

var _segments: Node3D
var _abyss: Node3D


func play() -> void:
	if _platform == null or ctx.floor_shape == null:
		ctx.swap_circle(true)
		return
	ctx.lock_movement(true)
	if not await _collapse_floor():
		return
	if not await _sink_pillar():
		return
	await _emerge()


## Tiembla, se oculta el suelo real y sus pedazos falsos caen por anillos (de fuera a dentro).
func _collapse_floor() -> bool:
	ctx.player.add_camera_shake(0.25, RUMBLE_SECONDS)
	play_sfx(SFX_RUMBLE, -4.0)
	if not await wait(RUMBLE_SECONDS * 0.6):
		return false
	_build_shaft()
	_build_abyss()
	_build_segments()
	ctx.floor_shape.visible = false
	var rings: int = RING_RADII.size() - 1
	for r in range(rings - 1, -1, -1):
		var ring_node: Node3D = _segments.get_child(r) as Node3D
		for seg in ring_node.get_children():
			_drop_segment(seg as Node3D, randf_range(0.0, RING_DELAY * 0.6))
		ctx.player.add_camera_shake(0.35, RING_DELAY)
		play_sfx(SFX_STONE, -4.0)
		if not await wait(RING_DELAY):
			return false
	return await wait(FALL_SECONDS * 0.5)


func _drop_segment(seg: Node3D, delay: float) -> void:
	var tw: Tween = seg.create_tween()
	tw.tween_interval(delay)
	# Se agrieta: tiembla un instante.
	tw.tween_property(seg, "position:y", -0.15, 0.12)
	tw.tween_callback(
		func() -> void:
			dust_burst(seg.global_position + seg.get_meta("center", Vector3.ZERO), 1.6, 3)
	)
	tw.set_parallel(true)
	(
		tw
		. tween_property(seg, "position:y", ABYSS_Y - 6.0, FALL_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
		. set_delay(0.12)
	)
	(
		tw
		. tween_property(
			seg,
			"rotation",
			Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8)),
			FALL_SECONDS
		)
		. set_delay(0.12)
	)


## El pilar baja por el pozo de catacumba hasta el fundido.
func _sink_pillar() -> bool:
	var bottom_y: float = _level_y - cfg.travel_distance
	var down: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	(
		down
		. tween_property(_platform, "global_position:y", bottom_y, cfg.travel_seconds)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await down.finished
	if not alive():
		return false
	await ctx.fade(Color.BLACK, 1.0, 0.5)
	return alive()


## A oscuras: suelo restaurado y círculo nuevo; el pilar sube desde el fondo y emerge por el hueco.
func _emerge() -> void:
	ctx.swap_circle(false)
	ctx.floor_shape.visible = true
	_segments.queue_free()
	_abyss.queue_free()
	await ctx.fade(Color.BLACK, 0.0, 0.7)
	if not alive():
		return
	var up: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	(
		up
		. tween_property(_platform, "global_position:y", _level_y, cfg.arrival_seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	ctx.player.add_camera_shake(0.1, cfg.arrival_seconds)
	await up.finished
	if not alive():
		return
	ctx.player.add_camera_shake(0.6, 0.3)
	dust_burst(Vector3(0.0, _level_y + LEVEL_DROP, 0.0), 6.0, 16)
	ctx.show_banner_now()
	_shaft.queue_free()
	var restore: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	restore.tween_property(_platform, "global_position:y", ctx.platform_rest_position.y, 0.6)
	await restore.finished
	ctx.lock_movement(false)


func cancel() -> void:
	super.cancel()
	if ctx != null and ctx.floor_shape != null:
		ctx.floor_shape.visible = true


## Suelo falso: un nodo por anillo con sus sectores (prismas de corona circular).
func _build_segments() -> void:
	_segments = Node3D.new()
	add_child(_segments)
	var mat := StandardMaterial3D.new()
	var real_mat: Material = (
		(ctx.floor_shape as CSGPrimitive3D).material if ctx.floor_shape is CSGPrimitive3D else null
	)
	if real_mat is StandardMaterial3D:
		mat.albedo_color = (real_mat as StandardMaterial3D).albedo_color
	else:
		mat.albedo_color = Color(0.7, 0.68, 0.66)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for r in RING_RADII.size() - 1:
		var ring_node := Node3D.new()
		_segments.add_child(ring_node)
		for s in SECTORS:
			var a0: float = TAU * float(s) / float(SECTORS)
			var a1: float = TAU * float(s + 1) / float(SECTORS)
			var seg := MeshInstance3D.new()
			seg.mesh = _sector_mesh(RING_RADII[r], RING_RADII[r + 1], a0, a1)
			seg.material_override = mat
			var mid_ang: float = (a0 + a1) * 0.5
			var mid_r: float = (RING_RADII[r] + RING_RADII[r + 1]) * 0.5
			seg.set_meta("center", Vector3(cos(mid_ang), 0.0, sin(mid_ang)) * mid_r)
			ring_node.add_child(seg)


## Prisma de corona circular: cara de arriba (y = 0), borde exterior e interior y laterales.
static func _sector_mesh(r0: float, r1: float, a0: float, a1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = 3
	var bottom: float = -FLOOR_THICKNESS
	for i in steps:
		var t0: float = lerpf(a0, a1, float(i) / float(steps))
		var t1: float = lerpf(a0, a1, float(i + 1) / float(steps))
		var p00 := Vector3(cos(t0) * r0, 0.0, sin(t0) * r0)
		var p01 := Vector3(cos(t0) * r1, 0.0, sin(t0) * r1)
		var p10 := Vector3(cos(t1) * r0, 0.0, sin(t1) * r0)
		var p11 := Vector3(cos(t1) * r1, 0.0, sin(t1) * r1)
		var down := Vector3(0.0, bottom, 0.0)
		_quad(st, p00, p10, p11, p01)  # arriba
		_quad(st, p01, p11, p11 + down, p01 + down)  # borde exterior
		_quad(st, p10, p00, p00 + down, p10 + down)  # borde interior
	var e0a := Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
	var e0b := Vector3(cos(a0) * r1, 0.0, sin(a0) * r1)
	var e1a := Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
	var e1b := Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
	var d := Vector3(0.0, bottom, 0.0)
	_quad(st, e0b, e0a, e0a + d, e0b + d)
	_quad(st, e1a, e1b, e1b + d, e1a + d)
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Abismo bajo la arena: fondo oscuro con resplandor rojo para que se vea caer el suelo.
func _build_abyss() -> void:
	_abyss = Node3D.new()
	add_child(_abyss)
	var plane := MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(70.0, 70.0)
	plane.mesh = plane_mesh
	plane.material_override = make_unshaded(Color(0.12, 0.02, 0.01))
	plane.position = Vector3(0.0, ABYSS_Y, 0.0)
	_abyss.add_child(plane)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.25, 0.08)
	glow.light_energy = 3.0
	glow.omni_range = 40.0
	glow.position = Vector3(0.0, ABYSS_Y + 4.0, 0.0)
	_abyss.add_child(glow)
