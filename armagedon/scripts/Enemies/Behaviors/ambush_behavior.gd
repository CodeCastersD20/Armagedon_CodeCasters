class_name AmbushBehavior
extends EnemyBehavior
## Emboscador (como Pinky): apunta a un punto por delante del jugador para cortarle el paso,
## según hacia dónde se MUEVE (velocidad). Si el jugador está quieto, si el enemigo ya está más
## cerca que ese punto o si llega a él, va directo al jugador.
## (Antes usaba hacia dónde miraba el jugador estando quieto: el enemigo seguía la mira y rondaba
## a `lead_distance` sin atacar nunca.)

## Velocidad mínima (m/s) del jugador para emboscar; por debajo se considera quieto.
const MIN_PLAYER_SPEED: float = 0.5
## Metros al punto de emboscada a partir de los que deja de emboscar y ataca.
const REACHED_POINT: float = 1.5


func get_target_point(_delta: float, player: Node3D) -> Vector3:
	var distance: float = _flat_distance(player)
	if distance <= maxf(cfg.engage_distance, cfg.lead_distance):
		debug_mode = "engage"
		return player.global_position
	var body := player as CharacterBody3D
	var ahead: Vector3 = Vector3.ZERO
	if body != null:
		ahead = Vector3(body.velocity.x, 0.0, body.velocity.z)
	if ahead.length_squared() < MIN_PLAYER_SPEED * MIN_PLAYER_SPEED:
		debug_mode = "chase_quieto"
		return player.global_position
	var point: Vector3 = player.global_position + ahead.normalized() * cfg.lead_distance
	var to_point: Vector3 = point - enemy.global_position
	to_point.y = 0.0
	if to_point.length() < REACHED_POINT:
		debug_mode = "engage"
		return player.global_position
	debug_mode = "ambush"
	return point
