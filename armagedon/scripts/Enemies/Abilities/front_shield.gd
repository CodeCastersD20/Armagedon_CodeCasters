class_name FrontShield
extends EnemyAbility
## Blindado frontal (#10): solo recibe daño por la espalda (arco `arc_degrees`). Gira lento
## (`turn_speed`) para poder rodearlo. Los golpes que atraviesan blindaje (La Espada en Llamas)
## le dañan por cualquier lado.


func _on_setup() -> void:
	enemy.turn_speed = cfg.turn_speed


func modify_damage(amount: float, ignore_armor: bool = false) -> float:
	if ignore_armor:
		return amount
	var player: Node3D = enemy.get_player()
	if player == null:
		return amount
	var to_player: Vector3 = player.global_position - enemy.global_position
	to_player.y = 0.0
	var forward: Vector3 = -enemy.global_basis.z
	forward.y = 0.0
	if to_player.length_squared() < 0.0001 or forward.length_squared() < 0.0001:
		return amount
	var rear_limit: float = cos(deg_to_rad(180.0 - cfg.arc_degrees * 0.5))
	if forward.normalized().dot(to_player.normalized()) <= rear_limit:
		return amount
	return 0.0
