class_name PlayerArms
extends Node3D
## Brazos FPS colgados de la cámara. Eligen la animación según el arma equipada (espada y escudo,
## pistola), la guardia y la recarga, y exponen las manos para que el arma y el escudo se
## coloquen en ellas (hand_transform + hands_updated).

signal reload_finished
## Se emite cuando el esqueleto termina de actualizarse: armas y escudo se colocan en las manos.
signal hands_updated

## Si es false, las armas vuelven a su colocación anterior (animaciones del pack UAL).
@export var enabled: bool = true
@export var settings: PlayerArmsSettings

var _player: AnimationPlayer
var _skeleton: Skeleton3D
var _right_bone: int = -1
var _left_bone: int = -1
var _moving: bool = false
var _busy: bool = false  # ataque, disparo o recarga en curso
var _one_shot: StringName = &""
var _weapon: Weapon
var _body: Player
var _melee_index: int = 0


func _ready() -> void:
	add_to_group("player_arms")
	PsxStyle.apply(self)
	var found: Array[Node] = find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		push_error("PlayerArms: no hay AnimationPlayer en el modelo.")
		return
	_player = found[0] as AnimationPlayer
	_player.animation_finished.connect(_on_animation_finished)
	for anim: StringName in [settings.idle_anim, settings.walk_anim, settings.melee_idle_anim, settings.guard_anim]:
		if _player.has_animation(anim):
			_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	var skeletons: Array[Node] = find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		_right_bone = _skeleton.find_bone("hand.R")
		_left_bone = _skeleton.find_bone("hand.L")
		_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_play_base()
	# Estos brazos nacen antes que el WeaponManager (hermano más adelante en el árbol): se espera.
	_bind_manager.call_deferred()


func _bind_manager() -> void:
	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager != null:
		manager.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(manager.get_current_weapon())


func _process(_delta: float) -> void:
	if _player == null or _busy:
		return
	var wanted: StringName = _wanted_base()
	if _player.current_animation != wanted:
		_play_base()


## true si los brazos están activos y el esqueleto está listo.
func is_active() -> bool:
	return enabled and _skeleton != null and _right_bone >= 0 and _left_bone >= 0


## Transform global de la mano (derecha o izquierda) en el fotograma actual.
func hand_transform(right: bool) -> Transform3D:
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(_right_bone if right else _left_bone)


## Coloca un modelo en la mano: el punto `model_point` (coordenadas locales del modelo) queda en
## `grip_position` (ejes de la mano) con la orientación `grip_rotation_degrees`. Conserva `model_scale`.
func place_in_hand(
	model: Node3D,
	right: bool,
	grip_position: Vector3,
	grip_rotation_degrees: Vector3,
	model_point: Vector3,
	model_scale: Vector3
) -> void:
	var grip := Transform3D(Basis.from_euler(grip_rotation_degrees * (PI / 180.0)), grip_position)
	var scale_basis := Basis.from_scale(model_scale)
	model.global_transform = hand_transform(right) * grip * Transform3D(scale_basis, -(scale_basis * model_point))


func set_moving(value: bool) -> void:
	if value == _moving:
		return
	_moving = value
	if not _busy:
		_play_base()


func play_fire() -> void:
	_play_action(settings.fire_anim)


func play_reload() -> void:
	_play_action(settings.reload_anim)


func _play_action(anim: StringName, speed: float = 1.0) -> void:
	if _player == null or not _player.has_animation(anim):
		return
	_busy = true
	_one_shot = anim
	_player.play(anim, settings.blend_time, speed)


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null:
		if _weapon.attacked.is_connected(_on_weapon_attacked):
			_weapon.attacked.disconnect(_on_weapon_attacked)
		if _weapon.reload_started.is_connected(_on_weapon_reload_started):
			_weapon.reload_started.disconnect(_on_weapon_reload_started)
	_weapon = weapon
	# Cambiar de arma en pleno ataque o recarga corta la animación pendiente.
	_busy = false
	_one_shot = &""
	if _weapon != null:
		_weapon.attacked.connect(_on_weapon_attacked)
		_weapon.reload_started.connect(_on_weapon_reload_started)
	_play_base()


func _on_weapon_attacked() -> void:
	if _weapon == null:
		return
	if _weapon.is_melee():
		if settings.melee_hit_anims.is_empty():
			return
		_melee_index = (_melee_index + 1) % settings.melee_hit_anims.size()
		_play_action(settings.melee_hit_anims[_melee_index])
	else:
		_play_action(settings.fire_anim)


func _on_weapon_reload_started(seconds: float) -> void:
	if _player == null or not _player.has_animation(settings.reload_anim):
		return
	# Escala la velocidad para que la recarga dure lo que dice reload_seconds del arma.
	var length: float = _player.get_animation(settings.reload_anim).length
	_play_action(settings.reload_anim, length / maxf(seconds, 0.01))


## Postura de reposo según el arma equipada y si se cubre con el escudo.
func _wanted_base() -> StringName:
	if _weapon != null and _weapon.is_melee():
		if _is_blocking() and _player.has_animation(settings.guard_anim):
			return settings.guard_anim
		if _player.has_animation(settings.melee_idle_anim):
			return settings.melee_idle_anim
	var anim: StringName = settings.walk_anim if _moving else settings.idle_anim
	return anim if _player.has_animation(anim) else settings.idle_anim


func _is_blocking() -> bool:
	if _body == null or not is_instance_valid(_body):
		_body = get_tree().get_first_node_in_group("player") as Player
	return _body != null and _body.is_blocking()


func _play_base() -> void:
	if _player == null:
		return
	_player.play(_wanted_base(), settings.blend_time)


func _on_animation_finished(anim: StringName) -> void:
	if anim == _one_shot:
		if anim == settings.reload_anim:
			reload_finished.emit()
		_busy = false
		_one_shot = &""
		_play_base()


func _on_skeleton_updated() -> void:
	if is_active():
		hands_updated.emit()
