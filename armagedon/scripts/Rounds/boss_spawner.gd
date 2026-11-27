class_name BossSpawner
extends Node
## Spawnea el jefe genérico en las rondas múltiplo de 10 (GDD §7, §9, §264-267).

signal boss_spawned(enemy: Enemy)
signal boss_health_changed(current: float, maximum: float)
signal boss_died(enemy: Node)

const BOSS_SCENES: Array[PackedScene] = [
	preload("res://scenes/Enemies/JefeSqueletor.tscn"),
	preload("res://scenes/Enemies/JefeDemonio.tscn"),
	preload("res://scenes/Enemies/JefeWrapped.tscn"),
]
const SPAWN_DISTANCE: float = 8.0
# TODO(GDD): puntos de aparición del arena y separación sin definir (§269).
const MIN_CLEARANCE: float = 3.0
const BOSS_ENTRANCE_FADE_SECONDS: float = 1.8
const CIRCLE_1_MAX_ROUND: int = 10

var _round_manager: RoundManager
var _boss: Enemy
var _last_boss_index: int = -1
var _spawn_request_id: int = 0


func _ready() -> void:
	add_to_group("boss_spawner")
	_connect_round_manager.call_deferred()


func _exit_tree() -> void:
	if _round_manager != null and _round_manager.round_started.is_connected(_on_round_started):
		_round_manager.round_started.disconnect(_on_round_started)


func _connect_round_manager() -> void:
	_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _round_manager == null:
		push_error("BossSpawner sin RoundManager")
		return
	_round_manager.round_started.connect(_on_round_started)


func _on_round_started(round_number: int, is_boss_round: bool) -> void:
	if round_number <= 1:
		_last_boss_index = -1
	if not is_boss_round or _round_manager == null:
		return
	if round_number >= _round_manager.config.lucifer_round:
		return
	if is_instance_valid(_boss) and not _boss.is_dead():
		return
	var boss_index: int = _pick_boss_index()
	if boss_index < 0:
		return
	_spawn_request_id += 1
	var request_id: int = _spawn_request_id
	var is_circle_1: bool = round_number <= CIRCLE_1_MAX_ROUND
	if is_circle_1:
		AudioManager.fade_out_music(BOSS_ENTRANCE_FADE_SECONDS)
		await get_tree().create_timer(BOSS_ENTRANCE_FADE_SECONDS).timeout
		if not is_inside_tree() or request_id != _spawn_request_id:
			return
		if (
			_round_manager == null
			or _round_manager.current_state != RoundManager.State.ROUND
			or _round_manager.current_round != round_number
		):
			return
	_spawn_boss(boss_index, round_number, is_circle_1)


func _spawn_boss(boss_index: int, round_number: int, is_circle_1: bool) -> void:
	var boss: Enemy = BOSS_SCENES[boss_index].instantiate() as Enemy
	if boss == null:
		push_error("BossSpawner: escena de jefe inválida en la ronda %d" % round_number)
		return
	_last_boss_index = boss_index
	boss.start_round = round_number
	boss.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_boss_died)
	add_child(boss)
	boss.set_spawn_position(_find_spawn_point(boss))
	DebugLogger.log_spawn("BossSpawner", boss, boss.global_position, round_number)
	_boss = boss
	_on_boss_health_changed(boss.get_health(), boss.get_max_health())
	if is_circle_1:
		AudioManager.play_boss_limbo_music()
	boss_spawned.emit(boss)


func _pick_boss_index() -> int:
	var count: int = BOSS_SCENES.size()
	if count <= 0:
		push_error("BossSpawner: no hay escenas de jefe configuradas")
		return -1
	if count == 1:
		return 0
	if _last_boss_index < 0:
		return randi_range(0, count - 1)
	var index: int = randi_range(0, count - 2)
	if index >= _last_boss_index:
		index += 1
	return index


func _find_spawn_point(boss: Enemy) -> Vector3:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var origin: Vector3 = player.global_position if player != null else Vector3.ZERO
	var forward: Vector3 = -player.global_basis.z if player != null else -Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = -Vector3.FORWARD
	forward = forward.normalized()
	var desired: Vector3 = origin + forward * SPAWN_DISTANCE
	var occupied: Array[Node] = []
	if player != null:
		occupied.append(player)
	for other: Node in get_tree().get_nodes_in_group("enemies"):
		if other is Node3D and other != boss:
			occupied.append(other)
	var clearance: float = MIN_CLEARANCE + _get_body_radius(boss)
	var avoid_center: bool = _has_center_hole()
	if _is_spot_clear(desired, occupied, clearance, avoid_center):
		return desired
	for ring in range(1, 8):
		var radius: float = clearance * float(ring)
		for slot in range(8):
			var angle: float = TAU * float(slot) / 8.0
			var candidate: Vector3 = (
				desired + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			)
			if _is_spot_clear(candidate, occupied, clearance, avoid_center):
				return candidate
	return desired


func _has_center_hole() -> bool:
	var scene: Node = get_tree().current_scene
	return scene != null and scene.find_child("HuecoCentral", true, false) != null


func _get_body_radius(boss: Enemy) -> float:
	var shape_node: CollisionShape3D = boss.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	return 0.0


func _is_spot_clear(
	pos: Vector3, occupied: Array[Node], clearance: float, avoid_center: bool = false
) -> bool:
	if (
		avoid_center
		and (
			Vector2(pos.x, pos.z).length_squared()
			< Enemy.CENTER_HOLE_RADIUS * Enemy.CENTER_HOLE_RADIUS
		)
	):
		return false
	var min_sq: float = clearance * clearance
	for other in occupied:
		if not is_instance_valid(other) or not (other is Node3D):
			continue
		var diff: Vector3 = pos - (other as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() < min_sq:
			return false
	return true


func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_health_changed.emit(current, maximum)


func _on_boss_died(enemy: Node) -> void:
	if enemy != _boss:
		return
	AudioManager.fade_out_music(1.5)
	boss_died.emit(enemy)
	_clear_boss()


func _clear_boss() -> void:
	if _boss != null:
		if _boss.health_changed.is_connected(_on_boss_health_changed):
			_boss.health_changed.disconnect(_on_boss_health_changed)
		if _boss.died.is_connected(_on_boss_died):
			_boss.died.disconnect(_on_boss_died)
	_boss = null
