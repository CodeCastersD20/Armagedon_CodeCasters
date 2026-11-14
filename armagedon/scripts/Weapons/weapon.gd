class_name Weapon
extends Node3D
## Base de todas las armas: cadencia, cargador, recarga y disparo hitscan.
## Cada arma concreta puede sobrescribir _perform_attack() (escopeta #46, espada #41).

signal attacked
signal hit_target(target: Object, hit_position: Vector3, hit_normal: Vector3)
signal ammo_changed(current: int, magazine: int)
signal reload_started(seconds: float)
signal reload_finished

const RECOIL_Z: float = 0.06
const RECOIL_RECOVERY_SPEED: float = 14.0
const TRACER_DURATION: float = 0.08
const IMPACT_DURATION: float = 1.5

@export var data: WeaponData

var _ammo: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	if data == null:
		push_error("Weapon sin WeaponData: %s" % name)
		return
	_ammo = data.magazine_size
	if data.mesh != null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.mesh = data.mesh
		add_child(_mesh_instance)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	position.z = move_toward(position.z, 0.0, RECOIL_RECOVERY_SPEED * delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = data.magazine_size
			reload_finished.emit()
			ammo_changed.emit(_ammo, data.magazine_size)


func is_melee() -> bool:
	return data.kind == WeaponData.Kind.MELEE


func uses_magazine() -> bool:
	return data.magazine_size > 0


func is_reloading() -> bool:
	return _reload_left > 0.0


func get_reload_seconds_left() -> float:
	return _reload_left


func get_ammo() -> int:
	return _ammo


## Ataca si la cadencia y el cargador lo permiten. Con el cargador vacío empieza a recargar.
func try_attack() -> bool:
	if _cooldown > 0.0 or is_reloading():
		return false
	if uses_magazine() and _ammo <= 0:
		try_reload()
		return false
	_cooldown = data.attack_interval
	if uses_magazine():
		_ammo -= 1
		ammo_changed.emit(_ammo, data.magazine_size)
	position.z = RECOIL_Z
	_perform_attack()
	attacked.emit()
	return true


func try_reload() -> bool:
	if not uses_magazine() or is_reloading() or _ammo >= data.magazine_size:
		return false
	_reload_left = data.reload_seconds
	reload_started.emit(data.reload_seconds)
	return true


## Al guardar el arma se cancela la recarga.
func cancel_reload() -> void:
	_reload_left = 0.0
	position.z = 0.0


## Disparo hitscan desde el centro de la cámara para armas de fuego.
func _perform_attack() -> void:
	if is_melee():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_basis.z * data.max_range
	var exclude: Array[RID] = []
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player != null:
		exclude.append(player.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, exclude)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var muzzle: Vector3 = global_position - global_basis.z * 0.25
	if hit.is_empty():
		_spawn_tracer(muzzle, to)
		return
	var hit_pos: Vector3 = hit["position"]
	var hit_norm: Vector3 = hit["normal"]
	_spawn_tracer(muzzle, hit_pos)
	_spawn_impact(hit_pos, hit_norm)
	var collider: Object = hit["collider"]
	if collider.has_method("take_damage"):
		collider.call("take_damage", data.damage)
	hit_target.emit(collider, hit_pos, hit_norm)


func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = im
	node.top_level = true
	get_tree().current_scene.add_child(node)
	get_tree().create_timer(TRACER_DURATION).timeout.connect(node.queue_free)


func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.25, 0.1)
	sphere.material = mat
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.top_level = true
	scene.add_child(node)
	node.global_position = pos + normal * 0.02
	get_tree().create_timer(IMPACT_DURATION).timeout.connect(node.queue_free)
