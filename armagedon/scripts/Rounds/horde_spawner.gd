class_name HordeSpawner
extends Node
## Mantiene la horda de la ronda (GDD §9): repone enemigos hasta `target_count`.
## Elige el tipo por ronda, variantes con habilidad y campeones.

const FALLBACK_SPAWN_RADIUS: float = 22.0
const SPAWN_JITTER: float = 1.5
const MIN_SPAWN_CLEARANCE: float = 1.5

@export var enabled: bool = true
@export var config: HordeConfig

var _round_manager: RoundManager
var _spawn_points: Array[Node3D] = []
## Sin tipar: pueden contener instancias ya liberadas (se comprueban con is_instance_valid).
var _alive: Array = []
var _round: int = 0
var _active: bool = false
var _pending: int = 0
var _avoid_center_hole: bool = false


func _ready() -> void:
	if not enabled:
		return
	if config == null:
		push_error("HordeSpawner sin HordeConfig: desactivado")
		return
	_connect_round_manager.call_deferred()


func _connect_round_manager() -> void:
	_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _round_manager == null:
		push_error("HordeSpawner sin RoundManager")
		return
	_round_manager.round_started.connect(_on_round_started)
	_round_manager.rest_started.connect(_on_round_over)
	_round_manager.escape_started.connect(_on_round_over)
	_round_manager.state_changed.connect(_on_state_changed)
	var scene: Node = get_tree().current_scene
	_avoid_center_hole = scene != null and scene.find_child("HuecoCentral", true, false) != null
	var points_root: Node = scene.find_child("SpawnPoints", true, false) if scene != null else null
	if points_root != null:
		for child in points_root.get_children():
			if child is Node3D:
				_spawn_points.append(child as Node3D)


func _on_round_started(round_number: int, _is_boss: bool) -> void:
	_clear_horde()
	_round = round_number
	_active = true
	_fill()


func _on_round_over(_round_number: int) -> void:
	_active = false
	_clear_horde()


func _on_state_changed(new_state: RoundManager.State, _old_state: RoundManager.State) -> void:
	if new_state == RoundManager.State.IDLE:
		_active = false
		_clear_horde()


func _clear_horde() -> void:
	_pending = 0
	for raw in _alive:
		if is_instance_valid(raw) and not (raw as Enemy).is_dead():
			(raw as Enemy).queue_free()
	_alive.clear()


func _fill() -> void:
	_prune_alive()
	var missing: int = config.target_count - _alive.size() - _pending
	for i in maxi(missing, 0):
		_spawn_one()


## Quita de `_alive` los enemigos liberados o muertos (sin tipar: pueden estar liberados).
func _prune_alive() -> void:
	for i in range(_alive.size() - 1, -1, -1):
		var raw: Variant = _alive[i]
		if not is_instance_valid(raw) or (raw as Enemy).is_dead():
			_alive.remove_at(i)


func _spawn_one() -> void:
	if not _active:
		return
	if get_tree().get_nodes_in_group("enemies").size() >= config.hard_cap:
		return
	var entry: HordeEntry = _pick_entry()
	if entry == null or entry.scene == null:
		return
	var enemy: Enemy = entry.scene.instantiate() as Enemy
	if enemy == null:
		push_error("HordeSpawner: escena de horda no es un Enemy")
		return
	enemy.start_round = _round
	var variant: HordeVariant = _pick_variant(entry)
	if variant != null:
		enemy.data = variant.data
	if _should_be_champion():
		enemy.champion_data = config.champion
	enemy.died.connect(_on_enemy_died)
	get_tree().current_scene.add_child(enemy)
	enemy.set_spawn_position(_pick_spawn_position())
	DebugLogger.log_spawn("HordeSpawner", enemy, enemy.global_position, _round)
	_alive.append(enemy)


func _pick_entry() -> HordeEntry:
	var total: float = 0.0
	for entry in config.entries:
		if entry != null and entry.min_round <= _round:
			total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for entry in config.entries:
		if entry == null or entry.min_round > _round:
			continue
		roll -= maxf(entry.weight, 0.0)
		if roll <= 0.0:
			return entry
	return null


func _pick_variant(entry: HordeEntry) -> HordeVariant:
	if randf() >= config.variant_chance or _count_variants() >= config.max_variants:
		return null
	var total: float = 0.0
	for variant in entry.variants:
		if variant != null and variant.data != null and variant.min_round <= _round:
			total += maxf(variant.weight, 0.0)
	if total <= 0.0:
		return null
	var roll: float = randf() * total
	for variant in entry.variants:
		if variant == null or variant.data == null or variant.min_round > _round:
			continue
		roll -= maxf(variant.weight, 0.0)
		if roll <= 0.0:
			return variant
	return null


func _count_variants() -> int:
	var count: int = 0
	for raw in _alive:
		if not is_instance_valid(raw):
			continue
		var enemy := raw as Enemy
		if not enemy.is_dead() and enemy.data.ability_script != null:
			count += 1
	return count


func _should_be_champion() -> bool:
	var champion: ChampionData = config.champion
	if champion == null or _round < champion.min_round or randf() >= champion.spawn_chance:
		return false
	var count: int = 0
	for raw in _alive:
		if not is_instance_valid(raw):
			continue
		var enemy := raw as Enemy
		if not enemy.is_dead() and enemy.champion_data != null:
			count += 1
	return count < champion.max_simultaneous


func _pick_spawn_position() -> Vector3:
	var base: Vector3
	if _spawn_points.is_empty():
		var angle: float = randf() * TAU
		base = Vector3(cos(angle), 0.0, sin(angle)) * FALLBACK_SPAWN_RADIUS
	else:
		base = _spawn_points[randi() % _spawn_points.size()].global_position
	var occupied: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var candidate: Vector3 = base
	for attempt in 8:
		candidate = (
			base
			+ Vector3(
				randf_range(-SPAWN_JITTER, SPAWN_JITTER),
				0.0,
				randf_range(-SPAWN_JITTER, SPAWN_JITTER)
			)
		)
		if _is_clear(candidate, occupied):
			break
	return candidate


func _is_clear(pos: Vector3, occupied: Array[Node]) -> bool:
	if (
		_avoid_center_hole
		and (
			Vector2(pos.x, pos.z).length_squared()
			< Enemy.CENTER_HOLE_RADIUS * Enemy.CENTER_HOLE_RADIUS
		)
	):
		return false
	var min_sq: float = MIN_SPAWN_CLEARANCE * MIN_SPAWN_CLEARANCE
	for other in occupied:
		if other is Node3D:
			var diff: Vector3 = pos - (other as Node3D).global_position
			diff.y = 0.0
			if diff.length_squared() < min_sq:
				return false
	return true


func _on_enemy_died(enemy: Node) -> void:
	_alive.erase(enemy)
	if not _active:
		return
	_pending += 1
	await get_tree().create_timer(config.respawn_delay).timeout
	_pending = maxi(_pending - 1, 0)
	if _active and is_inside_tree():
		_spawn_one()
