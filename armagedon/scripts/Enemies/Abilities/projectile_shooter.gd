class_name ProjectileShooter
extends EnemyAbility
## Dispara proyectiles al jugador según el AbilityData: recto (Tirador #2), en abanico de varios
## proyectiles sin gravedad (Artillero #7, projectile_count > 1), o en arco con gravedad y zona de
## creep (Lanzador de creep #8, gravity > 0 y leaves_creep).

const MUZZLE_HEIGHT: float = 1.4
const TARGET_HEIGHT: float = 1.0

var _cooldown_left: float = 0.0
var _windup_left: float = 0.0
var _winding_up: bool = false
var _vertical_fan: bool = false
var _burst_queue: Array[Vector3] = []
var _burst_timer: float = 0.0


func _on_setup() -> void:
	_cooldown_left = randf_range(0.0, cfg.cooldown)


func step(delta: float, player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not _burst_queue.is_empty():
		return _step_burst(delta, player)
	if _winding_up:
		return _step_windup(delta, player)
	_cooldown_left -= delta
	if _cooldown_left <= 0.0 and _flat_distance(player) <= cfg.max_range:
		if cfg.windup > 0.0:
			_winding_up = true
			_windup_left = cfg.windup
		else:
			_cooldown_left = cfg.cooldown
			_fire(player)
	return false


## Aviso previo al disparo: el enemigo se detiene y mira al jugador.
func _step_windup(delta: float, player: Node3D) -> bool:
	_windup_left -= delta
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.face_direction(player.global_position - enemy.global_position)
	if _windup_left <= 0.0:
		_winding_up = false
		_cooldown_left = cfg.cooldown
		_fire(player)
	return true


func _fire(player: Node3D) -> void:
	enemy.trigger_ability_attack_anim(0.45)
	var from: Vector3 = enemy.global_position + Vector3.UP * MUZZLE_HEIGHT
	var target: Vector3 = player.global_position + Vector3.UP * TARGET_HEIGHT
	var speed: float = maxf(cfg.projectile_speed, 0.1)
	var damage: float = cfg.damage * enemy.get_damage_multiplier()
	var tree: SceneTree = enemy.get_tree()
	if cfg.gravity > 0.0:
		EnemyProjectile.launch(
			tree, from, _ballistic_velocity(from, target, speed), cfg, damage, player
		)
		return
	var aim: Vector3 = (target - from).normalized()
	var count: int = maxi(cfg.projectile_count, 1)
	if count == 1:
		EnemyProjectile.launch(tree, from, aim * speed, cfg, damage, player)
		return
	var axis: Vector3 = Vector3.UP
	if _vertical_fan:
		axis = aim.cross(Vector3.UP).normalized()
		if axis.length_squared() < 0.0001:
			axis = Vector3.RIGHT
	if cfg.alternate_fan:
		_vertical_fan = not _vertical_fan
	var half: float = deg_to_rad(cfg.spread_degrees) * 0.5
	for i in count:
		var t: float = float(i) / float(count - 1)
		_burst_queue.append(aim.rotated(axis, lerpf(-half, half, t)) * speed)
	_burst_timer = 0.0
	if cfg.burst_interval <= 0.0:
		while not _burst_queue.is_empty():
			_launch_next(player)


## Lanza los proyectiles del abanico uno tras otro; el enemigo se queda quieto mientras dura.
func _step_burst(delta: float, player: Node3D) -> bool:
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.face_direction(player.global_position - enemy.global_position)
	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_launch_next(player)
		_burst_timer = cfg.burst_interval
	return true


func _launch_next(player: Node3D) -> void:
	if _burst_queue.is_empty():
		return
	enemy.trigger_ability_attack_anim(0.35)
	var velocity: Vector3 = _burst_queue.pop_front()
	var from: Vector3 = enemy.global_position + Vector3.UP * MUZZLE_HEIGHT
	var damage: float = cfg.damage * enemy.get_damage_multiplier()
	EnemyProjectile.launch(enemy.get_tree(), from, velocity, cfg, damage, player)


func _ballistic_velocity(from: Vector3, target: Vector3, speed: float) -> Vector3:
	var flat: Vector3 = target - from
	flat.y = 0.0
	var flight_time: float = maxf(flat.length() / speed, 0.2)
	var vy: float = (
		(target.y - from.y + 0.5 * cfg.gravity * flight_time * flight_time) / flight_time
	)
	var velocity: Vector3 = flat.normalized() * speed
	velocity.y = vy
	return velocity
