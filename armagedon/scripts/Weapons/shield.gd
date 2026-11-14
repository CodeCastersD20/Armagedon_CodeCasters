class_name Shield
extends Node3D
## Escudo de Zahariel (GDD §6.1).
## Clic derecho (mantener) lo alza al frente para cubrir daño frontal.
## Modelo PSX (Shield.glb) posicionado en la mano izquierda del jugador.

const SHIELD_MODEL_SCENE: PackedScene = preload("res://assets/models/weapons/psx_weapons/Shield.glb")

@export var rest_position: Vector3 = Vector3(-0.32, -0.26, -0.42)
@export var rest_rotation_degrees: Vector3 = Vector3(-8.0, -15.0, 8.0)
@export var block_position: Vector3 = Vector3(-0.10, -0.06, -0.35)
@export var block_rotation_degrees: Vector3 = Vector3(4.0, -3.0, 2.0)
@export var shield_scale: Vector3 = Vector3(0.35, 0.35, 0.35):
	set(val):
		shield_scale = val
		if _model_instance != null:
			_model_instance.scale = shield_scale
			_model_instance.position = Vector3(0.0, -0.38 * shield_scale.y, 0.0)

@export var transition_speed: float = 14.0

var _player: Player
var _model_instance: Node3D
var _bob_time: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	position = rest_position
	rotation_degrees = rest_rotation_degrees
	_setup_shield_model()


func _setup_shield_model() -> void:
	if SHIELD_MODEL_SCENE == null:
		return
	_model_instance = SHIELD_MODEL_SCENE.instantiate()
	# El modelo base tiene el frente hacia +X y centro en Y=+0.38
	# Lo rotamos 90° en Y para que mire al frente (-Z) y lo centramos en el pivote
	_model_instance.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_model_instance.scale = shield_scale
	_model_instance.position = Vector3(0.0, -0.38 * shield_scale.y, 0.0)
	add_child(_model_instance)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		return

	# Solo es visible cuando el arma melee está activa
	var manager: WeaponManager = get_node_or_null("../WeaponHolder/WeaponManager")
	if manager == null:
		manager = get_parent().get_node_or_null("WeaponManager")
	if manager != null:
		var current_w: Weapon = manager.get_current_weapon()
		visible = current_w != null and current_w.is_melee()
	else:
		visible = true

	if not visible:
		return

	var is_blocking: bool = _player.is_blocking()
	var target_pos: Vector3 = block_position if is_blocking else rest_position
	var target_rot_deg: Vector3 = block_rotation_degrees if is_blocking else rest_rotation_degrees

	# Balanceo sutil al caminar cuando está en reposo
	if not is_blocking and _player.is_on_floor():
		var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
		if speed > 0.1:
			var intensity: float = speed / maxf(_player.stats.move_speed, 1.0)
			_bob_time += delta * 8.0 * intensity
			target_pos += Vector3(cos(_bob_time * 0.5) * 0.015, sin(_bob_time) * 0.012, 0.0)

	position = position.lerp(target_pos, transition_speed * delta)
	rotation.x = lerp_angle(rotation.x, deg_to_rad(target_rot_deg.x), transition_speed * delta)
	rotation.y = lerp_angle(rotation.y, deg_to_rad(target_rot_deg.y), transition_speed * delta)
	rotation.z = lerp_angle(rotation.z, deg_to_rad(target_rot_deg.z), transition_speed * delta)
