class_name EnemyAbility
extends Node
## Base de las habilidades de enemigo.
## Las llama `Enemy.step_physics()`; no tienen _physics_process propio.

var enemy: Enemy
var cfg: AbilityData


func setup(owner_enemy: Enemy, ability_data: AbilityData) -> void:
	enemy = owner_enemy
	cfg = ability_data
	_on_setup()


## Se ejecuta antes del escalado por ronda; puede modificar `enemy.speed_scale`, etc.
func _on_setup() -> void:
	pass


## Devuelve true si la habilidad controla el movimiento este frame (el enemigo no persigue).
func step(_delta: float, _player: Node3D) -> bool:
	return false


## Filtra el daño recibido (blindado frontal). Devolver 0 anula el golpe.
## `ignore_armor` = el golpe atraviesa blindajes (p. ej. La Espada en Llamas).
func modify_damage(amount: float, _ignore_armor: bool = false) -> float:
	return amount


func _flat_distance(player: Node3D) -> float:
	var diff: Vector3 = player.global_position - enemy.global_position
	diff.y = 0.0
	return diff.length()


func _damage_player(player: Node3D, base_damage: float) -> void:
	if player != null and player.has_method("take_damage"):
		player.call(
			"take_damage", base_damage * enemy.get_damage_multiplier(), enemy.global_position
		)
