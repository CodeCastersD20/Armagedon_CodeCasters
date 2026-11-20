class_name Enemy
extends CharacterBody3D
## Enemigo base: persigue a Zahariel y daña al contacto. Stats escalados por ronda (GDD §7, §9).

signal died(enemy: Node)
signal health_changed(current: float, maximum: float)

@export var data: EnemyData
## Ronda usada para el escalado inicial de stats (GDD §9).
@export var start_round: int = 1

var _health: float = 0.0
var _max_health: float = 0.0
var _move_speed: float = 0.0
var _contact_damage: float = 0.0
var _contact_timer: float = 0.0
var _player: Node3D
var _dead: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")


func _ready() -> void:
	add_to_group("enemies")
	PsxStyle.apply(self)
	if data == null:
		push_error("Enemy sin EnemyData: %s" % name)
		set_physics_process(false)
		return
	_player = get_tree().get_first_node_in_group("player") as Node3D
	apply_round_scaling(start_round)
	_health = _max_health
	health_changed.emit(_health, _max_health)
	await get_tree().physics_frame
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _nav_agent != null and _player != null and is_instance_valid(_player):
		_nav_agent.target_position = _player.global_position


func _physics_process(delta: float) -> void:
	if _dead or data == null:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	_contact_timer = maxf(_contact_timer - delta, 0.0)

	if _player != null and is_instance_valid(_player):
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		var move_dir: Vector3 = _get_navigation_direction(to_player, distance)
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


func _get_navigation_direction(to_player: Vector3, distance: float) -> Vector3:
	if distance <= 0.001:
		return Vector3.ZERO
	var fallback_dir: Vector3 = to_player / distance
	if _nav_agent == null or _player == null or not is_instance_valid(_player):
		return fallback_dir
	_nav_agent.target_position = _player.global_position
	if _nav_agent.is_navigation_finished():
		return fallback_dir
	var next_pos: Vector3 = _nav_agent.get_next_path_position()
	var to_next: Vector3 = next_pos - global_position
	to_next.y = 0.0
	if to_next.length_squared() < 0.0001:
		return fallback_dir
	return to_next.normalized()


func _try_contact_damage(distance: float) -> void:
	if _player == null or _contact_timer > 0.0 or data == null:
		return
	if distance > data.contact_range:
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
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	queue_free()
