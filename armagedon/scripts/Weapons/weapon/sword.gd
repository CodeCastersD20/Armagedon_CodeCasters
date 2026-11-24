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
## Qué tan rápido (1/segundos) se desvanece la pose del pack al terminar la animación.
const PACK_FADE_SPEED: float = 8.0
## Giro de 180° en Y: pasa del personaje (mira a +Z) a la cámara (mira a -Z).
const CAMERA_FLIP: Basis = Basis(
	Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0)
)

## Medidas del modelo "Espada PS1" (las da el visor scenes/Debug/anim_viewer.tscn):
## dirección de la hoja, dirección del ancho de la guarda y centro del mango.
@export var model_blade_dir: Vector3 = Vector3(0.0, -1.0, 0.0)
@export var model_wide_dir: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var model_grip_center: Vector3 = Vector3(0.0, 0.835771, 0.0)

var _original_rotation: Vector3
var _original_position: Vector3
var _slash_tween: Tween
# Arranca en true: el primer ataque alterna a false y hace el tajo "\".
var _slash_alternate: bool = true
var _original_basis: Basis
## Estela de corte reutilizada en cada ataque (un solo nodo, malla y material).
var _whoosh_node: MeshInstance3D
var _whoosh_mesh: ImmediateMesh
var _whoosh_material: StandardMaterial3D
var _whoosh_tween: Tween
## Cada ataque lleva un número: si cambia durante el retraso del golpe, el golpe se cancela.
var _attack_id: int = 0
## Consulta de esfera reutilizada (no se crea una por tajo).
var _hit_shape: SphereShape3D
var _hit_query: PhysicsShapeQueryParameters3D


func _ready() -> void:
	super._ready()
	if _mesh_instance != null:
		_mesh_instance.position = Vector3(0.0, 0.4, -0.05)
	_original_rotation = rotation
	_original_position = position
	_original_basis = basis


## Punto de entrada del ataque: dispara cada módulo por separado sin mezclarse.
## El golpe conecta tras hit_delay_seconds para coincidir con el tajo de la animación.
func _perform_attack() -> void:
	_slash_alternate = not _slash_alternate
	_attack_id += 1
	var attack_id: int = _attack_id
	_play_weapon_animation(_slash_alternate)
	_show_whoosh_effect(_slash_alternate)
	if data.hit_delay_seconds > 0.0:
		await get_tree().create_timer(data.hit_delay_seconds).timeout
		# Si se guardó el arma (o hubo otro ataque) durante el tajo, el golpe se cancela.
		if not is_inside_tree() or not visible or attack_id != _attack_id:
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

	var exclude: Array[RID] = _player_exclude()

	var space_state := get_world_3d().direct_space_state
	# Las marcas rojas del tajo son ayuda de depuración: no corren en el juego exportado.
	if OS.is_debug_build():
		_mark_slash_line(space_state, camera, exclude)
	if _hit_shape == null:
		_hit_shape = SphereShape3D.new()
		_hit_query = PhysicsShapeQueryParameters3D.new()
		_hit_query.shape = _hit_shape
		_hit_query.collision_mask = 0xFFFFFFFF
	_hit_shape.radius = data.max_range
	var shape_query: PhysicsShapeQueryParameters3D = _hit_query
	shape_query.transform = Transform3D(Basis.IDENTITY, origin)
	shape_query.exclude = exclude

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
		var roll: Dictionary = roll_damage()
		collider.call("take_damage", roll["damage"], roll["crit"])
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


## Además de los efectos base, dibuja la estela de corte (transparente) con alfa 0.
func prewarm() -> void:
	super.prewarm()
	_show_whoosh_effect(true)
	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	if _whoosh_material != null:
		_whoosh_material.albedo_color.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if _whoosh_node != null and is_instance_valid(_whoosh_node):
		_whoosh_node.visible = false


## Al guardar el arma: anula el golpe pendiente y deja la espada en reposo.
func cancel_reload() -> void:
	super.cancel_reload()
	_attack_id += 1
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()
	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	if _whoosh_node != null and is_instance_valid(_whoosh_node):
		_whoosh_node.visible = false
	rotation = _original_rotation
	position = _original_position


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

	if _whoosh_mesh == null:
		_whoosh_mesh = ImmediateMesh.new()
		_whoosh_material = StandardMaterial3D.new()
		_whoosh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_whoosh_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_whoosh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_whoosh_material.albedo_color = Color(0.9, 0.95, 1.0, 0.85)

	var half_angle: float = deg_to_rad(data.arc_angle_degrees * 0.5)
	var steps: int = 16

	_whoosh_mesh.clear_surfaces()
	_whoosh_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _whoosh_material)
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

		_whoosh_mesh.surface_add_vertex(Vector3(x * 0.5, y * 0.5, z * 0.7))
		_whoosh_mesh.surface_add_vertex(Vector3(x * 1.1, y * 1.1, z * 1.3))
	_whoosh_mesh.surface_end()

	if _whoosh_node == null or not is_instance_valid(_whoosh_node):
		_whoosh_node = MeshInstance3D.new()
		_whoosh_node.mesh = _whoosh_mesh
		_whoosh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _whoosh_node.get_parent() != camera:
		if _whoosh_node.get_parent() != null:
			_whoosh_node.get_parent().remove_child(_whoosh_node)
		camera.add_child(_whoosh_node)
	_whoosh_node.position = Vector3(0.0, -0.05, 0.0)
	_whoosh_node.rotation = Vector3.ZERO
	_whoosh_node.visible = true

	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	_whoosh_tween = _whoosh_node.create_tween()
	_whoosh_tween.tween_property(_whoosh_material, "albedo_color:a", 0.0, 0.2)
	_whoosh_tween.tween_callback(_whoosh_node.set_visible.bind(false))


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
