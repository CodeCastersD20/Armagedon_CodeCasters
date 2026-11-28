class_name OrbitBehavior
extends EnemyBehavior
## Órbita: rodea al jugador y cierra en espiral; al llegar ataca y vuelve a abrir el radio.

var _angle: float = 0.0
var _radius: float = 0.0


func _on_setup() -> void:
	_radius = cfg.orbit_radius


func get_target_point(delta: float, player: Node3D) -> Vector3:
	var away: Vector3 = _away_from(player)
	if _radius <= cfg.engage_distance:
		debug_mode = "engage"
		return player.global_position
	debug_mode = "orbit"
	_angle = atan2(away.z, away.x) + side * 0.6
	_radius = maxf(_radius - cfg.orbit_shrink_speed * delta, cfg.engage_distance)
	return player.global_position + Vector3(cos(_angle), 0.0, sin(_angle)) * _radius


func on_contact_attack() -> void:
	_radius = cfg.orbit_radius
	side = -side


## Ya tiene su propia ruta alrededor del jugador: no ocupa hueco en el cerco.
func allows_surround() -> bool:
	return false
