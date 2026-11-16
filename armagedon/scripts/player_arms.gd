class_name PlayerArms
extends Node3D
## Brazos FPS colgados de la cámara. Reproduce idle, caminar, disparar y recargar.

signal reload_finished

@export var settings: PlayerArmsSettings

var _player: AnimationPlayer
var _moving: bool = false
var _busy: bool = false  # disparo o recarga en curso


func _ready() -> void:
	PsxStyle.apply(self)
	var found: Array[Node] = find_children("*", "AnimationPlayer", true, false)
	if found.is_empty():
		push_error("PlayerArms: no hay AnimationPlayer en el modelo.")
		return
	_player = found[0] as AnimationPlayer
	_player.animation_finished.connect(_on_animation_finished)
	for anim: StringName in [settings.idle_anim, settings.walk_anim]:
		if _player.has_animation(anim):
			_player.get_animation(anim).loop_mode = Animation.LOOP_LINEAR
	_play_base()


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


func _play_action(anim: StringName) -> void:
	if _player == null or not _player.has_animation(anim):
		return
	_busy = true
	_player.play(anim, settings.blend_time)


func _play_base() -> void:
	if _player == null:
		return
	var anim: StringName = settings.walk_anim if _moving else settings.idle_anim
	if not _player.has_animation(anim):
		anim = settings.idle_anim
	_player.play(anim, settings.blend_time)


func _on_animation_finished(anim: StringName) -> void:
	if anim == settings.reload_anim:
		reload_finished.emit()
	if anim == settings.fire_anim or anim == settings.reload_anim:
		_busy = false
		_play_base()
