class_name Shield
extends Node3D
## Escudo de Zahariel (GDD §6.1).
## Clic derecho (mantener) lo alza al frente para cubrir daño frontal.

@export var rest_position: Vector3 = Vector3(-0.35, -0.35, -0.4)
@export var rest_rotation: Vector3 = Vector3(0.0, 0.35, 0.1)
@export var block_position: Vector3 = Vector3(-0.1, -0.15, -0.32)
@export var block_rotation: Vector3 = Vector3(0.0, 0.05, 0.0)
@export var transition_speed: float = 12.0

var _player: Player
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	position = rest_position
	rotation = rest_rotation
	_create_shield_mesh()


func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		return

	# Solo es visible cuando el arma melee está activa
	var manager: WeaponManager = get_parent().get_node_or_null("WeaponManager")
	if manager != null:
		var current_w: Weapon = manager.get_current_weapon()
		visible = current_w != null and current_w.is_melee()
	else:
		visible = true

	if not visible:
		return

	var is_blocking: bool = _player.is_blocking()
	var target_pos: Vector3 = block_position if is_blocking else rest_position
	var target_rot: Vector3 = block_rotation if is_blocking else rest_rotation

	position = position.lerp(target_pos, transition_speed * delta)
	rotation.x = lerp_angle(rotation.x, target_rot.x, transition_speed * delta)
	rotation.y = lerp_angle(rotation.y, target_rot.y, transition_speed * delta)
	rotation.z = lerp_angle(rotation.z, target_rot.z, transition_speed * delta)


func _create_shield_mesh() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.28, 0.38, 0.04)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.6, 0.2) # Tono dorado/bronce acorde al GDD §13 (Zahariel lo divino)
	mat.roughness = 0.4
	mat.metallic = 0.5
	box.material = mat

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = box
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
