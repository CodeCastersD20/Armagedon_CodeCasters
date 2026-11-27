class_name Summoner
extends EnemyAbility
## Invocador (#5): genera 2-4 mini enemigos más débiles y rápidos al atacar.
## Solo una tanda a la vez: no invoca mientras queden minis suyos vivos.

const HARD_CAP: int = 30
const RING_RADIUS: float = 1.6

var _cooldown_left: float = 0.0
var _minis: Array[Enemy] = []


func _on_setup() -> void:
	_cooldown_left = cfg.cooldown * 0.5


func step(delta: float, player: Node3D) -> bool:
	if player == null or not is_instance_valid(player) or cfg.summon_scene == null:
		return false
	_cooldown_left -= delta
	if _cooldown_left > 0.0 or _flat_distance(player) > cfg.max_range:
		return false
	if _has_living_minis():
		return false
	_cooldown_left = cfg.cooldown
	enemy.trigger_ability_attack_anim(0.55)
	var tree: SceneTree = enemy.get_tree()
	var alive: int = tree.get_nodes_in_group("enemies").size()
	var wanted: int = randi_range(cfg.count_min, maxi(cfg.count_min, cfg.count_max))
	var parent: Node = enemy.get_parent()
	for i in mini(wanted, maxi(HARD_CAP - alive, 0)):
		var mini_enemy: Enemy = cfg.summon_scene.instantiate() as Enemy
		if mini_enemy == null:
			push_error("Summoner: summon_scene no es un Enemy")
			return false
		mini_enemy.start_round = enemy.start_round
		mini_enemy.health_scale = cfg.summon_health_factor
		mini_enemy.damage_scale = cfg.summon_damage_factor
		mini_enemy.speed_scale = cfg.summon_speed_factor
		mini_enemy.visual_scale = cfg.summon_scale
		mini_enemy.contact_cooldown_scale = cfg.summon_attack_cooldown_factor
		parent.add_child(mini_enemy)
		_minis.append(mini_enemy)
		mini_enemy.add_to_group("summoned")
		var angle: float = TAU * float(i) / float(maxi(wanted, 1))
		mini_enemy.set_spawn_position(
			enemy.global_position + Vector3(cos(angle), 0.3, sin(angle)) * RING_RADIUS
		)
		DebugLogger.log_spawn("Summoner", mini_enemy, mini_enemy.global_position, enemy.start_round)
	return false


func _has_living_minis() -> bool:
	# Se recorre a mano: una lambda tipada falla al recibir instancias ya liberadas.
	for i in range(_minis.size() - 1, -1, -1):
		var raw: Variant = _minis[i]
		if not is_instance_valid(raw) or (raw as Enemy).is_dead():
			_minis.remove_at(i)
	return not _minis.is_empty()
