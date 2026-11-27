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

var _player: Player
var _bob_time: float = 0.0
var _impact_recoil: float = 0.0
var _hide_tween: Tween
var _vis_id: int = 0

@onready var _model: Node3D = get_node_or_null("Shield2")


func _ready() -> void:
	position = rest_position
	rotation_degrees = rest_rotation_degrees
	if _model != null:
		PsxStyle.apply(_model)
	else:
		_build_mesh()
		PsxStyle.apply(self)
	# El WeaponManager es hijo del jugador y se registra antes que este nodo.
	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager != null:
		manager.weapon_changed.connect(_on_weapon_changed)
		_apply_weapon_visibility(manager.get_current_weapon(), false)
	else:
		visible = false


## Cambia el modelo visible del escudo (p. ej. desde el menú debug). Conserva el transform del
## modelo actual, así que el nuevo debe tener la misma huella (alto ~1.55 m, frente hacia +X).
func set_model(scene: PackedScene) -> void:
	if scene == null:
		push_error("Shield.set_model recibió una escena nula")
		return
	var new_model := scene.instantiate() as Node3D
	if new_model == null:
		push_error("Shield.set_model: la raíz de la escena no es Node3D")
		return
	if _model != null:
		new_model.transform = _model.transform
		remove_child(_model)
		_model.queue_free()
	new_model.name = "Shield2"
	add_child(new_model)
	PsxStyle.apply(new_model)
	_model = new_model


## Ruta de la escena del modelo actual ("" si es la malla provisional).
func get_model_path() -> String:
	return _model.scene_file_path if _model != null else ""


func _process(delta: float) -> void:
	if not visible:
		return
	if _player == null:
		# El jugador se registra en su grupo después que sus hijos, por eso se busca aquí.
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
		if not _player.attack_blocked.is_connected(_on_attack_blocked):
			_player.attack_blocked.connect(_on_attack_blocked)

	_impact_recoil = move_toward(_impact_recoil, 0.0, delta * 9.0)

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
	_apply_weapon_visibility(weapon, true)


func _apply_weapon_visibility(weapon: Weapon, animate: bool) -> void:
	var show_shield: bool = weapon != null and weapon.is_melee()
	_vis_id += 1
	var req_id: int = _vis_id
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	if show_shield:
		if animate and not visible:
			position = rest_position + Vector3(-0.08, -0.35, 0.08)
			rotation_degrees = rest_rotation_degrees + Vector3(-24.0, -10.0, 12.0)
		visible = true
		return
	if not animate or not visible:
		visible = false
		return
	var drop_pos: Vector3 = rest_position + Vector3(-0.08, -0.35, 0.08)
	var drop_rot: Vector3 = rest_rotation_degrees + Vector3(-24.0, -10.0, 12.0)
	_hide_tween = create_tween()
	_hide_tween.set_parallel(true)
	_hide_tween.tween_property(self, "position", drop_pos, 0.08).set_ease(Tween.EASE_IN)
	_hide_tween.tween_property(self, "rotation_degrees", drop_rot, 0.08).set_ease(Tween.EASE_IN)
	_hide_tween.chain().tween_callback(
		func() -> void:
			if req_id == _vis_id:
				visible = false
	)


## Retroceso visual rápido del escudo al absorber un golpe frontal.
func _on_attack_blocked(_damage_blocked: float) -> void:
	_impact_recoil = 1.0
	position = block_position + Vector3(0.03, -0.02, 0.10)
	rotation_degrees = block_rotation_degrees + Vector3(-12.0, 8.0, 14.0)
