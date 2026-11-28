class_name EnemyBehavior
extends RefCounted
## Base de los comportamientos de movimiento de enemigo (GDD §7.2). La llama Enemy.step_physics():
## el comportamiento elige un punto objetivo y el Enemy navega hacia él (NavigationAgent3D).
## La base persigue directo al jugador.
## Las habilidades que controlan el movimiento tienen prioridad.

var enemy: Enemy
var cfg: BehaviorData
## Lado elegido al azar por instancia (-1 izquierda, 1 derecha): reparte a los enemigos.
var side: float = 1.0
## Qué está haciendo este frame (solo para el log de depuración, ver DebugLogger "MOVE").
var debug_mode: String = "chase"


func setup(owner_enemy: Enemy, behavior_data: BehaviorData) -> void:
	enemy = owner_enemy
	cfg = behavior_data
	side = -1.0 if randf() < 0.5 else 1.0
	_on_setup()


func _on_setup() -> void:
	pass


## Punto del mundo hacia el que se mueve este frame.
func get_target_point(_delta: float, player: Node3D) -> Vector3:
	debug_mode = "chase"
	return player.global_position


## Nombre corto del comportamiento para el log ("ambush", "kite"...).
func get_debug_name() -> String:
	var script: Script = get_script()
	if script == null:
		return "base"
	return script.resource_path.get_file().get_basename().trim_suffix("_behavior")


## Multiplicador de la velocidad de movimiento este frame.
func get_speed_multiplier() -> float:
	return cfg.speed_multiplier


## true = mira al jugador aunque se mueva en otra dirección (retrocede o se desplaza de lado).
func faces_player() -> bool:
	return false


## true = entra en el cerco de EnemyManager (se reparte alrededor del jugador cuando va directo).
## Los que ya tienen su propia ruta (kite, órbita, flanqueo) no ocupan hueco.
func allows_surround() -> bool:
	return true


## true = sigue su táctica aunque el jugador esté al alcance (huye o se retira).
func keeps_target_when_close() -> bool:
	return false


## El Enemy avisa cuando conecta un golpe por contacto.
func on_contact_attack() -> void:
	pass


## Dirección plana normalizada del jugador al enemigo.
func _away_from(player: Node3D) -> Vector3:
	var diff: Vector3 = enemy.global_position - player.global_position
	diff.y = 0.0
	if diff.length_squared() < 0.0001:
		return Vector3.FORWARD
	return diff.normalized()


func _flat_distance(player: Node3D) -> float:
	var diff: Vector3 = player.global_position - enemy.global_position
	diff.y = 0.0
	return diff.length()


## Perpendicular (en el plano) a `dir`, hacia el lado de esta instancia.
func _side_of(dir: Vector3) -> Vector3:
	return Vector3(-dir.z, 0.0, dir.x) * side
