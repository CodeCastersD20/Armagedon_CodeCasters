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

@export_group("Animación al atacar")
## El escudo sigue el movimiento de la mano izquierda de la animación de espada (Sword_Regular_*).
@export var attack_anim_enabled: bool = true
## Escala del recorrido de la mano (1 = el del pack). Puede salirse de la vista.
@export_range(0.0, 1.5, 0.05) var attack_anim_position_scale: float = 1.0
## Escala del giro de la mano (1 = el del pack).
@export_range(0.0, 1.5, 0.05) var attack_anim_rotation_scale: float = 1.0
## Qué tan rápido (1/segundos) vuelve a su sitio al terminar o al bloquear.
@export var attack_anim_fade_speed: float = 8.0

@export_group("Agarre en la mano izquierda")
## Giro del escudo sobre el eje del pulgar, en grados.
@export_range(-180.0, 180.0, 5.0) var grip_roll_degrees: float = 0.0
## Dónde está el puño respecto a la mano izquierda (X palma, Y dedos, Z pulgar).
@export var grip_offset: Vector3 = Vector3(0.02, 0.06, 0.0)
## Pon true si el frente del escudo queda hacia ti en vez de hacia afuera.
@export var grip_flip_front: bool = false
## Escala del modelo en la mano. Shield.glb mide 1.55 m de alto; con 0.35 queda de ~0.55 m.
@export_range(0.05, 1.0, 0.01) var model_scale: float = 0.35
## Centro del modelo Shield.glb (dónde queda el asa).
@export var model_grip_center: Vector3 = Vector3(-0.031, 0.378, 0.0)

var _hands: ViewmodelHands
var _player: Player
var _bob_time: float = 0.0
var _weapon: Weapon
var _slash_alternate: bool = true
var _pose_weight: float = 0.0
var _model_base: Transform3D

@onready var _pose: Node3D = get_node_or_null("ShieldPose")
@onready var _attack_anim: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _model: Node3D = get_node_or_null("Shield2")


func _ready() -> void:
	position = rest_position
	rotation_degrees = rest_rotation_degrees
	if _model != null:
		_model_base = _model.transform
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
	if _apply_hand_pose():
		return
	_apply_attack_pose(delta, is_blocking)


## Modo "mano real": el escudo va donde está la mano izquierda de la animación. Devuelve true si
## lo aplicó; si no hay ViewmodelHands activo, sigue la animación anterior.
func _apply_hand_pose() -> bool:
	if _model == null:
		return false
	if _hands == null:
		_hands = get_tree().get_first_node_in_group("viewmodel_hands") as ViewmodelHands
	if _hands == null or not _hands.is_active():
		return false
	var camera: Camera3D = _hands.first_person_camera()
	_model.global_transform = camera.global_transform * _hands.left_in_camera() * _grip_transform()
	return true


## Escudo dentro de la mano izquierda: su cara plana mira hacia afuera por el dorso de la mano.
## Ejes de la mano izquierda: +Y dedos, +Z pulgar, +X palma. Se gira 180° en Y como la animación.
func _grip_transform() -> Transform3D:
	var scale_vec := Vector3(model_scale, model_scale, model_scale)
	var model_to_hand := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0), Vector3(0.0, 1.0, 0.0))
	if grip_flip_front:
		model_to_hand = model_to_hand * Basis(Vector3.UP, PI)
	var roll := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(grip_roll_degrees))
	var camera_flip := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0))
	var grip_basis: Basis = camera_flip * (roll * model_to_hand)
	var origin: Vector3 = camera_flip * grip_offset - grip_basis * (model_grip_center * scale_vec)
	return Transform3D(grip_basis * Basis.from_scale(scale_vec), origin)


## true si las animaciones del pack están activas en PlayerStats.
func _pack_animation_on() -> bool:
	var player := _player
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	return player != null and player.stats != null and player.stats.pack_animations_enabled


## Mueve el modelo como la mano izquierda de la animación de ataque y lo devuelve a su sitio.
func _apply_attack_pose(delta: float, is_blocking: bool) -> void:
	if _pose == null or _attack_anim == null or _model == null:
		return
	if not _pack_animation_on():
		_model.transform = _model_base
		return
	var playing: bool = attack_anim_enabled and _attack_anim.is_playing() and not is_blocking
	_pose_weight = move_toward(_pose_weight, 1.0 if playing else 0.0, delta * attack_anim_fade_speed)
	if _pose_weight <= 0.0 and not playing:
		_model.transform = _model_base
		return
	# La animación está en ejes de cámara; el escudo está girado, se pasa a sus ejes locales.
	var offset: Vector3 = basis.inverse() * (_pose.position * attack_anim_position_scale)
	var turn: Quaternion = Quaternion.IDENTITY.slerp(
		_pose.quaternion, clampf(attack_anim_rotation_scale, 0.0, 1.0)
	)
	var animated := Transform3D(
		basis.inverse() * Basis(turn) * basis * _model_base.basis,
		_model_base.origin + offset
	)
	_model.transform = _model_base.interpolate_with(animated, _pose_weight)


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
	if _weapon != null and _weapon.attacked.is_connected(_on_weapon_attacked):
		_weapon.attacked.disconnect(_on_weapon_attacked)
	_weapon = weapon
	if _weapon != null and _weapon.is_melee():
		_weapon.attacked.connect(_on_weapon_attacked)


## Reproduce el mismo tajo (A/B alternados) que la espada, con la mano izquierda.
func _on_weapon_attacked() -> void:
	if not attack_anim_enabled or _attack_anim == null or not _pack_animation_on():
		return
	_slash_alternate = not _slash_alternate
	var clip: String = "slash_b" if _slash_alternate else "slash_a"
	_attack_anim.play(clip)
	_attack_anim.queue(clip + "_rec")
