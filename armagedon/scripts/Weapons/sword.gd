class_name Sword
extends Weapon
## Espada: arma melee inicial de Zahariel (GDD §6.1).
## Lógica modular separada:
## 1. Detección de daño (hit/raycasts del arco frontal limpio)
## 2. Animación procedural del arma (Tween)
## 3. Efecto visual independiente (Whoosh)

signal hit_enemy(enemy: Object, hit_position: Vector3)

## Altura (sobre los pies) del punto al que se apunta en cada enemigo para la línea de visión.
const TARGET_HEIGHT: float = 0.9
const MAX_TARGETS: int = 32
const SLASH_MARKS: int = 7
const SLASH_REACH_X: float = 0.35
const SLASH_RAISE_Y: float = 0.3
const SLASH_DROP_Y: float = 0.25

var _original_rotation: Vector3
var _original_position: Vector3
var _slash_tween: Tween
# Arranca en true: el primer ataque alterna a false y hace el tajo "\".
var _slash_alternate: bool = true


func _ready() -> void:
	super._ready()
	if _mesh_instance != null:
		_mesh_instance.position = Vector3(0.0, 0.4, -0.05)
	_original_rotation = rotation
	_original_position = position


## Punto de entrada del ataque: dispara cada módulo por separado sin mezclarse.
## El golpe conecta tras hit_delay_seconds para coincidir con el tajo de la animación.
func _perform_attack() -> void:
	_slash_alternate = not _slash_alternate
	_play_weapon_animation(_slash_alternate)
	_show_whoosh_effect(_slash_alternate)
	if data.hit_delay_seconds > 0.0:
		await get_tree().create_timer(data.hit_delay_seconds).timeout
		# Si se guardó el arma durante el tajo, el golpe se cancela.
		if not is_inside_tree() or not visible:
			return
	_perform_combat_hit()


# ==============================================================================
# MÓDULO 1: COMBATE Y DAÑO (HIT TOTALMENTE INDEPENDIENTE)
# Todo se calcula en espacio de mundo desde la cámara, sin usar la rotación del arma.
# Sector frontal: cuerpos dentro de una esfera (alcance), dentro del ángulo del arco
# (en el plano horizontal, así acierta a cualquier altura) y sin pared de por medio.
# ==============================================================================
func _perform_combat_hit() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		# Mirando casi recto arriba o abajo: se usa el frente del jugador.
		forward = -camera.global_basis.y
		forward.y = 0.0
	forward = forward.normalized()

	var exclude: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null:
		exclude.append(player.get_rid())

	var space_state := get_world_3d().direct_space_state
	_mark_slash_line(space_state, camera, exclude)
	var sphere := SphereShape3D.new()
	sphere.radius = data.max_range
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = sphere
	shape_query.transform = Transform3D(Basis.IDENTITY, origin)
	shape_query.exclude = exclude
	shape_query.collision_mask = 0xFFFFFFFF

	var min_dot: float = cos(deg_to_rad(data.arc_angle_degrees * 0.5))
	var hit_targets: Array[Object] = []

	for result in space_state.intersect_shape(shape_query, MAX_TARGETS):
		var collider := result["collider"] as Node3D
		# El daño solo se aplica 1 vez por enemigo en este tajo
		if collider == null or hit_targets.has(collider) or not collider.has_method("take_damage"):
			continue
		var target_point: Vector3 = collider.global_position + Vector3.UP * TARGET_HEIGHT
		var to_target: Vector3 = target_point - origin
		var flat: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
		# Pegado al jugador siempre cuenta; si no, debe caer dentro del arco.
		if flat.length() > 0.3 and forward.dot(flat.normalized()) < min_dot:
			continue
		if not _has_line_of_sight(space_state, origin, target_point, exclude, collider):
			continue
		hit_targets.append(collider)
		collider.call("take_damage", data.damage)
		var normal: Vector3 = -to_target.normalized()
		_spawn_impact(target_point, normal)
		hit_enemy.emit(collider, target_point)
		hit_target.emit(collider, target_point, normal)


## Ninguna pared debe estar entre el jugador y el enemigo.
func _has_line_of_sight(
	space_state: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	exclude: Array[RID],
	target: CollisionObject3D
) -> bool:
	var ignore: Array[RID] = exclude.duplicate()
	if target != null:
		ignore.append(target.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, ignore)
	return space_state.intersect_ray(query).is_empty()


# ==============================================================================
# MÓDULO 2: ANIMACIÓN PROCEDURAL DEL ARMA (VISUAL MODELO)
# ==============================================================================
func _play_weapon_animation(alternate: bool) -> void:
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()

	_slash_tween = create_tween()
	# Tajo en diagonal frente a la cámara: "\" (arriba-izquierda a abajo-derecha) y
	# "/" (arriba-derecha a abajo-izquierda) alternando. La punta pasa de atrás a adelante.
	var start_side: float = 1.0 if alternate else -1.0
	var start_pos: Vector3 = (
		_original_position + Vector3(start_side * SLASH_REACH_X, SLASH_RAISE_Y, 0.0)
	)
	var end_pos: Vector3 = (
		_original_position + Vector3(-start_side * SLASH_REACH_X, -SLASH_DROP_Y, 0.0)
	)
	var start_rot: Vector3 = (
		_original_rotation + Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(-start_side * 35.0))
	)
	var end_rot: Vector3 = (
		_original_rotation + Vector3(deg_to_rad(-65.0), 0.0, deg_to_rad(start_side * 35.0))
	)

	_slash_tween.tween_property(self, "position", start_pos, 0.07)
	_slash_tween.parallel().tween_property(self, "rotation", start_rot, 0.07)
	(
		_slash_tween
		. tween_property(self, "position", end_pos, 0.12)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", end_rot, 0.12)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. tween_property(self, "position", _original_position, 0.35)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", _original_rotation, 0.35)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


# ==============================================================================
# MÓDULO 3: ESTELA DE CORTE (WHOOSH VISUAL EN PANTALLA)
# ==============================================================================
func _show_whoosh_effect(alternate: bool) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.9, 0.95, 1.0, 0.85)

	var half_angle: float = deg_to_rad(data.arc_angle_degrees * 0.5)
	var steps: int = 16

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float
		var y: float

		if alternate:
			# Diagonal /
			angle = half_angle - t * deg_to_rad(data.arc_angle_degrees)
			y = 0.18 - t * 0.42
		else:
			# Diagonal \
			angle = -half_angle + t * deg_to_rad(data.arc_angle_degrees)
			y = 0.18 - t * 0.42

		var x: float = sin(angle)
		var z: float = -cos(angle)

		im.surface_add_vertex(Vector3(x * 0.5, y * 0.5, z * 0.7))
		im.surface_add_vertex(Vector3(x * 1.1, y * 1.1, z * 1.3))
	im.surface_end()

	var node := MeshInstance3D.new()
	node.mesh = im
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(node)
	node.position = Vector3(0.0, -0.05, 0.0)
	node.rotation = Vector3.ZERO

	var tw := node.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(node.queue_free)


## Marca con puntos rojos en línea la superficie que recorre el tajo (diagonal, como el whoosh).
func _mark_slash_line(
	space_state: PhysicsDirectSpaceState3D, camera: Camera3D, exclude: Array[RID]
) -> void:
	var from: Vector3 = camera.global_position
	var half_angle: float = deg_to_rad(data.arc_angle_degrees * 0.5)
	for i in range(SLASH_MARKS):
		var t: float = float(i) / float(SLASH_MARKS - 1)
		var yaw: float = lerpf(half_angle, -half_angle, t) * (1.0 if _slash_alternate else -1.0)
		var pitch: float = lerpf(0.18, -0.24, t)
		var dir: Vector3 = (camera.global_basis * Vector3(sin(yaw), pitch, -cos(yaw))).normalized()
		var query := PhysicsRayQueryParameters3D.create(
			from, from + dir * data.max_range, 0xFFFFFFFF, exclude
		)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty() or (hit["collider"] as Object).has_method("take_damage"):
			continue
		_spawn_impact(hit["position"], hit["normal"])
