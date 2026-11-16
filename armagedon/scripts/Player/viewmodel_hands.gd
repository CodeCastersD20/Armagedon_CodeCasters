class_name ViewmodelHands
extends Node3D
## Posición de las dos manos de la animación de espada (Universal Animation Library 2), medida
## desde la cabeza y en ejes de cámara. La espada (mano derecha) y el escudo (mano izquierda) se
## cuelgan de aquí, así van donde está la mano y no en un punto fijo de la pantalla.
## Las animaciones horneadas están en assets/animations/universal/viewmodel_hands.res.

## Si es false, la espada y el escudo usan su animación anterior (por código).
@export var enabled: bool = true
## Desplazamiento de cada mano respecto a la cabeza, para traerlas al cuadro de la cámara.
## En reposo la mano derecha queda detrás de la cabeza, por eso hace falta desplazarla.
@export var right_offset: Vector3 = Vector3(0.3, 0.05, -0.84)
@export var left_offset: Vector3 = Vector3(-0.6, -0.05, -0.3)
@export var idle_clip: StringName = &"idle"
@export var block_clip: StringName = &"block"
@export var blend_seconds: float = 0.1

var _player: Player
var _weapon: Weapon
var _slash_alternate: bool = true
var _attacking: bool = false
var _camera: Camera3D

@onready var _right: Node3D = $RightHand
@onready var _left: Node3D = $LeftHand
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("viewmodel_hands")
	_player = get_parent() as Player
	if _player == null:
		push_error("ViewmodelHands debe ser hijo del Player")
		set_process(false)
		return
	_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	_anim.playback_default_blend_time = blend_seconds
	_anim.animation_finished.connect(_on_animation_finished)
	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager != null:
		manager.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(manager.get_current_weapon())
	_anim.play(idle_clip)


## true si las manos están activas: el interruptor del nodo y el de PlayerStats.
func is_active() -> bool:
	return (
		enabled
		and _player != null
		and _player.stats != null
		and _player.stats.pack_animations_enabled
	)


func _process(_delta: float) -> void:
	if not is_active() or _attacking:
		return
	var wanted: StringName = block_clip if _player.is_blocking() else idle_clip
	if _anim.current_animation != wanted:
		_anim.play(wanted)


## Transform de la mano derecha en ejes de cámara (ya con su desplazamiento).
func right_in_camera() -> Transform3D:
	return Transform3D(_right.basis, _right.position + right_offset)


## Transform de la mano izquierda en ejes de cámara (ya con su desplazamiento).
func left_in_camera() -> Transform3D:
	return Transform3D(_left.basis, _left.position + left_offset)


## Cámara de primera persona (aunque la vista de depuración use otra).
func first_person_camera() -> Camera3D:
	return _camera


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null and _weapon.attacked.is_connected(_on_weapon_attacked):
		_weapon.attacked.disconnect(_on_weapon_attacked)
	_weapon = weapon
	# Si se cambia de arma en pleno tajo, el clip "_rec" ya no llegará a terminar.
	_attacking = false
	if _weapon != null and _weapon.is_melee():
		_weapon.attacked.connect(_on_weapon_attacked)


func _on_weapon_attacked() -> void:
	if not is_active():
		return
	_slash_alternate = not _slash_alternate
	var clip: String = "slash_b" if _slash_alternate else "slash_a"
	if not _anim.has_animation(clip):
		return
	_attacking = true
	_anim.play(clip)
	if _anim.has_animation(clip + "_rec"):
		_anim.queue(clip + "_rec")
	else:
		_attacking = false


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name.ends_with("_rec"):
		_attacking = false
