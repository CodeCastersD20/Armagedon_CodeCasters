class_name KiteBehavior
extends EnemyBehavior
## Mantener distancia (enemigos a distancia): si el jugador se acerca, huye en diagonal;
## si se aleja, se acerca; dentro de la banda preferida se desplaza de lado mirando al jugador.

var _switch_left: float = 0.0


func _on_setup() -> void:
	_switch_left = randf_range(cfg.strafe_switch_min, cfg.strafe_switch_max)


func get_target_point(delta: float, player: Node3D) -> Vector3:
	var distance: float = _flat_distance(player)
	var away: Vector3 = _away_from(player)
	if distance < cfg.preferred_min:
		debug_mode = "flee"
		return enemy.global_position + (away + _side_of(away) * 0.5) * cfg.flee_distance
	if distance > cfg.preferred_max:
		debug_mode = "approach"
		return player.global_position
	debug_mode = "strafe"
	_switch_left -= delta
	if _switch_left <= 0.0:
		side = -side
		_switch_left = randf_range(cfg.strafe_switch_min, cfg.strafe_switch_max)
	return enemy.global_position + _side_of(away) * 3.0


func get_speed_multiplier() -> float:
	var player: Node3D = enemy.get_player()
	if player != null and is_instance_valid(player):
		var distance: float = _flat_distance(player)
		if distance >= cfg.preferred_min and distance <= cfg.preferred_max:
			return cfg.speed_multiplier * cfg.strafe_speed_mult
	return cfg.speed_multiplier


func faces_player() -> bool:
	return true


func keeps_target_when_close() -> bool:
	return true


## Ya tiene su propia ruta alrededor del jugador: no ocupa hueco en el cerco.
func allows_surround() -> bool:
	return false
