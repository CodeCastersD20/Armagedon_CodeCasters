class_name EnemyManager
extends Node
## Centraliza la simulación de todos los enemigos activos en un único _physics_process y _process:
## - Resuelve _player y _camera una sola vez por frame.
## - Presupuesto de pathfinding por frame (máx. MAX_NAV_UPDATES_PER_FRAME).
## - Física escalonada a mitad de tasa para enemigos lejanos (> 16 m).
## - Culling de animación para enemigos detrás de la cámara.
## - Movimiento en grupo (CrowdConfig): separación entre enemigos y cerco alrededor del jugador,
##   para que no se amontonen ni lleguen en fila.

const MAX_NAV_UPDATES_PER_FRAME: int = 10
const FAR_PHYSICS_DIST_SQ: float = 256.0
const _CROWD_CONFIG: CrowdConfig = preload("res://data/enemies/crowd_config.tres")

static var _instance: EnemyManager

var _enemies: Array[Node] = []
var _player: Node3D
var _camera: Camera3D
var _physics_tick: int = 0
var _nav_cursor: int = 0
var _surround_timer: float = 0.0
## Buffers reutilizados por frame (no se crean arrays nuevos en cada física).
var _crowd_alive: Array[Enemy] = []
var _crowd_positions: PackedVector3Array = PackedVector3Array()
var _crowd_push: PackedVector3Array = PackedVector3Array()


static func register(enemy: Node) -> void:
	if enemy == null or not enemy.is_inside_tree():
		return
	var mgr: EnemyManager = _get_or_create(enemy.get_tree())
	if mgr != null and not mgr._enemies.has(enemy):
		mgr._enemies.append(enemy)


static func unregister(enemy: Node) -> void:
	if _instance == null or enemy == null:
		return
	var idx: int = _instance._enemies.find(enemy)
	if idx >= 0:
		var last: int = _instance._enemies.size() - 1
		if idx != last:
			_instance._enemies[idx] = _instance._enemies[last]
		_instance._enemies.pop_back()


static func _get_or_create(tree: SceneTree) -> EnemyManager:
	if is_instance_valid(_instance) and not _instance.is_queued_for_deletion():
		return _instance
	if tree == null or tree.current_scene == null:
		return null
	var created := EnemyManager.new()
	created.name = "EnemyManager"
	_instance = created
	tree.current_scene.add_child.call_deferred(created)
	return created


func _exit_tree() -> void:
	_enemies.clear()
	_player = null
	_camera = null
	if _instance == self:
		_instance = null


func _physics_process(delta: float) -> void:
	if _enemies.is_empty():
		return
	_physics_tick += 1
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	var has_player: bool = _player != null and is_instance_valid(_player)
	var player_pos: Vector3 = _player.global_position if has_player else Vector3.ZERO
	_update_crowd(delta, player_pos, has_player)
	var nav_budget: int = MAX_NAV_UPDATES_PER_FRAME
	var count: int = _enemies.size()
	if _nav_cursor >= count:
		_nav_cursor = 0

	var i: int = count - 1
	while i >= 0:
		var enemy: Node = _enemies[i]
		if (
			enemy == null
			or not is_instance_valid(enemy)
			or not enemy.is_inside_tree()
			or enemy.call("is_dead")
		):
			unregister(enemy)
			i -= 1
			continue

		var is_far: bool = false
		if has_player:
			var dist_sq: float = (enemy as Node3D).global_position.distance_squared_to(player_pos)
			is_far = dist_sq > FAR_PHYSICS_DIST_SQ

		if is_far and ((i + _physics_tick) & 1) != 0:
			i -= 1
			continue

		var step_delta: float = delta * 2.0 if is_far else delta
		var allow_nav: bool = false
		if nav_budget > 0 and ((i - _nav_cursor + count) % count) < MAX_NAV_UPDATES_PER_FRAME:
			allow_nav = true
			nav_budget -= 1

		enemy.call("step_physics", step_delta, _player, allow_nav)
		i -= 1

	if count > 0:
		_nav_cursor = (_nav_cursor + MAX_NAV_UPDATES_PER_FRAME) % count


func _update_crowd(delta: float, player_pos: Vector3, has_player: bool) -> void:
	_crowd_alive.clear()
	for raw: Variant in _enemies:
		if not is_instance_valid(raw):
			continue
		var enemy := raw as Enemy
		if enemy != null and enemy.is_inside_tree() and not enemy.is_dead():
			_crowd_alive.append(enemy)
	_apply_separation(player_pos, has_player)
	_surround_timer -= delta
	if _surround_timer <= 0.0:
		_surround_timer = maxf(_CROWD_CONFIG.surround_update_seconds, 0.05)
		_assign_surround_slots(player_pos, has_player)


## Cada par de enemigos más cerca que `separation_radius` se empuja en sentidos opuestos,
## más fuerte cuanto más pegados. Como mucho ~30 enemigos: el doble bucle es barato.
func _apply_separation(player_pos: Vector3, has_player: bool) -> void:
	var count: int = _crowd_alive.size()
	var radius: float = maxf(_CROWD_CONFIG.separation_radius, 0.01)
	var radius_sq: float = radius * radius
	_crowd_positions.resize(count)
	_crowd_push.resize(count)
	for i in count:
		_crowd_positions[i] = _crowd_alive[i].global_position
		_crowd_push[i] = Vector3.ZERO
	for a in count:
		for b in range(a + 1, count):
			var diff: Vector3 = _crowd_positions[a] - _crowd_positions[b]
			diff.y = 0.0
			var dist_sq: float = diff.length_squared()
			if dist_sq >= radius_sq:
				continue
			if dist_sq < 0.0001:
				# Encimados: se separan en una dirección cualquiera según su orden.
				diff = Vector3(cos(float(a)), 0.0, sin(float(a))) * 0.01
				dist_sq = 0.0001
			var dist: float = sqrt(dist_sq)
			var push: Vector3 = diff / dist * (1.0 - dist / radius)
			_crowd_push[a] += push
			_crowd_push[b] -= push
	var weight: float = _CROWD_CONFIG.separation_weight
	for i in count:
		_crowd_push[i] *= weight
	if has_player:
		_apply_line_avoidance(player_pos)
	for i in count:
		_crowd_alive[i].set_crowd_separation(_crowd_push[i])


## Rompe las filas: si un enemigo está detrás de otro visto desde el jugador (casi el mismo
## ángulo y más lejos), se empuja de lado (perpendicular a la línea con el jugador), hacia el
## lado contrario al de delante. Así una ráfaga o un tajo no atraviesa a varios en hilera.
func _apply_line_avoidance(player_pos: Vector3) -> void:
	var limit: float = deg_to_rad(maxf(_CROWD_CONFIG.line_avoid_degrees, 0.1))
	var weight: float = _CROWD_CONFIG.line_avoid_weight
	var range_sq: float = _CROWD_CONFIG.line_avoid_range * _CROWD_CONFIG.line_avoid_range
	if weight <= 0.0:
		return
	var count: int = _crowd_positions.size()
	for a in count:
		var rel_a: Vector3 = _crowd_positions[a] - player_pos
		rel_a.y = 0.0
		var dist_a_sq: float = rel_a.length_squared()
		if dist_a_sq > range_sq or dist_a_sq < 0.25:
			continue
		var angle_a: float = atan2(rel_a.z, rel_a.x)
		for b in count:
			if b == a:
				continue
			var rel_b: Vector3 = _crowd_positions[b] - player_pos
			rel_b.y = 0.0
			# Solo el de atrás (a) se aparta del de delante (b).
			if rel_b.length_squared() >= dist_a_sq:
				continue
			var diff: float = angle_difference(atan2(rel_b.z, rel_b.x), angle_a)
			if absf(diff) >= limit:
				continue
			var side: float = 1.0 if diff >= 0.0 else -1.0
			if absf(diff) < 0.001:
				side = 1.0 if (a & 1) == 0 else -1.0
			var tangent: Vector3 = Vector3(-rel_a.z, 0.0, rel_a.x).normalized() * side
			_crowd_push[a] += tangent * weight * (1.0 - absf(diff) / limit)


## Ordena por ángulo alrededor del jugador a los que van directo a él y les da huecos
## repartidos por igual, respetando su orden (cada uno toma el hueco más cercano a su lado).
func _assign_surround_slots(player_pos: Vector3, has_player: bool) -> void:
	var range_sq: float = _CROWD_CONFIG.surround_range * _CROWD_CONFIG.surround_range
	var engage_sq: float = (
		_CROWD_CONFIG.surround_engage_distance * _CROWD_CONFIG.surround_engage_distance
	)
	var ring: Array[Vector2] = []  # x = ángulo, y = índice en _crowd_alive
	for i in _crowd_alive.size():
		var enemy: Enemy = _crowd_alive[i]
		enemy.clear_surround_slot()
		if not has_player or not _CROWD_CONFIG.surround_enabled or not enemy.wants_surround():
			continue
		var diff: Vector3 = enemy.global_position - player_pos
		diff.y = 0.0
		var dist_sq: float = diff.length_squared()
		if dist_sq > range_sq or dist_sq <= engage_sq:
			continue
		ring.append(Vector2(atan2(diff.z, diff.x), float(i)))
	var count: int = ring.size()
	if count < 2:
		return
	ring.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spacing: float = TAU / float(count)
	# Giro común que deja a cada uno lo más cerca posible de su ángulo actual (media circular).
	var sum := Vector2.ZERO
	for k in count:
		var offset: float = ring[k].x - float(k) * spacing
		sum += Vector2(cos(offset), sin(offset))
	var base: float = atan2(sum.y, sum.x)
	var max_turn: float = deg_to_rad(_CROWD_CONFIG.surround_max_turn_degrees)
	for k in count:
		var current: float = ring[k].x
		var slot: float = base + float(k) * spacing
		var turn: float = clampf(angle_difference(current, slot), -max_turn, max_turn)
		_crowd_alive[int(ring[k].y)].set_surround_slot(current + turn)


func _process(delta: float) -> void:
	if _enemies.is_empty():
		return
	var viewport: Viewport = get_viewport()
	if viewport != null:
		_camera = viewport.get_camera_3d()
	var has_cam: bool = _camera != null and is_instance_valid(_camera)
	var cam_pos: Vector3 = _camera.global_position if has_cam else Vector3.ZERO
	var cam_forward: Vector3 = -_camera.global_basis.z if has_cam else Vector3.FORWARD

	var i: int = _enemies.size() - 1
	while i >= 0:
		var enemy: Node = _enemies[i]
		if enemy != null and is_instance_valid(enemy) and not enemy.call("is_dead"):
			enemy.call("step_process", delta, cam_pos, cam_forward, has_cam)
		i -= 1
