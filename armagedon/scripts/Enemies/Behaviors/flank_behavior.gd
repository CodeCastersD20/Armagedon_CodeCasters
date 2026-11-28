class_name FlankBehavior
extends EnemyBehavior
## Flanqueador (como Inky): se abre hacia un costado del jugador y entra por el lado,
## así un grupo no llega en fila. Una vez comprometido, persigue hasta alejarse otra vez.

var _committed: bool = false


func get_target_point(_delta: float, player: Node3D) -> Vector3:
	var distance: float = _flat_distance(player)
	if _committed and distance > cfg.engage_distance * 2.5:
		_committed = false
	if _committed or distance <= cfg.engage_distance:
		_committed = true
		debug_mode = "engage"
		return player.global_position
	var away: Vector3 = _away_from(player)
	var flank_point: Vector3 = (
		player.global_position + _side_of(away) * cfg.flank_offset + away * cfg.flank_offset * 0.3
	)
	var to_point: Vector3 = flank_point - enemy.global_position
	to_point.y = 0.0
	if to_point.length() < 1.5:
		_committed = true
		debug_mode = "engage"
		return player.global_position
	debug_mode = "flank"
	return flank_point


## Ya tiene su propia ruta alrededor del jugador: no ocupa hueco en el cerco.
func allows_surround() -> bool:
	return false
