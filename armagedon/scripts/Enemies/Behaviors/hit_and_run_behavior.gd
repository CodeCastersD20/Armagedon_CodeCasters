class_name HitAndRunBehavior
extends EnemyBehavior
## Golpear y retirarse (inspirado en Clyde, que se aparta al acercarse): persigue, y tras
## conectar un golpe se aleja un rato antes de volver a entrar.

var _retreat_left: float = 0.0


func get_target_point(delta: float, player: Node3D) -> Vector3:
	if _retreat_left > 0.0:
		_retreat_left -= delta
		debug_mode = "retreat"
		var away: Vector3 = _away_from(player)
		return enemy.global_position + (away + _side_of(away) * 0.4) * cfg.retreat_distance
	debug_mode = "chase"
	return player.global_position


func get_speed_multiplier() -> float:
	if _retreat_left > 0.0:
		return cfg.speed_multiplier * cfg.retreat_speed_mult
	return cfg.speed_multiplier


func keeps_target_when_close() -> bool:
	return _retreat_left > 0.0


func on_contact_attack() -> void:
	_retreat_left = cfg.retreat_seconds
