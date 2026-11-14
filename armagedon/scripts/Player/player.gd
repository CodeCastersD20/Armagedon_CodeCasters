class_name Player
extends CharacterBody3D
## Zahariel en primera persona: movimiento WASD, mirar con mouse, salto, dash, correr (Ctrl) y agacharse (C).

## Cargas de dash actuales (fraccionarias mientras se recarga) y máximo. Para el HUD (#88).
signal stamina_changed(current: float, maximum: float)
## Vida actual y máxima. Para el HUD (#88).
signal health_changed(current: float, maximum: float)
## Emite cuando el escudo bloquea exitosamente un ataque frontal (para sonido/efecto).
signal attack_blocked(damage_blocked: float)
## HP llegó a 0: no es muerte, es el escape (aro de luz). Lo escucha el RoundManager (#72).
signal player_escaped

@export var stats: PlayerStats

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _charges: float
var _dash_time_left: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _running: bool = false
var _crouching: bool = false
var _stand_height: float
var _head_stand_y: float

## Multiplicador del daño recibido (1.0 = normal). El escudo (#42) lo baja, p. ej. a 0.5.
var damage_taken_multiplier: float = 1.0
var _health: float
var _time_since_damage: float = 0.0
var _regen_timer: float = 0.0
var _escaped: bool = false
var _spawn_transform: Transform3D
var _is_blocking: bool = false

@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $Colison


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	add_to_group("player")
	_spawn_transform = global_transform
	_collision.shape = _collision.shape.duplicate()
	_stand_height = (_collision.shape as CapsuleShape3D).height
	_head_stand_y = _head.position.y
	_charges = stats.stamina
	stamina_changed.emit(_charges, stats.stamina)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_health = stats.max_health
	health_changed.emit(_health, stats.max_health)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * stats.mouse_sensitivity)
		_head.rotate_x(-event.relative.y * stats.mouse_sensitivity)
		var limit: float = deg_to_rad(stats.max_pitch_degrees)
		_head.rotation.x = clampf(_head.rotation.x, -limit, limit)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	_recharge_dash(delta)
	_regen_health(delta)
	_respawn_if_fallen()
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = stats.jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	_update_crouch(delta)
	_update_running(input_dir)
	_update_shield_block()

	if Input.is_action_just_pressed("dash"):
		_try_dash(direction)

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		velocity.x = _dash_velocity.x
		velocity.z = _dash_velocity.z
	else:
		var speed: float = _current_speed()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	move_and_slide()


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
	var wants_crouch: bool = Input.is_action_pressed("crouch")
	if not wants_crouch and _crouching:
		wants_crouch = test_move(global_transform, Vector3.UP * (_stand_height - shape.height))
	_crouching = wants_crouch
	var target_height: float = stats.crouch_height if _crouching else _stand_height
	shape.height = lerpf(shape.height, target_height, stats.crouch_transition_speed * delta)
	_collision.position.y = shape.height / 2.0
	_head.position.y = _head_stand_y - (_stand_height - shape.height)


func _try_dash(direction: Vector3) -> void:
	if _charges < 1.0 or _dash_time_left > 0.0:
		return
	if not is_on_floor() and not stats.dash_in_air:
		return
	if direction == Vector3.ZERO:
		direction = -transform.basis.z
	_charges -= 1.0
	_dash_time_left = stats.dash_duration
	_dash_velocity = direction * (stats.dash_distance / stats.dash_duration)
	stamina_changed.emit(_charges, stats.stamina)


func _recharge_dash(delta: float) -> void:
	if _charges >= stats.stamina:
		return
	_charges = minf(_charges + delta / stats.dash_recharge_seconds, stats.stamina)
	stamina_changed.emit(_charges, stats.stamina)

func get_health() -> float:
	return _health


## Segundos hasta el próximo HP regenerado (0 si la vida está llena o ya escapó).
func get_regen_seconds_left() -> float:
	if _escaped or _health >= stats.max_health:
		return 0.0
	if _time_since_damage < stats.regen_delay_seconds:
		return stats.regen_delay_seconds - _time_since_damage + stats.regen_interval_seconds
	return stats.regen_interval_seconds - _regen_timer


## Aplica daño (ya con el multiplicador). Al llegar a 0 emite player_escaped una sola vez.
## Acepta damage_source_position opcional para comprobar si el escudo lo bloquea de frente.
func take_damage(amount: float, damage_source_position: Vector3 = Vector3.INF) -> void:
	if _escaped or amount <= 0.0:
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
			# Bloqueo exitoso frontal
			attack_blocked.emit(amount)
			return

	_health = maxf(_health - amount * damage_taken_multiplier, 0.0)
	_time_since_damage = 0.0
	_regen_timer = 0.0
	health_changed.emit(_health, stats.max_health)
	if _health <= 0.0:
		_escaped = true
		player_escaped.emit()


## Actualiza el estado de cobertura del escudo y el multiplicador pasivo (GDD §6.1).
func _update_shield_block() -> void:
	var weapon_manager: WeaponManager = get_node_or_null("Head/Camera3D/WeaponHolder/WeaponManager")
	var has_sword_equipped: bool = false
	if weapon_manager != null:
		var current_w: Weapon = weapon_manager.get_current_weapon()
		has_sword_equipped = current_w != null and current_w.is_melee()

	# Pasiva GDD §6.1: llevar espada + escudo reduce el daño un 60%
	if has_sword_equipped:
		damage_taken_multiplier = 1.0 - stats.sword_shield_passive_reduction
	else:
		damage_taken_multiplier = 1.0

	# Bloqueo activo manteniendo clic derecho (solo con la espada equipada)
	_is_blocking = has_sword_equipped and Input.is_action_pressed("block") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


func is_blocking() -> bool:
	return _is_blocking


func _regen_health(delta: float) -> void:
	if _escaped or _health >= stats.max_health:
		return
	_time_since_damage += delta
	if _time_since_damage < stats.regen_delay_seconds:
		return
	_regen_timer += delta
	if _regen_timer >= stats.regen_interval_seconds:
		_regen_timer -= stats.regen_interval_seconds
		_health = minf(_health + stats.regen_amount, stats.max_health)
		health_changed.emit(_health, stats.max_health)


## Si caes fuera del mapa, vuelves al punto de inicio sin perder vida.
func _respawn_if_fallen() -> void:
	if global_position.y >= stats.fall_limit_y:
		return
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_dash_time_left = 0.0
	_head.rotation.x = 0.0
