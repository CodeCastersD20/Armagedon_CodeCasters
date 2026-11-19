class_name Pistol
extends Weapon
## Pistola: reproduce las animaciones del modelo (fire, reload) y aplica recoil e
## inclinación procedurales con los valores de su WeaponData (data/weapons/pistol.tres).

# Fracciones de la recarga: baja la inclinación, se mantiene y vuelve.
const TILT_IN: float = 0.18
const TILT_HOLD_END: float = 0.64
const TILT_OUT: float = 0.28
# Fracción del tiempo de recuperación que tarda la subida del recoil.
const KICK_IN: float = 0.12

var _base_rotation: Vector3
var _base_y: float
var _pose_tween: Tween
var _fire_clip: StringName = &""
var _reload_clip: StringName = &""

@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	super._ready()
	_base_rotation = rotation
	_base_y = position.y
	# Los nombres de clip se resuelven una vez, no en cada disparo.
	_fire_clip = _find_clip("fire")
	_reload_clip = _find_clip("reload")
	attacked.connect(_on_attacked)
	reload_started.connect(_on_reload_started)


func _on_attacked() -> void:
	var clip: StringName = _fire_clip
	if clip != &"":
		_anim.stop()
		_anim.play(clip)
	_play_recoil()


func _on_reload_started(seconds: float) -> void:
	var clip: StringName = _reload_clip
	if clip != &"":
		# Escala la velocidad para que dure lo que dice reload_seconds del .tres.
		var length: float = _anim.get_animation(clip).length
		_anim.play(clip, -1.0, length / maxf(seconds, 0.01))
	_play_reload_tilt(seconds)


## Sube el cañón y el arma, y los devuelve a su sitio.
func _play_recoil() -> void:
	if data.recoil_kick_degrees == 0.0 and data.recoil_lift == 0.0:
		return
	_reset_pose_tween()
	var total: float = maxf(data.recoil_recovery_seconds, 0.01)
	var kick: float = _base_rotation.x + deg_to_rad(data.recoil_kick_degrees)
	var up: float = _base_y + data.recoil_lift
	_pose_tween.tween_property(self, "rotation:x", kick, total * KICK_IN)
	_pose_tween.parallel().tween_property(self, "position:y", up, total * KICK_IN)
	_pose_tween.tween_property(self, "rotation:x", _base_rotation.x, total * (1.0 - KICK_IN))
	_pose_tween.parallel().tween_property(
		self, "position:y", _base_y, total * (1.0 - KICK_IN)
	)


## Inclina el arma mientras el cargador sale y entra.
func _play_reload_tilt(seconds: float) -> void:
	if (
		data.reload_tilt_pitch_degrees == 0.0
		and data.reload_tilt_roll_degrees == 0.0
		and data.reload_tilt_drop == 0.0
	):
		return
	_reset_pose_tween()
	var pitch: float = _base_rotation.x - deg_to_rad(data.reload_tilt_pitch_degrees)
	var roll: float = _base_rotation.z - deg_to_rad(data.reload_tilt_roll_degrees)
	var drop: float = _base_y - data.reload_tilt_drop
	var t_in: float = seconds * TILT_IN
	var t_hold: float = seconds * (TILT_HOLD_END - TILT_IN)
	var t_out: float = seconds * TILT_OUT
	(
		_pose_tween
		. tween_property(self, "rotation:x", pitch, t_in)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_pose_tween.parallel().tween_property(self, "rotation:z", roll, t_in)
	_pose_tween.parallel().tween_property(self, "position:y", drop, t_in)
	_pose_tween.tween_interval(t_hold)
	_pose_tween.tween_property(self, "rotation:x", _base_rotation.x, t_out)
	_pose_tween.parallel().tween_property(self, "rotation:z", _base_rotation.z, t_out)
	_pose_tween.parallel().tween_property(self, "position:y", _base_y, t_out)


## Al guardar el arma se cancela la recarga y se limpia la pose: sin esto el tween y el clip
## quedan pausados y se reanudan al volver a equiparla.
func cancel_reload() -> void:
	super.cancel_reload()
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_anim.stop()
	rotation = _base_rotation
	position.y = _base_y


func _reset_pose_tween() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween()


## Busca la animación por nombre, con o sin prefijo de librería ("fire" o "lib/fire").
func _find_clip(clip_name: String) -> StringName:
	for anim_name in _anim.get_animation_list():
		if anim_name == clip_name or anim_name.ends_with("/" + clip_name):
			return anim_name
	return &""
