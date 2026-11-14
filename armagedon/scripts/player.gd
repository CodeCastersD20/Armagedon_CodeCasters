class_name Player
extends CharacterBody3D
## Zahariel en primera persona: movimiento WASD, mirar con mouse, salto, dash, correr (Ctrl) y agacharse (C).

## Cargas de dash actuales (fraccionarias mientras se recarga) y máximo. Para el HUD (#88).
signal stamina_changed(current: float, maximum: float)

@export var stats: PlayerStats

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _charges: float
var _dash_time_left: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _running: bool = false
var _crouching: bool = false
var _stand_height: float
var _head_stand_y: float

@onready var _head: Node3D = $Head
@onready var _collision: CollisionShape3D = $Colison


func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	add_to_group("player")
	_collision.shape = _collision.shape.duplicate()
	_stand_height = (_collision.shape as CapsuleShape3D).height
	_head_stand_y = _head.position.y
	_charges = stats.stamina
	stamina_changed.emit(_charges, stats.stamina)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = stats.jump_velocity

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	_update_crouch(delta)
	_update_running(input_dir)

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
