class_name Shield
extends Node3D
## Escudo de Zahariel (GDD §6.1). Provisional: un cuadrado café en la mano izquierda.
## Clic derecho (mantener) lo alza al frente; solo se ve con el arma melee equipada.
## La lógica de bloqueo vive en Player; esto es solo la parte visual.

const SIZE: Vector3 = Vector3(0.4, 0.55, 0.05)
const COLOR: Color = Color(0.45, 0.27, 0.12)

@export var rest_position: Vector3 = Vector3(-0.52, -0.26, -0.42)
@export var rest_rotation_degrees: Vector3 = Vector3(-8.0, 15.0, -8.0)
@export var block_position: Vector3 = Vector3(-0.10, -0.06, -0.35)
@export var block_rotation_degrees: Vector3 = Vector3(4.0, -3.0, 2.0)
@export var transition_speed: float = 14.0

var _player: Player
var _bob_time: float = 0.0


func _ready() -> void:
	position = rest_position
	rotation_degrees = rest_rotation_degrees
	_build_mesh()
	# El WeaponManager es hijo del jugador y se registra antes que este nodo.
	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager != null:
		manager.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(manager.get_current_weapon())
	else:
		visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	if _player == null:
		# El jugador se registra en su grupo después que sus hijos, por eso se busca aquí.
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return

	var is_blocking: bool = _player.is_blocking()
	var target_pos: Vector3 = block_position if is_blocking else rest_position
	var target_rot: Vector3 = block_rotation_degrees if is_blocking else rest_rotation_degrees

	# Balanceo sutil al caminar cuando está en reposo
	if not is_blocking and _player.is_on_floor():
		var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
		if speed > 0.1:
			_bob_time += delta * 8.0 * speed / maxf(_player.stats.move_speed, 1.0)
			target_pos += Vector3(cos(_bob_time * 0.5) * 0.015, sin(_bob_time) * 0.012, 0.0)

	position = position.lerp(target_pos, transition_speed * delta)
	rotation.x = lerp_angle(rotation.x, deg_to_rad(target_rot.x), transition_speed * delta)
	rotation.y = lerp_angle(rotation.y, deg_to_rad(target_rot.y), transition_speed * delta)
	rotation.z = lerp_angle(rotation.z, deg_to_rad(target_rot.z), transition_speed * delta)


func _build_mesh() -> void:
	var box := BoxMesh.new()
	box.size = SIZE
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR
	box.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	add_child(mesh_instance)


func _on_weapon_changed(weapon: Weapon) -> void:
	visible = weapon != null and weapon.is_melee()
