class_name Sword
extends Weapon
## Espada: arma melee inicial de Zahariel (GDD §6.1).
## Lógica modular separada:
## 1. Detección de daño (hit/raycasts del arco frontal limpio)
## 2. Animación procedural del arma (Tween)
## 3. Efecto visual independiente (Whoosh)

signal hit_enemy(enemy: Object, hit_position: Vector3)

@export var arc_angle_degrees: float = 90.0
@export var arc_range: float = 2.5
@export var ray_count: int = 9

var _original_rotation: Vector3
var _original_position: Vector3
var _slash_tween: Tween
var _slash_alternate: bool = false


func _ready() -> void:
	super._ready()
	if _mesh_instance != null:
		_mesh_instance.position.z = -0.45
	_original_rotation = rotation
	_original_position = position


## Punto de entrada del ataque: dispara cada módulo por separado sin mezclarse
func _perform_attack() -> void:
	_slash_alternate = not _slash_alternate
	_perform_combat_hit()
	_play_weapon_animation(_slash_alternate)
	_show_whoosh_effect(_slash_alternate)


# ==============================================================================
# MÓDULO 1: COMBATE Y DAÑO (HIT TOTALMENTE INDEPENDIENTE)
# ==============================================================================
func _perform_combat_hit() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var from: Vector3 = camera.global_position
	var half_angle_rad: float = deg_to_rad(arc_angle_degrees * 0.5)
	var step_angle: float = deg_to_rad(arc_angle_degrees) / float(maxi(ray_count - 1, 1))

	var exclude: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null:
		exclude.append(player.get_rid())

	var space_state := get_world_3d().direct_space_state
	var hit_targets: Array[Object] = []

	for i in range(ray_count):
		var angle: float = -half_angle_rad + float(i) * step_angle
		# Rayo proyectado en el plano horizontal de la vista del jugador
		var dir: Vector3 = (-camera.global_basis.z).rotated(camera.global_basis.y, angle).normalized()
		var to: Vector3 = from + dir * arc_range

		var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, exclude)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var collider: Object = hit["collider"]
		# Dibujar la marca de impacto en cada punto del abanico que choque con una superficie
		_spawn_impact(hit["position"], hit["normal"])

		# El daño solo se aplica 1 vez por enemigo en este tajo
		if collider != null and not hit_targets.has(collider):
			hit_targets.append(collider)
			if collider.has_method("take_damage"):
				collider.call("take_damage", data.damage)
			hit_enemy.emit(collider, hit["position"])
			hit_target.emit(collider, hit["position"], hit["normal"])


# ==============================================================================
# MÓDULO 2: ANIMACIÓN PROCEDURAL DEL ARMA (VISUAL MODELO)
# ==============================================================================
func _play_weapon_animation(alternate: bool) -> void:
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()

	_slash_tween = create_tween()

	if alternate:
		# Swing 1: corte descendente diagonal /
		_slash_tween.tween_property(self, "rotation:x", _original_rotation.x + deg_to_rad(30.0), 0.07)
		_slash_tween.parallel().tween_property(self, "rotation:y", _original_rotation.y + deg_to_rad(35.0), 0.07)

		_slash_tween.tween_property(self, "rotation:x", _original_rotation.x - deg_to_rad(55.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_slash_tween.parallel().tween_property(self, "rotation:y", _original_rotation.y - deg_to_rad(65.0), 0.12)
		_slash_tween.parallel().tween_property(self, "rotation:z", _original_rotation.z - deg_to_rad(30.0), 0.12)
	else:
		# Swing 2: corte descendente diagonal \
		_slash_tween.tween_property(self, "rotation:x", _original_rotation.x + deg_to_rad(30.0), 0.07)
		_slash_tween.parallel().tween_property(self, "rotation:y", _original_rotation.y - deg_to_rad(45.0), 0.07)

		_slash_tween.tween_property(self, "rotation:x", _original_rotation.x - deg_to_rad(55.0), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_slash_tween.parallel().tween_property(self, "rotation:y", _original_rotation.y + deg_to_rad(55.0), 0.12)
		_slash_tween.parallel().tween_property(self, "rotation:z", _original_rotation.z + deg_to_rad(35.0), 0.12)

	_slash_tween.tween_property(self, "rotation", _original_rotation, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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

	var half_angle: float = deg_to_rad(arc_angle_degrees * 0.5)
	var steps: int = 16

	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, mat)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float
		var y: float

		if alternate:
			# Diagonal /
			angle = half_angle - t * deg_to_rad(arc_angle_degrees)
			y = 0.18 - t * 0.42
		else:
			# Diagonal \
			angle = -half_angle + t * deg_to_rad(arc_angle_degrees)
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
