class_name ElevatorTransition
extends CircleTransition
## A. Elevador del Mercader: la plataforma central se nivela, el sello aparece sobre ella y al
## romperlo bajan cadenas y la plataforma desciende por un pozo de catacumba (osario, antorchas,
## cráneos y brazos que se lanzan al pasar y almas que gritan; todo se puede romper a tiros).
## Tras un fundido, llega colgada de las cadenas desde lo alto a la arena del nuevo círculo y
## encaja en el hueco central. Se puede mirar y disparar todo el viaje.

## La plataforma ya está a ras del suelo (coliseo.tscn): no hace falta bajarla antes.
const LEVEL_DROP: float = 0.0
const CHAIN_COUNT: int = 4
const CHAIN_RADIUS: float = 4.3
const CHAIN_LENGTH: float = 40.0
const LINK_SPACING: float = 0.26
const SHAKE_BEFORE: float = 1.1
const EDGE_WALL_RADIUS: float = 4.6
const EDGE_WALL_HEIGHT: float = 2.6

var _platform: AnimatableBody3D
var _level_y: float = 0.0
var _chains: Node3D
var _shaft: CatacombShaft
var _light: OmniLight3D
var _edge_wall: CollisionShape3D


func prepare() -> void:
	_platform = ctx.platform
	if _platform == null:
		return
	_level_y = ctx.platform_rest_position.y - LEVEL_DROP
	var tw: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(_platform, "global_position:y", _level_y, 0.8).set_trans(Tween.TRANS_SINE)
	await tw.finished


## El sello flota sobre el centro de la plataforma.
func get_seal_position() -> Vector3:
	return Vector3(0.0, _level_y + LEVEL_DROP, 0.0)


func play() -> void:
	if _platform == null:
		ctx.swap_circle(true)
		return
	ctx.lock_jump(true)
	if not await _descend():
		return
	if not await _arrive_from_above():
		return
	await _settle()


## Bajan las cadenas, tiembla y la plataforma baja por el pozo de catacumba.
func _descend() -> bool:
	_build_edge_wall()
	_build_chains()
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.35)
	_light.light_energy = 1.2
	_light.omni_range = 10.0
	_light.position = Vector3(0.0, 3.5, 0.0)
	_platform.add_child(_light)
	ctx.player.add_camera_shake(0.3, SHAKE_BEFORE)
	play_sfx(SFX_RUMBLE, -8.0)
	if not await wait(SHAKE_BEFORE):
		return false
	_build_shaft()
	var bottom_y: float = _level_y - cfg.travel_distance
	var down: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	(
		down
		. tween_property(_platform, "global_position:y", bottom_y, cfg.travel_seconds)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	await down.finished
	if not alive():
		return false
	await ctx.fade(Color.BLACK, 1.0, 0.45)
	return alive()


## A oscuras cambia el círculo; la plataforma aparece en lo alto colgada de las cadenas y baja
## despacio hasta encajar en el hueco central de la arena nueva.
func _arrive_from_above() -> bool:
	var player: Player = ctx.player
	ctx.swap_circle(false)
	_shaft.queue_free()
	var offset: Vector3 = player.global_position - _platform.global_position
	_platform.global_position.y = _level_y + cfg.arrival_height
	ctx.teleport_player(_platform.global_position + offset + Vector3.UP * 0.05)
	await ctx.fade(Color.BLACK, 0.0, 0.7)
	if not alive():
		return false
	var arrive: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	(
		arrive
		. tween_property(_platform, "global_position:y", _level_y, cfg.arrival_seconds)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	player.add_camera_shake(0.08, cfg.arrival_seconds)
	await arrive.finished
	return alive()


## Golpe al encajar, polvo, cartel del círculo, las cadenas suben y la plataforma vuelve a su
## altura de siempre.
func _settle() -> void:
	ctx.player.add_camera_shake(0.7, 0.35)
	dust_burst(Vector3(0.0, _level_y + LEVEL_DROP, 0.0), 6.0, 16)
	ctx.show_banner_now()
	var retract: Tween = create_tween()
	(
		retract
		. tween_property(_chains, "position:y", CHAIN_LENGTH, 1.6)
		. as_relative()
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	retract.parallel().tween_property(_light, "light_energy", 0.0, 1.0)
	await retract.finished
	if not alive():
		return
	var restore: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	restore.tween_property(_platform, "global_position:y", ctx.platform_rest_position.y, 0.6)
	await restore.finished
	_cleanup_platform_children()
	ctx.lock_jump(false)


func cancel() -> void:
	super.cancel()
	_cleanup_platform_children()
	if ctx != null and ctx.game_flow != null:
		ctx.game_flow.call("fade_screen", Color.BLACK, 0.0, 0.2)


## Pared invisible en el borde de la plataforma: se camina por ella sin caer al pozo (no se puede
## saltar durante el viaje). Va en la propia plataforma, así baja y sube con ella.
func _build_edge_wall() -> void:
	var ring := CylinderMesh.new()
	ring.top_radius = EDGE_WALL_RADIUS
	ring.bottom_radius = EDGE_WALL_RADIUS
	ring.height = EDGE_WALL_HEIGHT
	ring.radial_segments = 24
	ring.cap_top = false
	ring.cap_bottom = false
	var shape: ConcavePolygonShape3D = ring.create_trimesh_shape()
	shape.backface_collision = true
	_edge_wall = CollisionShape3D.new()
	_edge_wall.shape = shape
	_edge_wall.position = Vector3(0.0, EDGE_WALL_HEIGHT * 0.5, 0.0)
	_platform.add_child(_edge_wall)


func _cleanup_platform_children() -> void:
	if is_instance_valid(_edge_wall):
		_edge_wall.queue_free()
	if is_instance_valid(_chains):
		_chains.queue_free()
	if is_instance_valid(_light):
		_light.queue_free()


## Cuatro cadenas (eslabones low-poly en un MultiMesh por cadena) que suben desde el borde de
## la plataforma hasta el cielo. Son hijas de la plataforma: bajan y suben con ella.
func _build_chains() -> void:
	_chains = Node3D.new()
	_chains.name = "ElevatorChains"
	_platform.add_child(_chains)
	_chains.position = Vector3(0.0, LEVEL_DROP + CHAIN_LENGTH, 0.0)
	var link := TorusMesh.new()
	link.inner_radius = 0.05
	link.outer_radius = 0.13
	link.rings = 6
	link.ring_segments = 4
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.22, 0.2, 0.19)
	iron.metallic = 0.6
	iron.roughness = 0.7
	link.material = iron
	var links: int = int(CHAIN_LENGTH / LINK_SPACING)
	for c in CHAIN_COUNT:
		var ang: float = TAU * (float(c) + 0.5) / float(CHAIN_COUNT)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = link
		mm.instance_count = links
		for i in links:
			# Eslabones alternos girados 90°, de pie (el toro se pone vertical).
			var link_basis := Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3(1.0, 1.6, 1.0))
			if i % 2 == 1:
				link_basis = Basis(Vector3.UP, PI * 0.5) * link_basis
			var link_pos := Vector3(0.0, -float(i) * LINK_SPACING, 0.0)
			mm.set_instance_transform(i, Transform3D(link_basis, link_pos))
		var chain := MultiMeshInstance3D.new()
		chain.multimesh = mm
		chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chain.position = Vector3(cos(ang) * CHAIN_RADIUS, 0.0, sin(ang) * CHAIN_RADIUS)
		_chains.add_child(chain)
	# Bajan desde el cielo hasta engancharse a la plataforma.
	var drop: Tween = create_tween()
	_chains.position.y += 12.0
	(
		drop
		. tween_property(_chains, "position:y", -12.0, SHAKE_BEFORE * 0.8)
		. as_relative()
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)


## Pozo de catacumba bajo el hueco central: osario, antorchas, cráneos que se lanzan y almas.
func _build_shaft() -> void:
	_shaft = CatacombShaft.new()
	_shaft.top_y = _level_y - 1.0
	_shaft.height = cfg.travel_distance + 26.0
	_shaft.soul_count = cfg.soul_count
	add_child(_shaft)
	_shaft.build()
