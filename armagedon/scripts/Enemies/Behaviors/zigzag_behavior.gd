class_name ZigzagBehavior
extends EnemyBehavior
## Zigzag: avanza hacia el jugador serpenteando de lado a lado para ser difícil de apuntar.

var _time: float = 0.0


func _on_setup() -> void:
	_time = randf() * 10.0


func get_target_point(delta: float, player: Node3D) -> Vector3:
	_time += delta
	if _flat_distance(player) <= cfg.engage_distance:
		debug_mode = "engage"
		return player.global_position
	debug_mode = "zigzag"
	var toward: Vector3 = -_away_from(player)
	var lateral: float = sin(_time * cfg.zigzag_frequency * TAU) * cfg.zigzag_amplitude
	return enemy.global_position + toward * 3.0 + _side_of(toward) * lateral
