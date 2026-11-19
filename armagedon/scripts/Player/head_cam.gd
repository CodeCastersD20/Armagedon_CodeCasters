class_name HeadCam
extends Node3D
## Movimiento de cámara tomado de la cabeza de las animaciones de Quaternius (Universal
## Animation Library 1 y 2): salto/aterrizaje y caminar/correr. Una animación mueve HeadPose;
## aquí se escala y se aplica a la cámara. Todo se ajusta en PlayerStats
## (data/player_stats.tres) y está APAGADO por defecto (head_cam_jump_enabled / _move_enabled).

## Velocidad horizontal (fracción de move_speed) a partir de la cual se usa "sprint".
const SPRINT_SPEED_FACTOR: float = 1.3
const MOVE_MIN_SPEED: float = 0.5

@export var camera: Camera3D

var _player: Player
var _was_on_floor: bool = true
var _camera_base_position: Vector3
var _camera_base_rotation: Vector3
var _weight: float = 0.0
var _scale_pos: float = 1.0
var _scale_rot: float = 1.0

@onready var _pose: Node3D = $HeadPose
@onready var _anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_player = get_parent() as Player
	if camera != null:
		_camera_base_position = camera.position
		_camera_base_rotation = camera.rotation


func _physics_process(_delta: float) -> void:
	if _player == null or camera == null or _player.stats == null:
		return
	var stats: PlayerStats = _player.stats
	# Con ambos efectos apagados no hay nada que animar (se evita el trabajo por tick).
	if not stats.head_cam_jump_enabled and not stats.head_cam_move_enabled:
		if _anim.is_playing():
			_anim.stop()
		return
	var on_floor: bool = _player.is_on_floor()
	var jump_name: String = _jump_prefix(stats)
	var in_jump: bool = (
		_anim.current_animation.begins_with("ninja/")
		or _anim.current_animation.begins_with("basic/")
	)

	if stats.head_cam_jump_enabled:
		if _was_on_floor and not on_floor and _player.velocity.y > 0.0:
			_play(
				jump_name + "/jump_start",
				stats.head_cam_jump_scale_position,
				stats.head_cam_jump_scale_rotation
			)
			_anim.queue(jump_name + "/jump_idle")
			_was_on_floor = on_floor
			return
		if not _was_on_floor and on_floor:
			_play(
				jump_name + "/jump_land",
				stats.head_cam_jump_scale_position,
				stats.head_cam_jump_scale_rotation
			)
			_was_on_floor = on_floor
			return
	_was_on_floor = on_floor

	if in_jump and (stats.head_cam_jump_enabled) and (_anim.is_playing()):
		return

	if stats.head_cam_move_enabled and on_floor:
		var speed: float = Vector2(_player.velocity.x, _player.velocity.z).length()
		var wanted: String = ""
		if speed > stats.move_speed * SPRINT_SPEED_FACTOR:
			wanted = "move/sprint"
		elif speed > MOVE_MIN_SPEED:
			wanted = "move/walk"
		if wanted == "":
			if _anim.current_animation.begins_with("move/"):
				_anim.stop()
		elif _anim.current_animation != wanted:
			_play(wanted, stats.head_cam_move_scale_position, stats.head_cam_move_scale_rotation)
	elif _anim.is_playing() and not in_jump:
		_anim.stop()


func _process(delta: float) -> void:
	if _player == null or camera == null or _player.stats == null:
		return
	var stats: PlayerStats = _player.stats
	# Si la animación termina, la pose queda en su último fotograma (no neutro):
	# se desvanece a cero para que la cámara vuelva derecha.
	var target: float = 1.0 if _anim.is_playing() else 0.0
	_weight = move_toward(_weight, target, delta * stats.head_cam_fade_speed)
	camera.position = _camera_base_position + _pose.position * _scale_pos * _weight
	camera.rotation = _camera_base_rotation + _pose.rotation * _scale_rot * _weight


func _play(clip: String, scale_pos: float, scale_rot: float) -> void:
	_scale_pos = scale_pos
	_scale_rot = scale_rot
	_anim.play(clip)


func _jump_prefix(stats: PlayerStats) -> String:
	return "basic" if stats.head_cam_jump_style == PlayerStats.JumpStyle.BASIC else "ninja"
