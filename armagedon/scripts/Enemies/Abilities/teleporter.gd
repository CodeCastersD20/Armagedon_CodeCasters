class_name Teleporter
extends EnemyAbility
## Teleporte (#12): parpadea durante `windup` s y reaparece detrás del jugador.

const BEHIND_DISTANCE: float = 2.5
const ARENA_RADIUS: float = 23.0
const CENTER_HOLE_RADIUS: float = 6.0
const BLINK_INTERVAL: float = 0.1

var _cooldown_left: float = 0.0
var _windup_left: float = 0.0
var _winding_up: bool = false


func _on_setup() -> void:
	_cooldown_left = randf_range(0.0, cfg.cooldown)


func step(delta: float, player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _winding_up:
		_windup_left -= delta
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
		enemy.visible = int(_windup_left / BLINK_INTERVAL) % 2 == 0
		if _windup_left <= 0.0:
			_winding_up = false
			enemy.visible = true
			_cooldown_left = cfg.cooldown
			_teleport(player)
		return true
	_cooldown_left -= delta
	var distance: float = _flat_distance(player)
	if _cooldown_left <= 0.0 and distance >= cfg.radius and distance <= cfg.max_range:
		_winding_up = true
		_windup_left = cfg.windup
	return false


func _teleport(player: Node3D) -> void:
	var behind: Vector3 = player.global_basis.z
	behind.y = 0.0
	if behind.length_squared() < 0.0001:
		return
	var target: Vector3 = player.global_position + behind.normalized() * BEHIND_DISTANCE
	var flat := Vector2(target.x, target.z)
	if flat.length() > ARENA_RADIUS or flat.length() < CENTER_HOLE_RADIUS:
		return
	target.y = enemy.global_position.y
	enemy.global_position = target
	enemy.velocity = Vector3.ZERO
	enemy.trigger_ability_attack_anim(0.45)
