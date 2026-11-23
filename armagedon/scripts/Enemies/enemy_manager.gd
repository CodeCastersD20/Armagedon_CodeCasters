class_name EnemyManager
extends Node
## Centraliza la simulación de todos los enemigos activos en un único _physics_process y _process:
## - Resuelve _player y _camera una sola vez por frame.
## - Presupuesto de pathfinding por frame (máx. MAX_NAV_UPDATES_PER_FRAME).
## - Física escalonada a mitad de tasa para enemigos lejanos (> 16 m).
## - Culling de animación para enemigos detrás de la cámara.

const MAX_NAV_UPDATES_PER_FRAME: int = 10
const FAR_PHYSICS_DIST_SQ: float = 256.0

static var _instance: EnemyManager

var _enemies: Array[Node] = []
var _player: Node3D
var _camera: Camera3D
var _physics_tick: int = 0
var _nav_cursor: int = 0


static func register(enemy: Node) -> void:
	if enemy == null or not enemy.is_inside_tree():
		return
	var mgr: EnemyManager = _get_or_create(enemy.get_tree())
	if mgr != null and not mgr._enemies.has(enemy):
		mgr._enemies.append(enemy)


static func unregister(enemy: Node) -> void:
	if _instance == null or enemy == null:
		return
	var idx: int = _instance._enemies.find(enemy)
	if idx >= 0:
		var last: int = _instance._enemies.size() - 1
		if idx != last:
			_instance._enemies[idx] = _instance._enemies[last]
		_instance._enemies.pop_back()


static func _get_or_create(tree: SceneTree) -> EnemyManager:
	if is_instance_valid(_instance) and not _instance.is_queued_for_deletion():
		return _instance
	if tree == null or tree.current_scene == null:
		return null
	var created := EnemyManager.new()
	created.name = "EnemyManager"
	_instance = created
	tree.current_scene.add_child.call_deferred(created)
	return created


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _physics_process(delta: float) -> void:
	if _enemies.is_empty():
		return
	_physics_tick += 1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	var has_player: bool = _player != null and is_instance_valid(_player)
	var player_pos: Vector3 = _player.global_position if has_player else Vector3.ZERO
	var nav_budget: int = MAX_NAV_UPDATES_PER_FRAME
	var count: int = _enemies.size()
	if _nav_cursor >= count:
		_nav_cursor = 0

	var i: int = count - 1
	while i >= 0:
		var enemy: Node = _enemies[i]
		if enemy == null or not is_instance_valid(enemy) or enemy.call("is_dead"):
			unregister(enemy)
			i -= 1
			continue

		var is_far: bool = false
		if has_player:
			var dist_sq: float = (enemy as Node3D).global_position.distance_squared_to(player_pos)
			is_far = dist_sq > FAR_PHYSICS_DIST_SQ

		if is_far and ((i + _physics_tick) & 1) != 0:
			i -= 1
			continue

		var step_delta: float = delta * 2.0 if is_far else delta
		var allow_nav: bool = false
		if nav_budget > 0 and ((i - _nav_cursor + count) % count) < MAX_NAV_UPDATES_PER_FRAME:
			allow_nav = true
			nav_budget -= 1

		enemy.call("step_physics", step_delta, _player, allow_nav)
		i -= 1

	if count > 0:
		_nav_cursor = (_nav_cursor + MAX_NAV_UPDATES_PER_FRAME) % count


func _process(delta: float) -> void:
	if _enemies.is_empty():
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		_camera = viewport.get_camera_3d()
	var has_cam: bool = _camera != null and is_instance_valid(_camera)
	var cam_pos: Vector3 = _camera.global_position if has_cam else Vector3.ZERO
	var cam_forward: Vector3 = -_camera.global_basis.z if has_cam else Vector3.FORWARD

	var i: int = _enemies.size() - 1
	while i >= 0:
		var enemy: Node = _enemies[i]
		if enemy != null and is_instance_valid(enemy) and not enemy.call("is_dead"):
			enemy.call("step_process", delta, cam_pos, cam_forward, has_cam)
		i -= 1
