class_name Enemy
extends CharacterBody3D
## Enemigo base: persigue a Zahariel y daña al contacto. Stats escalados por ronda (GDD §7, §9).

signal died(enemy: Node)
signal health_changed(current: float, maximum: float)

const MIN_SPAWN_SEPARATION: float = 0.85
const NAV_UPDATE_INTERVAL: float = 0.15
const FALL_LIMIT_Y: float = -20.0
const CENTER_HOLE_RADIUS: float = 5.4
const HIT_STOP_SCALE: float = 0.0
const HIT_STOP_CRIT_SECONDS: float = 0.045
const HIT_STOP_KILL_SECONDS: float = 0.06
const HIT_STOP_CRIT_KILL_SECONDS: float = 0.11
const HIT_STOP_LAST_KILL_SECONDS: float = 0.14
const HIT_FLASH_SECONDS: float = 0.075
const HIT_KNOCKBACK_SPEED: float = 4.2
const HIT_KNOCKBACK_DECAY: float = 24.0
const _ENEMY_MANAGER = preload("res://scripts/Enemies/enemy_manager.gd")
const _BONE_PIECE := preload("res://scripts/Enemies/bone_piece.gd")
const _ENEMY_GIB := preload("res://scripts/Enemies/enemy_gib.gd")

static var _hit_stop_id: int = 0
static var _hit_flash_material: StandardMaterial3D

@export var data: EnemyData
## Ronda usada para el escalado inicial de stats (GDD §9).
@export var start_round: int = 1
@export var use_psx_style: bool = true
@export var attack_stop_distance: float = 0.0
## Si se asigna, este enemigo es un Campeón (corona + aura, stats mayores).
@export var champion_data: ChampionData

## Multiplicadores de variante (campeón, mini invocado). Se fijan antes de añadir al árbol.
var health_scale: float = 1.0
var damage_scale: float = 1.0
var speed_scale: float = 1.0
var visual_scale: float = 1.0
var contact_cooldown_scale: float = 1.0
## Velocidad de giro en rad/s (0 = instantáneo). La usa el blindado frontal.
var turn_speed: float = 0.0
## Multiplicador temporal de la velocidad de animación (lo usan habilidades como la embestida).
var animation_speed_boost: float = 1.0
## Animación forzada por una habilidad (ej. grito o carrera al cargar); "" = automática.
var override_animation: String = ""

var _health: float = 0.0
var _max_health: float = 0.0
var _move_speed: float = 0.0
var _contact_damage: float = 0.0
var _contact_timer: float = 0.0
var _nav_timer: float = 0.0
var _cached_nav_dir: Vector3 = Vector3.ZERO
var _player: Node3D
var _dead: bool = false
var _spawn_position: Vector3 = Vector3.ZERO
var _avoid_center_hole: bool = false
var _abilities: Array[EnemyAbility] = []
var _flash_meshes: Array[MeshInstance3D] = []
var _hit_flash_timer: float = 0.0
var _hit_knockback: Vector3 = Vector3.ZERO
var _step_delta: float = 0.016
var _move_log_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var _nav_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")


func _ready() -> void:
	add_to_group("enemies")
	set_physics_process(false)
	set_process(false)
	_spawn_position = global_position
	var scene := get_tree().current_scene
	_avoid_center_hole = scene != null and scene.find_child("HuecoCentral", true, false) != null
	if use_psx_style:
		PsxStyle.apply(self)
		if data != null:
			PsxStyle.apply_tint(self, data.tint_color)
	_apply_variant_visuals()
	_cache_flash_meshes()
	_resolve_spawn_overlap.call_deferred()
	_nav_timer = randf_range(0.0, NAV_UPDATE_INTERVAL)
	if data == null:
		push_error("Enemy sin EnemyData: %s" % name)
		return
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if champion_data != null:
		health_scale *= champion_data.health_multiplier
		damage_scale *= champion_data.damage_multiplier
		speed_scale *= champion_data.speed_multiplier
	_setup_ability()
	apply_round_scaling(start_round)
	_health = _max_health
	health_changed.emit(_health, _max_health)
	_ENEMY_MANAGER.register(self)
	await get_tree().physics_frame
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _nav_agent != null and _player != null and is_instance_valid(_player):
		_nav_agent.target_position = _player.global_position


func _exit_tree() -> void:
	_ENEMY_MANAGER.unregister(self)


func step_physics(delta: float, player_node: Node3D, allow_nav: bool = true) -> void:
	if _dead or data == null or not is_inside_tree() or not can_process():
		return
	if global_position.y < FALL_LIMIT_Y:
		(
			DebugLogger
			. write(
				"FALL_RESPAWN",
				(
					"%s | from=(%.2f, %.2f, %.2f) -> to=(%.2f, %.2f, %.2f)"
					% [
						name,
						global_position.x,
						global_position.y,
						global_position.z,
						_spawn_position.x,
						_spawn_position.y,
						_spawn_position.z,
					]
				)
			)
		)
		global_position = _spawn_position
		velocity = Vector3.ZERO
		return
	_player = player_node
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)

	_step_delta = delta
	_contact_timer = maxf(_contact_timer - delta, 0.0)
	_nav_timer -= delta
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_clear_hit_flash()

	if _player != null and is_instance_valid(_player):
		var to_player: Vector3 = _player.global_position - global_position
		to_player.y = 0.0
		var distance: float = to_player.length()
		var ability_controls: bool = false
		for ability in _abilities:
			if ability.step(delta, _player):
				ability_controls = true
		if _dead:
			return
		if ability_controls:
			_apply_hit_knockback(delta)
			move_and_slide()
			return
		if attack_stop_distance > 0.0 and distance <= attack_stop_distance:
			velocity.x = 0.0
			velocity.z = 0.0
			if distance > 0.001:
				_look_toward_direction(to_player)
		else:
			var move_dir: Vector3 = _get_navigation_direction(to_player, distance, allow_nav)
			if _avoid_center_hole:
				move_dir = _steer_around_center_hole(move_dir)
			velocity.x = move_dir.x * _move_speed
			velocity.z = move_dir.z * _move_speed
			if move_dir.length_squared() > 0.0001:
				_look_toward_direction(move_dir)
			elif distance > 0.001:
				_look_toward_direction(to_player)
		_try_contact_damage(distance)
	else:
		velocity.x = move_toward(velocity.x, 0.0, _move_speed)
		velocity.z = move_toward(velocity.z, 0.0, _move_speed)

	_apply_hit_knockback(delta)
	move_and_slide()
	if OS.is_debug_build():
		_move_log_timer -= delta
		if _move_log_timer <= 0.0 or is_on_wall():
			_move_log_timer = 0.25
			var nav_next: Vector3 = (
				_nav_agent.get_next_path_position() if _nav_agent != null else Vector3.ZERO
			)
			var nav_fin: bool = _nav_agent.is_navigation_finished() if _nav_agent != null else true
			var dist_p: float = (
				_player.global_position.distance_to(global_position)
				if _player != null and is_instance_valid(_player)
				else -1.0
			)
			(
				DebugLogger
				. log_enemy_move(
					self,
					Vector3(velocity.x, 0.0, velocity.z),
					nav_next,
					nav_fin,
					dist_p,
				)
			)


func step_process(
	_delta: float,
	_cam_pos: Vector3 = Vector3.ZERO,
	_cam_forward: Vector3 = Vector3.FORWARD,
	_has_cam: bool = false,
) -> void:
	pass


## Aplica el escalado de stats por ronda (GDD §9): stat = base × (1 + 0.1 × (ronda − 1)).
# TODO(GDD): fórmula propuesta pendiente de confirmación (§366).
func apply_round_scaling(round_number: int) -> void:
	if data == null:
		return
	var r: int = maxi(round_number, 1)
	var multiplier: float = 1.0 + data.scaling_per_round * float(r - 1)
	_max_health = data.max_health * multiplier
	_contact_damage = data.contact_damage * multiplier
	_move_speed = data.move_speed * multiplier
	_max_health *= health_scale
	_contact_damage *= damage_scale
	_move_speed *= speed_scale
	_health = minf(_health, _max_health) if _health > 0.0 else _max_health
	health_changed.emit(_health, _max_health)


## Escala del modelo/colisión (no del CharacterBody3D) y marcador de Campeón.
func _apply_variant_visuals() -> void:
	if data == null:
		return
	var factor: float = maxf(data.scale_multiplier, 0.01)
	if champion_data != null:
		factor *= maxf(champion_data.scale_multiplier, 0.01)
	factor *= maxf(visual_scale, 0.01)
	visual_scale = factor
	if champion_data != null:
		var marker: ChampionMarker = ChampionMarker.create(
			champion_data, data.damage_number_height * factor
		)
		add_child(marker)
	if is_equal_approx(factor, 1.0):
		return
	for child_name in ["Model", "CollisionShape3D"]:
		var child := get_node_or_null(child_name) as Node3D
		if child != null:
			child.scale *= factor
			child.position *= factor


func _setup_ability() -> void:
	if data == null or data.ability_script == null:
		return
	if data.ability == null:
		push_error("Enemy con ability_script pero sin AbilityData: %s" % name)
		return
	var ability := data.ability_script.new() as EnemyAbility
	if ability == null:
		push_error("ability_script no extiende EnemyAbility: %s" % name)
		return
	add_child(ability)
	ability.setup(self, data.ability)
	_abilities.append(ability)


## Multiplicador de daño actual respecto al base (ronda + variante), para escalar habilidades.
func get_damage_multiplier() -> float:
	if data == null:
		return 1.0
	return _contact_damage / maxf(data.contact_damage, 0.01)


func get_player() -> Node3D:
	return _player if _player != null and is_instance_valid(_player) else null


func face_direction(direction: Vector3) -> void:
	_look_toward_direction(direction)


func die() -> void:
	_die()


## Dispara brevemente la animación de ataque cuando una habilidad activa se ejecuta.
func trigger_ability_attack_anim(_duration: float = 0.45) -> void:
	pass


func take_damage(amount: float, is_critical: bool = false) -> void:
	if _dead or amount <= 0.0 or data == null:
		return
	for ability in _abilities:
		amount = ability.modify_damage(amount)
	if amount <= 0.0:
		return
	_health = maxf(_health - amount, 0.0)
	DamageNumber.spawn(
		get_tree(), global_position + Vector3.UP * data.damage_number_height, amount, is_critical
	)
	health_changed.emit(_health, _max_health)
	var is_kill: bool = _health <= 0.0
	if is_kill:
		_clear_hit_flash()
		var is_last: bool = _is_last_living_enemy()
		if is_last:
			_trigger_hit_stop(get_tree(), HIT_STOP_LAST_KILL_SECONDS, 1.6, true)
		elif is_critical:
			_trigger_hit_stop(get_tree(), HIT_STOP_CRIT_KILL_SECONDS, 1.4, true)
		else:
			_trigger_hit_stop(get_tree(), HIT_STOP_KILL_SECONDS, 0.95, true)
		_die()
	else:
		_start_hit_flash()
		_apply_damage_knockback(is_critical)
		if is_critical:
			_trigger_hit_stop(get_tree(), HIT_STOP_CRIT_SECONDS, 0.85, false)
		elif _player != null and _player.has_method("add_camera_punch"):
			_player.call("add_camera_punch", 0.4)


func _cache_flash_meshes() -> void:
	_flash_meshes.clear()
	for child in find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node != null:
			_flash_meshes.append(mesh_node)


func _start_hit_flash() -> void:
	if _hit_flash_material == null:
		_hit_flash_material = StandardMaterial3D.new()
		_hit_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hit_flash_material.albedo_color = Color(1.0, 0.9, 0.85, 0.88)
		_hit_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hit_flash_timer = HIT_FLASH_SECONDS
	for mesh_node in _flash_meshes:
		if is_instance_valid(mesh_node):
			mesh_node.material_overlay = _hit_flash_material


func _clear_hit_flash() -> void:
	_hit_flash_timer = 0.0
	for mesh_node in _flash_meshes:
		if is_instance_valid(mesh_node):
			mesh_node.material_overlay = null


func _apply_damage_knockback(is_critical: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var away: Vector3 = global_position - _player.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		return
	var mult: float = 1.6 if is_critical else 1.0
	_hit_knockback = away.normalized() * (HIT_KNOCKBACK_SPEED * mult)


func _apply_hit_knockback(delta: float) -> void:
	if _hit_knockback.length_squared() <= 0.0001:
		return
	velocity.x += _hit_knockback.x
	velocity.z += _hit_knockback.z
	_hit_knockback = _hit_knockback.move_toward(Vector3.ZERO, HIT_KNOCKBACK_DECAY * delta)


func _is_last_living_enemy() -> bool:
	for other: Node in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		if other.has_method("is_dead") and not other.call("is_dead"):
			return false
	return true


static func _trigger_hit_stop(
	tree: SceneTree, duration: float, punch: float = 1.0, force_override: bool = false
) -> void:
	if tree == null:
		return
	var in_normal_time: bool = is_equal_approx(Engine.time_scale, 1.0)
	var in_hit_stop: bool = _hit_stop_id > 0 and is_equal_approx(Engine.time_scale, HIT_STOP_SCALE)
	if not in_normal_time and not (force_override and in_hit_stop):
		return
	var player_node := tree.get_first_node_in_group("player")
	if player_node != null and player_node.has_method("add_camera_punch"):
		player_node.call("add_camera_punch", punch)
	_hit_stop_id += 1
	var my_id: int = _hit_stop_id
	Engine.time_scale = HIT_STOP_SCALE
	await tree.create_timer(duration, true, false, true).timeout
	if my_id == _hit_stop_id and is_equal_approx(Engine.time_scale, HIT_STOP_SCALE):
		Engine.time_scale = 1.0
		_hit_stop_id = 0


func get_health() -> float:
	return _health


func get_max_health() -> float:
	return _max_health


func is_dead() -> bool:
	return _dead


func _get_navigation_direction(
	to_player: Vector3, distance: float, allow_nav: bool = true
) -> Vector3:
	if distance <= 0.001:
		return Vector3.ZERO
	var fallback_dir: Vector3 = to_player / distance
	if distance < 4.0 or _nav_agent == null or _player == null or not is_instance_valid(_player):
		return fallback_dir
	if allow_nav and _nav_timer <= 0.0:
		_nav_timer = NAV_UPDATE_INTERVAL
		_nav_agent.target_position = _player.global_position
		if _nav_agent.is_navigation_finished():
			_cached_nav_dir = fallback_dir
		else:
			var next_pos: Vector3 = _nav_agent.get_next_path_position()
			var to_next: Vector3 = next_pos - global_position
			to_next.y = 0.0
			if to_next.length_squared() >= 0.0001 and to_next.dot(fallback_dir) > 0.0:
				_cached_nav_dir = to_next.normalized()
			else:
				_cached_nav_dir = fallback_dir
	if _cached_nav_dir.length_squared() >= 0.0001:
		return _cached_nav_dir
	return fallback_dir


func _steer_around_center_hole(move_dir: Vector3) -> Vector3:
	if move_dir.length_squared() < 0.0001:
		return move_dir
	var flat_pos := Vector2(global_position.x, global_position.z)
	var dist_center: float = flat_pos.length()
	var radial_out := flat_pos.normalized() if dist_center > 0.001 else Vector2.RIGHT
	if dist_center < CENTER_HOLE_RADIUS - 0.15:
		return Vector3(radial_out.x, 0.0, radial_out.y)
	var flat_dir := Vector2(move_dir.x, move_dir.z).normalized()
	var next_pos: Vector2 = flat_pos + flat_dir * 1.4
	if dist_center > CENTER_HOLE_RADIUS + 1.5 and next_pos.length() >= CENTER_HOLE_RADIUS:
		return move_dir
	if flat_dir.dot(radial_out) >= 0.0 and dist_center >= CENTER_HOLE_RADIUS:
		return move_dir
	var tangent_a := Vector2(-radial_out.y, radial_out.x)
	var tangent_b := -tangent_a
	var chosen: Vector2 = (
		tangent_a if tangent_a.dot(flat_dir) >= tangent_b.dot(flat_dir) else tangent_b
	)
	return Vector3(chosen.x, 0.0, chosen.y)


func _can_apply_contact_damage() -> bool:
	return true


func _try_contact_damage(distance: float) -> void:
	if _player == null or _contact_timer > 0.0 or data == null:
		return
	if distance > data.contact_range:
		return
	if not _can_apply_contact_damage():
		return
	if _player.has_method("take_damage"):
		_player.call("take_damage", _contact_damage, global_position)
		_contact_timer = data.contact_cooldown * maxf(contact_cooldown_scale, 0.01)


func _look_toward_direction(direction: Vector3) -> void:
	var flat_dir: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat_dir.length_squared() < 0.0001:
		return
	if turn_speed > 0.0:
		var target_yaw: float = atan2(-flat_dir.x, -flat_dir.z)
		var step_angle: float = turn_speed * _step_delta
		rotation.y += clampf(angle_difference(rotation.y, target_yaw), -step_angle, step_angle)
		return
	var target: Vector3 = global_position + flat_dir.normalized()
	target.y = global_position.y
	look_at(target, Vector3.UP)


func _die() -> void:
	if _dead:
		return
	_dead = true
	died.emit(self)
	# TODO(GDD): drops/reposición los gestiona el sistema de oleadas/spawner.
	if data != null:
		var burst_origin: Vector3 = global_position + Vector3.UP * (data.damage_number_height * 0.5)
		if data.death_explosion_type == EnemyData.DeathExplosionType.BONES:
			_BONE_PIECE.spawn_burst(
				get_tree(), burst_origin, data.bone_piece_count + 6, data.bone_floor_lifetime
			)
			(
				_ENEMY_GIB
				. spawn_burst(
					get_tree(),
					burst_origin,
					18,
					[Color(0.86, 0.82, 0.70), Color(0.85, 0.06, 0.06)],
				)
			)
		elif data.death_gib_count > 0:
			(
				_ENEMY_GIB
				. spawn_burst(
					get_tree(),
					burst_origin,
					maxi(data.death_gib_count * 2, 36),
					data.death_gib_colors,
				)
			)
	visible = false
	_ENEMY_MANAGER.unregister(self)
	collision_layer = 0
	collision_mask = 0
	queue_free()


## Fija la posición inicial del enemigo y actualiza su punto de respawn tras caer.
func set_spawn_position(pos: Vector3) -> void:
	global_position = pos
	_spawn_position = pos


## Evita que dos enemigos queden superpuestos al spawnear en la misma coordenada
## (lo que provoca impulsos bruscos en move_and_slide).
func _resolve_spawn_overlap() -> void:
	var min_sq: float = MIN_SPAWN_SEPARATION * MIN_SPAWN_SEPARATION
	var others: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var has_overlap: bool = false
	for other in others:
		if other == self or not (other is Node3D):
			continue
		var diff: Vector3 = global_position - (other as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() < min_sq:
			has_overlap = true
			break
	if not has_overlap:
		return
	var step: float = MIN_SPAWN_SEPARATION + 0.15
	for ring in range(1, 6):
		var radius: float = step * float(ring)
		for slot in range(8):
			var angle: float = TAU * float(slot) / 8.0
			var candidate: Vector3 = (
				global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			)
			if _is_spot_clear(candidate, others, min_sq):
				global_position = candidate
				_spawn_position = candidate
				return


func _is_spot_clear(pos: Vector3, others: Array[Node], min_sq: float) -> bool:
	if (
		_avoid_center_hole
		and Vector2(pos.x, pos.z).length_squared() < CENTER_HOLE_RADIUS * CENTER_HOLE_RADIUS
	):
		return false
	for other in others:
		if other == self or not (other is Node3D):
			continue
		var diff: Vector3 = pos - (other as Node3D).global_position
		diff.y = 0.0
		if diff.length_squared() < min_sq:
			return false
	return true
