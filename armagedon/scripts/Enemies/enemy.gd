class_name Enemy
extends CharacterBody3D
## Enemigo base: persigue a Zahariel y daña al contacto. Stats escalados por ronda (GDD §7, §9).

signal died(enemy: Node)
signal health_changed(current: float, maximum: float)

const MIN_SPAWN_SEPARATION: float = 0.85
const NAV_UPDATE_INTERVAL: float = 0.15
const _ENEMY_MANAGER = preload("res://scripts/Enemies/enemy_manager.gd")
const _BONE_PIECE := preload("res://scripts/Enemies/bone_piece.gd")
const _ENEMY_GIB := preload("res://scripts/Enemies/enemy_gib.gd")

@export var data: EnemyData
## Ronda usada para el escalado inicial de stats (GDD §9).
@export var start_round: int = 1
@export var use_psx_style: bool = true
@export var attack_stop_distance: float = 0.0

var _health: float = 0.0
var _max_health: float = 0.0
var _move_speed: float = 0.0
var _contact_damage: float = 0.0
var _contact_timer: float = 0.0
var _nav_timer: float = 0.0
var _cached_nav_dir: Vector3 = Vector3.ZERO
var _player: Node3D
var _dead: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")


func _ready() -> void:
	add_to_group("enemies")
	set_physics_process(false)
	set_process(false)
	if use_psx_style:
		PsxStyle.apply(self)
	_resolve_spawn_overlap.call_deferred()
	_nav_timer = randf_range(0.0, NAV_UPDATE_INTERVAL)
	if data == null:
		push_error("Enemy sin EnemyData: %s" % name)
		return
	_player = get_tree().get_first_node_in_group("player") as Node3D
	apply_round_scaling(start_round)
	_health = _max_health
	health_changed.emit(_health, _max_health)
	_ENEMY_MANAGER.register(self)
	await get_tree().physics_frame
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _nav_agent != null and _player != null and is_instance_valid(_player):
		_nav_agent.target_position = _player.global_position


func _exit_tree() -> void:
	_ENEMY_MANAGER.unregister(self)


func step_physics(delta: float, player_node: Node3D, allow_nav: bool = true) -> void:
	if _dead or data == null:
		return
	_player = player_node
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)

	_contact_timer = maxf(_contact_timer - delta, 0.0)
	_nav_timer -= delta

	if _player != null and is_instance_valid(_player):
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		if attack_stop_distance > 0.0 and distance <= attack_stop_distance:
			velocity.x = 0.0
			velocity.z = 0.0
			if distance > 0.001:
				_look_toward_direction(to_player)
		else:
			var move_dir: Vector3 = _get_navigation_direction(to_player, distance, allow_nav)
			velocity.x = move_dir.x * _move_speed
			velocity.z = move_dir.z * _move_speed
			if move_dir.length_squared() > 0.0001:
				_look_toward_direction(move_dir)
			elif distance > 0.001:
				_look_toward_direction(to_player)
		_try_contact_damage(distance)
	else:
		velocity.x = move_toward(velocity.x, 0.0, _move_speed)
		velocity.z = move_toward(velocity.z, 0.0, _move_speed)

	move_and_slide()


func step_process(
	_delta: float,
	_cam_pos: Vector3 = Vector3.ZERO,
	_cam_forward: Vector3 = Vector3.FORWARD,
	_has_cam: bool = false,
) -> void:
	pass


## Aplica el escalado de stats por ronda (GDD §9): stat = base × (1 + 0.1 × (ronda − 1)).
# TODO(GDD): fórmula propuesta pendiente de confirmación (§366).
func apply_round_scaling(round_number: int) -> void:
	if data == null:
		return
	var r: int = maxi(round_number, 1)
	var multiplier: float = 1.0 + data.scaling_per_round * float(r - 1)
	_max_health = data.max_health * multiplier
	_contact_damage = data.contact_damage * multiplier
	_move_speed = data.move_speed * multiplier
	_health = minf(_health, _max_health) if _health > 0.0 else _max_health
	health_changed.emit(_health, _max_health)


func take_damage(amount: float, is_critical: bool = false) -> void:
	if _dead or amount <= 0.0 or data == null:
		return
	_health = maxf(_health - amount, 0.0)
	DamageNumber.spawn(
		get_tree(), global_position + Vector3.UP * data.damage_number_height, amount, is_critical
	)
	health_changed.emit(_health, _max_health)
	if _health <= 0.0:
		_die()


func get_health() -> float:
	return _health


func get_max_health() -> float:
	return _max_health


func is_dead() -> bool:
	return _dead


func _get_navigation_direction(
	to_player: Vector3, distance: float, allow_nav: bool = true
) -> Vector3:
	if distance <= 0.001:
		return Vector3.ZERO
	var fallback_dir: Vector3 = to_player / distance
	if distance < 4.0 or _nav_agent == null or _player == null or not is_instance_valid(_player):
		return fallback_dir
	if allow_nav and _nav_timer <= 0.0:
		_nav_timer = NAV_UPDATE_INTERVAL
		_nav_agent.target_position = _player.global_position
		if _nav_agent.is_navigation_finished():
			_cached_nav_dir = fallback_dir
		else:
			var next_pos: Vector3 = _nav_agent.get_next_path_position()
			var to_next: Vector3 = next_pos - global_position
			to_next.y = 0.0
			if to_next.length_squared() >= 0.0001:
				_cached_nav_dir = to_next.normalized()
			else:
				_cached_nav_dir = fallback_dir
	if _cached_nav_dir.length_squared() >= 0.0001:
		return _cached_nav_dir
	return fallback_dir


func _can_apply_contact_damage() -> bool:
	return true


func _try_contact_damage(distance: float) -> void:
	if _player == null or _contact_timer > 0.0 or data == null:
		return
	if distance > data.contact_range:
		return
	if not _can_apply_contact_damage():
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", _contact_damage, global_position)
		_contact_timer = data.contact_cooldown


func _look_toward_direction(direction: Vector3) -> void:
	var flat_dir: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat_dir.length_squared() < 0.0001:
		return
	var target: Vector3 = global_position + flat_dir.normalized()
	target.y = global_position.y
	look_at(target, Vector3.UP)


func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	# TODO(GDD): drops/reposición los gestiona el sistema de oleadas/spawner.
	if data != null:
		var burst_origin: Vector3 = global_position + Vector3.UP * (data.damage_number_height * 0.5)
		if data.death_explosion_type == EnemyData.DeathExplosionType.BONES:
			_BONE_PIECE.spawn_burst(
				get_tree(), burst_origin, data.bone_piece_count, data.bone_floor_lifetime
			)
			_ENEMY_GIB.spawn_burst(get_tree(), burst_origin, 10, [Color(0.86, 0.82, 0.70)])
		elif data.death_gib_count > 0:
			_ENEMY_GIB.spawn_burst(
				get_tree(), burst_origin, data.death_gib_count, data.death_gib_colors
			)
	visible = false
	_ENEMY_MANAGER.unregister(self)
	collision_layer = 0
	collision_mask = 0
	queue_free()


## Evita que dos enemigos queden superpuestos al spawnear en la misma coordenada
## (lo que provoca impulsos bruscos en move_and_slide).
func _resolve_spawn_overlap() -> void:
	var min_sq: float = MIN_SPAWN_SEPARATION * MIN_SPAWN_SEPARATION
	var others: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var has_overlap: bool = false
	for other in others:
		if other == self or not (other is Node3D):
			continue
		var diff: Vector3 = global_position - (other as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() < min_sq:
			has_overlap = true
			break
	if not has_overlap:
		return
	var step: float = MIN_SPAWN_SEPARATION + 0.15
	for ring in range(1, 6):
		var radius: float = step * float(ring)
		for slot in range(8):
			var angle: float = TAU * float(slot) / 8.0
			var candidate: Vector3 = (
				global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			)
			if _is_spot_clear(candidate, others, min_sq):
				global_position = candidate
				return


func _is_spot_clear(pos: Vector3, others: Array[Node], min_sq: float) -> bool:
	for other in others:
		if other == self or not (other is Node3D):
			continue
		var diff: Vector3 = pos - (other as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() < min_sq:
			return false
	return true
