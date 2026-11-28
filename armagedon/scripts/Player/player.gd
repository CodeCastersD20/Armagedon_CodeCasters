class_name Player
extends CharacterBody3D
## Zahariel en primera persona: movimiento WASD, mirar con mouse, salto,
## dash, correr (Ctrl) y agacharse (C).

## Cargas de dash actuales (fraccionarias mientras se recarga) y máximo. Para el HUD (#88).
signal stamina_changed(current: float, maximum: float)
## Vida actual y máxima. Para el HUD (#88).
signal health_changed(current: float, maximum: float)
## Fe actual y máxima. Para el HUD (#88) y los Poderes de Fe (#80).
signal faith_changed(current: float, maximum: float)
## Emite cuando el escudo bloquea exitosamente un ataque frontal (para sonido/efecto).
signal attack_blocked(damage_blocked: float)
## HP llegó a 0: no es muerte, es el escape (aro de luz). Lo escucha el RoundManager (#72).
signal player_escaped
## Emite al impactar contra el suelo tras un ground slam (Ctrl en el aire).
signal slam_landed(impact_pos: Vector3)
## Emite al realizar un doble salto en el aire (para partículas/plumas).
signal double_jumped(origin: Vector3)

@export var stats: PlayerStats

## Multiplicador del daño recibido (1.0 = normal). El escudo (#42) lo baja, p. ej. a 0.5.
var damage_taken_multiplier: float = 1.0

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _charges: float
var _dash_time_left: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _slide_time_left: float = 0.0
var _slide_cooldown_left: float = 0.0
var _slide_velocity: Vector3 = Vector3.ZERO
var _crouch_release_required: bool = false
var _slamming: bool = false
var _slam_cooldown_left: float = 0.0
var _running: bool = false
var _crouching: bool = false
var _stand_height: float
var _head_stand_y: float
var _health: float
var _faith: float
var _escaped: bool = false
var _spawn_transform: Transform3D
var _is_blocking: bool = false
var _air_jumps_left: int = 0
var _coyote_timer: float = 0.0
var _god_mode: bool = false
var _invuln_timer: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
## Transiciones de círculo: sin moverse (sí mirar y disparar) y sin reaparecer al caer.
var _movement_locked: bool = false
## Elevador: se puede caminar, pero no saltar ni esquivar (no salir de la plataforma).
var _jump_locked: bool = false
var _fall_respawn_suspended: bool = false
var _stun_time_left: float = 0.0
var _weapon_manager: WeaponManager
var _camera_feel: PlayerCameraFeel = PlayerCameraFeel.new()

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _collision: CollisionShape3D = $Colison
@onready var _slide_lines: ColorRect = get_node_or_null("SlideOverlay/SpeedLines")
@onready var _stun_rect: ColorRect = get_node_or_null("StunOverlay/StunRect")


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	add_to_group("player")
	# El WeaponManager se registra en su grupo en su propio _ready (hijo, corre antes que este).
	_weapon_manager = get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	_spawn_transform = global_transform
	_collision.shape = _collision.shape.duplicate()
	assert(_collision.shape is CapsuleShape3D, "El jugador necesita una CapsuleShape3D")
	_stand_height = (_collision.shape as CapsuleShape3D).height
	_head_stand_y = _head.position.y
	_camera_feel.setup(_head, _camera, stats, _stun_rect, _slide_lines)
	_charges = stats.stamina
	stamina_changed.emit(_charges, stats.stamina)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health = stats.max_health
	health_changed.emit(_health, stats.max_health)
	_faith = stats.faith
	faith_changed.emit(_faith, stats.max_faith)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _stun_time_left > 0.0:
			return
		rotate_y(-event.relative.x * stats.mouse_sensitivity)
		var limit: float = deg_to_rad(stats.max_pitch_degrees)
		_head.rotation.x = clampf(
			_head.rotation.x - event.relative.y * stats.mouse_sensitivity, -limit, limit
		)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_invuln_timer = maxf(_invuln_timer - delta, 0.0)
	_stun_time_left = maxf(_stun_time_left - delta, 0.0)
	_recharge_dash(delta)
	_respawn_if_fallen()

	var on_floor: bool = is_on_floor()
	# El bloqueo de movimiento (transiciones) se trata como un aturdimiento sin efecto visual.
	var stunned: bool = _stun_time_left > 0.0 or _movement_locked
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	_slam_cooldown_left = maxf(_slam_cooldown_left - delta, 0.0)
	if on_floor:
		if _slamming:
			_slamming = false
			_apply_slam_impact()
		_air_jumps_left = stats.max_air_jumps
		_coyote_timer = stats.coyote_time_seconds
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		if _dash_time_left <= 0.0 and not _slamming:
			velocity.y -= _gravity * delta

	if not stunned and not _jump_locked and Input.is_action_just_pressed("jump"):
		if on_floor or _coyote_timer > 0.0:
			if _slide_time_left > 0.0:
				velocity.y = stats.jump_velocity * stats.slide_jump_vertical_multiplier
				velocity.x = _slide_velocity.x * stats.slide_jump_horizontal_multiplier
				velocity.z = _slide_velocity.z * stats.slide_jump_horizontal_multiplier
				_slide_time_left = 0.0
			else:
				velocity.y = stats.jump_velocity
			if _crouching or Input.is_action_pressed("crouch"):
				_crouch_release_required = true
				_crouching = false
				_stand_up_immediately()
			_coyote_timer = 0.0
		elif _air_jumps_left > 0:
			_air_jumps_left -= 1
			velocity.y = stats.air_jump_velocity
			_slide_time_left = 0.0
			double_jumped.emit(global_position)
			if _crouching or Input.is_action_pressed("crouch"):
				_crouch_release_required = true
				_crouching = false
				_stand_up_immediately()

	var input_dir: Vector2 = (
		Vector2.ZERO
		if stunned
		else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	)
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if not Input.is_action_pressed("crouch"):
		_crouch_release_required = false

	if not stunned and Input.is_action_just_pressed("crouch"):
		if on_floor:
			_try_slide(direction, input_dir, on_floor)
		elif not _slamming:
			_start_ground_slam()
	elif stunned or not Input.is_action_pressed("crouch") or not on_floor:
		_slide_time_left = 0.0

	_update_crouch(delta)
	_update_running(input_dir)
	if not stunned:
		_update_shield_block()
	else:
		_is_blocking = false

	if not stunned and not _jump_locked and Input.is_action_just_pressed("dash"):
		_slide_time_left = 0.0
		_slamming = false
		_try_dash(direction)

	if stunned:
		velocity.x = 0.0
		velocity.z = 0.0
	elif _slamming:
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -stats.slam_speed
	elif _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity.x = _dash_velocity.x
		velocity.z = _dash_velocity.z
		if not on_floor:
			velocity.y = maxf(velocity.y, 0.0)
		if _dash_time_left <= 0.0:
			var dash_dir: Vector3 = _dash_velocity.normalized()
			var residual: Vector3 = dash_dir * stats.dash_residual_speed
			velocity.x = residual.x
			velocity.z = residual.z
	elif _slide_time_left > 0.0:
		_slide_time_left -= delta
		velocity.x = _slide_velocity.x
		velocity.z = _slide_velocity.z
		_slide_velocity = _slide_velocity.move_toward(Vector3.ZERO, 6.0 * delta)
	else:
		_apply_horizontal_movement(delta, direction, on_floor)

	if _knockback_velocity.length_squared() > 0.0001:
		velocity.x += _knockback_velocity.x
		velocity.z += _knockback_velocity.z
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 28.0 * delta)
	move_and_slide()
	_update_camera_feel(delta, input_dir)


## Cargas de dash actuales, para quien se conecte tarde a stamina_changed.
func get_charges() -> float:
	return _charges


## Caminar es lo normal. Ctrl alterna a correr; al dejar de moverte o agacharte vuelve a caminar.
func _update_running(input_dir: Vector2) -> void:
	if Input.is_action_just_pressed("run_toggle"):
		_running = not _running
	if input_dir == Vector2.ZERO or _crouching:
		_running = false


func _current_speed() -> float:
	if _crouching:
		return stats.move_speed * stats.crouch_speed_multiplier
	if stats.always_run or _running:
		return stats.move_speed * stats.run_speed_multiplier
	return stats.move_speed


## Agacharse mientras se mantiene C; no se levanta si hay techo encima.
func _update_crouch(delta: float) -> void:
	var shape := _collision.shape as CapsuleShape3D
	var wants_crouch: bool = (
		is_on_floor()
		and Input.is_action_pressed("crouch")
		and not _crouch_release_required
		and not _slamming
	)
	if not wants_crouch and _crouching:
		wants_crouch = test_move(global_transform, Vector3.UP * (_stand_height - shape.height))
	_crouching = wants_crouch
	var target_height: float = stats.crouch_height if _crouching else _stand_height
	shape.height = lerpf(shape.height, target_height, stats.crouch_transition_speed * delta)
	_collision.position.y = shape.height / 2.0
	_head.position.y = _head_stand_y - (_stand_height - shape.height)


func _stand_up_immediately() -> void:
	var shape := _collision.shape as CapsuleShape3D
	if shape != null:
		shape.height = _stand_height
	_collision.position.y = _stand_height / 2.0
	_head.position.y = _head_stand_y


func _start_ground_slam() -> void:
	if _slam_cooldown_left > 0.0:
		return
	if test_move(global_transform, Vector3.DOWN * stats.slam_min_height):
		return
	_slamming = true
	_slam_cooldown_left = stats.slam_cooldown
	_slide_time_left = 0.0
	_dash_time_left = 0.0
	_crouch_release_required = true
	velocity = Vector3(0.0, -stats.slam_speed, 0.0)


func _apply_slam_impact() -> void:
	slam_landed.emit(global_position)
	_start_slam_camera_shake()
	var radius_sq: float = stats.slam_radius * stats.slam_radius
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy_3d := enemy as Node3D
		if enemy_3d == null or not is_instance_valid(enemy_3d):
			continue
		if enemy_3d.global_position.distance_squared_to(global_position) <= radius_sq:
			if enemy_3d.has_method("take_damage"):
				enemy_3d.call("take_damage", stats.slam_damage, false)


func _try_slide(direction: Vector3, _input_dir: Vector2, on_floor: bool) -> void:
	if not on_floor or _slide_cooldown_left > 0.0 or _dash_time_left > 0.0:
		return
	if direction == Vector3.ZERO:
		return
	var current_horiz: float = Vector2(velocity.x, velocity.z).length()
	if current_horiz < stats.move_speed * 0.5:
		return
	_slide_time_left = stats.slide_duration
	_slide_cooldown_left = stats.slide_cooldown
	_slide_velocity = direction * maxf(stats.slide_speed, current_horiz)


func _try_dash(direction: Vector3) -> void:
	if _charges < 1.0 or _dash_time_left > 0.0:
		return
	if not is_on_floor() and not stats.dash_in_air:
		return
	if direction == Vector3.ZERO:
		direction = -transform.basis.z
	_charges -= 1.0
	_dash_time_left = stats.dash_duration
	_dash_velocity = direction * (stats.dash_distance / maxf(stats.dash_duration, 0.01))
	if not is_on_floor():
		velocity.y = stats.dash_air_vertical_boost
	stamina_changed.emit(_charges, stats.stamina)


func _apply_horizontal_movement(delta: float, direction: Vector3, on_floor: bool) -> void:
	var horiz := Vector2(velocity.x, velocity.z)
	var wish_dir := Vector2(direction.x, direction.z)
	var target_speed: float = _current_speed()

	if on_floor:
		var friction: float = stats.ground_friction
		if wish_dir == Vector2.ZERO:
			horiz = horiz.move_toward(
				Vector2.ZERO, maxf(horiz.length(), target_speed) * friction * delta
			)
		else:
			if horiz.length() > target_speed:
				horiz = horiz.move_toward(wish_dir * target_speed, friction * target_speed * delta)
			else:
				horiz = horiz.move_toward(
					wish_dir * target_speed, stats.ground_acceleration * delta
				)
	else:
		if wish_dir == Vector2.ZERO:
			horiz = horiz.move_toward(Vector2.ZERO, horiz.length() * stats.air_friction * delta)
		else:
			# Air control estilo Quake/Source: suma velocidad sin sobrescribir la inercia previa.
			var proj_speed: float = horiz.dot(wish_dir)
			var add_speed: float = maxf(target_speed - proj_speed, 0.0)
			var accel_speed: float = minf(stats.air_acceleration * delta, add_speed)
			horiz += wish_dir * accel_speed

	velocity.x = horiz.x
	velocity.z = horiz.y


func _update_camera_feel(delta: float, input_dir: Vector2) -> void:
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	_camera_feel.update(
		delta,
		input_dir,
		horiz_speed,
		_slide_time_left > 0.0,
		_dash_time_left > 0.0,
		_stun_time_left > 0.0
	)


## Golpe seco de cámara estilo ULTRAKILL al conectar un hit-stop.
func add_camera_punch(strength: float = 1.0) -> void:
	_camera_feel.add_punch(strength)


## Sacudida breve con decaimiento lineal al impactar el ground slam.
func _start_slam_camera_shake() -> void:
	_camera_feel.add_shake(stats.slam_shake_strength, stats.slam_shake_duration)


## Sacudida de cámara externa (explosiones): `strength` como la del slam (1.0), `duration` en s.
func add_camera_shake(strength: float, duration: float) -> void:
	_camera_feel.add_shake(strength, duration)


## Empuje horizontal externo que decae solo (explosiones).
func apply_knockback(impulse: Vector3) -> void:
	_knockback_velocity = Vector3(impulse.x, 0.0, impulse.z)


## Aturde brevemente al jugador (ej. impacto de embestida del cargador).
func apply_stun(duration: float) -> void:
	if duration <= 0.0:
		return
	_stun_time_left = maxf(_stun_time_left, duration)
	_slide_time_left = 0.0
	_dash_time_left = 0.0
	_slamming = false
	_is_blocking = false
	add_camera_shake(0.65, 0.25)


func is_stunned() -> bool:
	return _stun_time_left > 0.0


## Suma un desplazamiento temporal al FOV (p. ej. latido con poca vida en GameFlow).
func set_heartbeat_fov_offset(offset: float) -> void:
	_camera_feel.set_heartbeat_fov_offset(offset)


func _recharge_dash(delta: float) -> void:
	if _charges >= stats.stamina:
		return
	_charges = minf(_charges + delta / maxf(stats.dash_recharge_seconds, 0.01), stats.stamina)
	stamina_changed.emit(_charges, stats.stamina)


func get_health() -> float:
	return _health


func set_god_mode(enabled: bool) -> void:
	if not OS.is_debug_build():
		return
	_god_mode = enabled


func is_god_mode() -> bool:
	return _god_mode


## Suma vida respetando max_health y emite health_changed.
func heal(amount: float) -> void:
	if _escaped or amount <= 0.0:
		return
	var next_health: float = minf(_health + amount, stats.max_health)
	if is_equal_approx(next_health, _health):
		return
	_health = next_health
	health_changed.emit(_health, stats.max_health)


func get_faith() -> float:
	return _faith


func is_faith_full() -> bool:
	return _escaped or _faith >= stats.max_faith


func is_health_full() -> bool:
	return _escaped or _health >= stats.max_health


## Suma Fe respetando max_faith y emite faith_changed.
func add_faith(amount: float) -> void:
	if _escaped or amount <= 0.0:
		return
	var next_faith: float = minf(_faith + amount, stats.max_faith)
	if is_equal_approx(next_faith, _faith):
		return
	_faith = next_faith
	faith_changed.emit(_faith, stats.max_faith)


## Aplica daño (ya con el multiplicador). Al llegar a 0 emite player_escaped una sola vez.
## Acepta damage_source_position opcional para comprobar si el escudo lo bloquea de frente.
func take_damage(amount: float, damage_source_position: Vector3 = Vector3.INF) -> void:
	if _escaped or _god_mode or _invuln_timer > 0.0 or amount <= 0.0:
		return

	# Si se está cubriendo con el escudo y el ataque viene de frente, bloquea el 100%
	if _is_blocking and damage_source_position != Vector3.INF:
		var to_source: Vector3 = (damage_source_position - global_position).normalized()
		# Usamos la dirección frontal del jugador (horizontal)
		var forward: Vector3 = -global_basis.z
		to_source.y = 0.0
		forward.y = 0.0
		to_source = to_source.normalized()
		forward = forward.normalized()
		var dot: float = forward.dot(to_source)
		var min_dot: float = cos(deg_to_rad(stats.shield_block_angle_degrees * 0.5))
		if dot >= min_dot:
			# Bloqueo exitoso frontal + pequeño empujón hacia atrás
			_knockback_velocity = -to_source * stats.shield_block_knockback
			attack_blocked.emit(amount)
			return

	_health = maxf(_health - amount * damage_taken_multiplier, 0.0)
	_invuln_timer = stats.invulnerability_seconds
	health_changed.emit(_health, stats.max_health)
	if _health <= 0.0:
		_escaped = true
		player_escaped.emit()


## Actualiza el estado de cobertura del escudo y el multiplicador pasivo (GDD §6.1).
func _update_shield_block() -> void:
	var has_sword_equipped: bool = false
	if _weapon_manager != null:
		var current_w: Weapon = _weapon_manager.get_current_weapon()
		has_sword_equipped = current_w != null and current_w.is_melee()

	# Pasiva GDD §6.1: llevar espada + escudo reduce el daño un 60%
	if has_sword_equipped:
		damage_taken_multiplier = 1.0 - stats.sword_shield_passive_reduction
	else:
		damage_taken_multiplier = 1.0

	# Bloqueo activo manteniendo clic derecho (solo con la espada equipada)
	_is_blocking = (
		has_sword_equipped
		and Input.is_action_pressed("block")
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)


func is_blocking() -> bool:
	return _is_blocking


## Si caes fuera del mapa, vuelves al punto de inicio sin perder vida.
func _respawn_if_fallen() -> void:
	if _fall_respawn_suspended or global_position.y >= stats.fall_limit_y:
		return
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_dash_time_left = 0.0
	_head.rotation.x = 0.0


## Transiciones de círculo: bloquea moverse, saltar y esquivar, pero deja mirar y disparar.
func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		velocity.x = 0.0
		velocity.z = 0.0
		_dash_time_left = 0.0
		_slide_time_left = 0.0


## Elevador: caminar sí, saltar y esquivar no.
func set_jump_locked(locked: bool) -> void:
	_jump_locked = locked


## Transiciones de círculo: no reaparecer en el spawn al bajar de `fall_limit_y`.
func set_fall_respawn_suspended(suspended: bool) -> void:
	_fall_respawn_suspended = suspended


## Activa o desactiva el control del jugador durante menús y cinemáticas.
func set_cinematic_mode(enabled: bool) -> void:
	set_physics_process(not enabled)
	set_process_unhandled_input(not enabled)
	if _weapon_manager != null:
		_weapon_manager.set_process(not enabled)
		_weapon_manager.set_process_unhandled_input(not enabled)
	if enabled:
		velocity = Vector3.ZERO
		_dash_time_left = 0.0
		_slide_time_left = 0.0
		_slide_cooldown_left = 0.0
		_crouch_release_required = false
		_slamming = false
		_slam_cooldown_left = 0.0
		_coyote_timer = 0.0
		_is_blocking = false
		_head.rotation.z = 0.0
		_camera_feel.reset()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Reinicia vida, estamina y estado de escape para una nueva partida sin recargar la escena.
func reset_for_new_run() -> void:
	_escaped = false
	_health = stats.max_health
	_faith = stats.faith
	_charges = stats.stamina
	_dash_time_left = 0.0
	_slide_time_left = 0.0
	_slide_cooldown_left = 0.0
	_crouch_release_required = false
	_slamming = false
	_slam_cooldown_left = 0.0
	_coyote_timer = 0.0
	_is_blocking = false
	_invuln_timer = 0.0
	_knockback_velocity = Vector3.ZERO
	_stun_time_left = 0.0
	_crouching = false
	_running = false
	_air_jumps_left = stats.max_air_jumps
	_movement_locked = false
	_jump_locked = false
	_fall_respawn_suspended = false
	_stand_up_immediately()
	velocity = Vector3.ZERO
	global_transform = _spawn_transform
	_head.position.y = _head_stand_y
	_head.rotation = Vector3.ZERO
	_camera_feel.reset()
	health_changed.emit(_health, stats.max_health)
	faith_changed.emit(_faith, stats.max_faith)
	stamina_changed.emit(_charges, stats.stamina)


## Posiciona la altura de la cabeza (para la animación de levantarse tras la caída).
func set_head_height(height_y: float) -> void:
	_head.position.y = height_y


## Devuelve la altura normal de la cabeza de pie.
func get_head_stand_y() -> float:
	return _head_stand_y
