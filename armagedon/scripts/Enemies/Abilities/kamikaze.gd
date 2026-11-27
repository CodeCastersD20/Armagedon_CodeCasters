class_name Kamikaze
extends EnemyAbility
## Kamikaze (#9): corre más rápido y explota al llegar. Su explosión daña a otros enemigos
## con `enemy_damage_factor` del daño al jugador.


func _on_setup() -> void:
	enemy.speed_scale *= cfg.speed_multiplier


func step(_delta: float, player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if _flat_distance(player) > enemy.data.contact_range:
		return false
	_explode(player)
	return true


func _explode(player: Node3D) -> void:
	var damage: float = cfg.damage * enemy.get_damage_multiplier()
	var origin: Vector3 = enemy.global_position
	ExplosionFx.spawn(enemy.get_tree(), origin, cfg.radius)
	if origin.distance_to(player.global_position) <= cfg.radius:
		if player.has_method("take_damage"):
			player.call("take_damage", damage, origin)
		_push_player(player, origin)
	for other: Node in enemy.get_tree().get_nodes_in_group("enemies"):
		var victim := other as Enemy
		if victim == null or victim == enemy or victim.is_dead():
			continue
		if origin.distance_to(victim.global_position) <= cfg.radius:
			victim.take_damage(damage * cfg.enemy_damage_factor)
	enemy.die()


func _push_player(player: Node3D, origin: Vector3) -> void:
	var away: Vector3 = player.global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = player.global_basis.z
		away.y = 0.0
	if cfg.knockback_speed > 0.0 and player.has_method("apply_knockback"):
		player.call("apply_knockback", away.normalized() * cfg.knockback_speed)
	if cfg.camera_shake_strength > 0.0 and player.has_method("add_camera_shake"):
		player.call("add_camera_shake", cfg.camera_shake_strength, cfg.camera_shake_duration)
