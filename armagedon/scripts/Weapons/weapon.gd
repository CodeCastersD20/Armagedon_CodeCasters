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
const MUZZLE_FLASH_DURATION: float = 0.055
const MUZZLE_FLASH_SHADER: Shader = preload("res://assets/shaders/muzzle_flash.gdshader")
const IMPACT_DURATION: float = 1.5
const ENEMY_IMPACT_SCALE: float = 2.0
const _HITSCAN_TRACER = preload("res://scripts/Weapons/hitscan_tracer.gd")

## Recursos compartidos por todos los disparos/impactos: se crean una vez, no por disparo.
static var _muzzle_mesh: QuadMesh
static var _muzzle_material: ShaderMaterial
static var _impact_mesh: SphereMesh
## Nodos de impacto libres para reutilizar (no se crean ni liberan por disparo).
static var _impact_pool: Array[MeshInstance3D] = []

@export var data: WeaponData
@export var muzzle_offset: Vector3 = Vector3(0.15, -0.02, -0.38)

var _ammo: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _muzzle_left: float = 0.0
var _muzzle_flash: MeshInstance3D
var _mesh_instance: MeshInstance3D
var _player_body: CollisionObject3D
var _base_recoil_tween: Tween
var _initial_rot_x: float = 0.0
var _initial_pos_y: float = 0.0


func _ready() -> void:
	_initial_rot_x = rotation.x
	_initial_pos_y = position.y
	if data == null:
		push_error("Weapon sin WeaponData: %s" % name)
		return
	if data.attack_interval <= 0.0 or data.max_range <= 0.0:
		push_warning("WeaponData con valores inválidos (attack_interval/max_range <= 0): %s" % name)
	_ammo = data.magazine_size
	if data.mesh != null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.mesh = data.mesh
		add_child(_mesh_instance)
	# Estilo PSX (Nearest y vertex snapping) en todas las mallas del arma; los materiales se cachean.
	PsxStyle.apply(self)
	if not is_melee():
		_setup_muzzle_flash()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	position.z = move_toward(position.z, 0.0, RECOIL_RECOVERY_SPEED * delta)
	if _muzzle_left > 0.0:
		_muzzle_left -= delta
		if _muzzle_left <= 0.0 and _muzzle_flash != null:
			_muzzle_flash.visible = false
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
	_cooldown = maxf(data.attack_interval, 0.01)
	if uses_magazine():
		_ammo -= 1
		ammo_changed.emit(_ammo, data.magazine_size)
	position.z = data.recoil_z_kick if data.recoil_z_kick > 0.0 else RECOIL_Z
	_perform_attack()
	attacked.emit()
	_play_sfx(data.sfx_attack)
	return true


func try_reload() -> bool:
	if not uses_magazine() or is_reloading() or _ammo >= data.magazine_size:
		return false
	if data.reload_seconds <= 0.0:
		# Recarga instantánea: evita dejar el arma vacía para siempre.
		_ammo = data.magazine_size
		ammo_changed.emit(_ammo, data.magazine_size)
		return true
	_reload_left = data.reload_seconds
	reload_started.emit(data.reload_seconds)
	_play_sfx(data.sfx_reload)
	return true


## Reproduce un SFX por el AudioManager (bus SFX, pool de 8). Null = sin sonido asignado.
func _play_sfx(stream: AudioStream) -> void:
	if stream != null:
		AudioManager.play_sfx(stream)


## Al guardar el arma se cancela la recarga.
func cancel_reload() -> void:
	_reload_left = 0.0
	_muzzle_left = 0.0
	if _muzzle_flash != null:
		_muzzle_flash.visible = false
	if _base_recoil_tween != null and _base_recoil_tween.is_valid():
		_base_recoil_tween.kill()
	rotation.x = _initial_rot_x
	position.y = _initial_pos_y
	position.z = 0.0


## Devuelve el daño del golpe; tira el crítico. Sin relación con headshot ni Score.
func roll_damage() -> Dictionary:
	var is_crit: bool = randf() < data.crit_chance
	var amount: float = data.damage * (data.crit_multiplier if is_crit else 1.0)
	return {"damage": amount, "crit": is_crit}


## Disparo hitscan desde el centro de la cámara para armas de fuego.
func _perform_attack() -> void:
	if is_melee():
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_basis.z * data.max_range
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, _player_exclude())
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_show_muzzle_flash()
	_apply_fire_camera_feedback()
	_play_base_recoil()
	var tracer_from: Vector3 = _muzzle_flash.global_position if _muzzle_flash != null else from
	if hit.is_empty():
		if data.tracer_enabled:
			_spawn_tracer(tracer_from, to)
		return
	var hit_pos: Vector3 = hit["position"]
	var hit_norm: Vector3 = hit["normal"]
	if data.tracer_enabled:
		_spawn_tracer(tracer_from, hit_pos)
	var collider: Object = hit["collider"]
	var is_enemy: bool = collider != null and collider.has_method("take_damage")
	_spawn_impact(hit_pos, hit_norm, ENEMY_IMPACT_SCALE if is_enemy else 1.0)
	if is_enemy:
		var roll: Dictionary = roll_damage()
		collider.call("take_damage", roll["damage"], roll["crit"])
	hit_target.emit(collider, hit_pos, hit_norm)


func _apply_fire_camera_feedback() -> void:
	var player_node := _player_body
	if player_node == null or not is_instance_valid(player_node):
		player_node = get_tree().get_first_node_in_group("player") as CollisionObject3D
		_player_body = player_node
	if player_node == null:
		return
	if data.camera_punch_on_fire > 0.0 and player_node.has_method("add_camera_punch"):
		player_node.call("add_camera_punch", data.camera_punch_on_fire)
	if data.camera_shake_on_fire > 0.0 and player_node.has_method("add_camera_shake"):
		player_node.call(
			"add_camera_shake", data.camera_shake_on_fire, maxf(data.camera_shake_duration, 0.01)
		)


func _play_base_recoil() -> void:
	if data.recoil_kick_degrees == 0.0 and data.recoil_lift == 0.0:
		return
	if _base_recoil_tween != null and _base_recoil_tween.is_valid():
		_base_recoil_tween.kill()
	_base_recoil_tween = create_tween()
	var total: float = maxf(data.recoil_recovery_seconds, 0.01)
	var kick: float = _initial_rot_x + deg_to_rad(data.recoil_kick_degrees)
	var up: float = _initial_pos_y + data.recoil_lift
	_base_recoil_tween.tween_property(self, "rotation:x", kick, total * 0.14)
	_base_recoil_tween.parallel().tween_property(self, "position:y", up, total * 0.14)
	_base_recoil_tween.tween_property(self, "rotation:x", _initial_rot_x, total * 0.86)
	_base_recoil_tween.parallel().tween_property(self, "position:y", _initial_pos_y, total * 0.86)


## RID del jugador para excluirlo de los raycasts. El nodo se busca una vez y se guarda.
func _player_exclude() -> Array[RID]:
	if _player_body == null or not is_instance_valid(_player_body):
		_player_body = get_tree().get_first_node_in_group("player") as CollisionObject3D
	var exclude: Array[RID] = []
	if _player_body != null:
		exclude.append(_player_body.get_rid())
	return exclude


## Toma un nodo libre del pool o crea uno nuevo (solo la primera vez que hace falta).
## Devuelve null si no hay escena activa.
static func _pool_take(pool: Array[MeshInstance3D], scene: Node) -> MeshInstance3D:
	var node: MeshInstance3D = null
	while not pool.is_empty() and node == null:
		var raw: Variant = pool.pop_back()
		# Si cambió la escena, los nodos del pool pueden estar liberados; validar antes de tipar.
		if is_instance_valid(raw):
			var candidate := raw as MeshInstance3D
			if candidate != null and candidate.is_inside_tree():
				node = candidate
	if node == null:
		node = MeshInstance3D.new()
		node.top_level = true
		scene.add_child(node)
	node.visible = true
	return node


static func _pool_release(node: MeshInstance3D, pool: Array[MeshInstance3D]) -> void:
	if is_instance_valid(node) and not pool.has(node):
		node.visible = false
		pool.append(node)


func _setup_muzzle_flash() -> void:
	if _muzzle_mesh == null:
		_muzzle_mesh = QuadMesh.new()
		_muzzle_mesh.size = Vector2(0.24, 0.24)
	if _muzzle_material == null:
		_muzzle_material = ShaderMaterial.new()
		_muzzle_material.shader = MUZZLE_FLASH_SHADER
	_muzzle_flash = MeshInstance3D.new()
	_muzzle_flash.mesh = _muzzle_mesh
	_muzzle_flash.material_override = _muzzle_material
	var muzzle_node := get_node_or_null("Muzzle") as Node3D
	_muzzle_flash.position = muzzle_node.position if muzzle_node != null else muzzle_offset
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)


func _show_muzzle_flash() -> void:
	if _muzzle_flash == null:
		return
	_muzzle_flash.visible = true
	_muzzle_flash.rotation.z = randf() * TAU
	_muzzle_flash.scale = Vector3.ONE * randf_range(0.85, 1.2)
	_muzzle_left = MUZZLE_FLASH_DURATION


func _acquire_impact(pos: Vector3, normal: Vector3) -> MeshInstance3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	if _impact_mesh == null:
		_impact_mesh = SphereMesh.new()
		_impact_mesh.radius = 0.05
		_impact_mesh.height = 0.1
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.25, 0.1)
		# Visible aunque el punto quede dentro del cuerpo del enemigo (golpes melee).
		mat.no_depth_test = true
		_impact_mesh.material = mat
	var node := _pool_take(_impact_pool, scene)
	node.mesh = _impact_mesh
	node.scale = Vector3.ONE
	node.global_position = pos + normal * 0.02
	return node


func _spawn_impact(pos: Vector3, normal: Vector3, scale_mult: float = 1.0) -> void:
	var node := _acquire_impact(pos, normal)
	if node != null:
		node.scale = Vector3.ONE * scale_mult
		get_tree().create_timer(IMPACT_DURATION).timeout.connect(
			Weapon._pool_release.bind(node, _impact_pool)
		)


func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	_HITSCAN_TRACER.spawn(get_tree(), from_pos, to_pos)


## Dibuja una vez, frente a la cámara, cada efecto del arma para que sus shaders se compilen
## al cargar y no en el primer disparo. Las subclases añaden sus propios efectos.
func prewarm() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var pos: Vector3 = camera.global_position - camera.global_basis.z * 0.5
	var impact := _acquire_impact(pos, Vector3.ZERO)
	if _muzzle_flash != null:
		_muzzle_flash.visible = true
	await _HITSCAN_TRACER.prewarm(get_tree())
	_pool_release(impact, _impact_pool)
	if is_instance_valid(_muzzle_flash):
		_muzzle_flash.visible = false
