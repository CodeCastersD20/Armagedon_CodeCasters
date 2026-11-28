class_name PlayerCameraFeel
extends RefCounted
## Maneja el tilt de cámara, FOV dinámico, hit-punch, sacudidas y overlays de stun/slide.

var _head: Node3D
var _camera: Camera3D
var _stats: PlayerStats
var _stun_rect: ColorRect
var _slide_lines: ColorRect

var _base_fov: float = 90.0
var _dynamic_fov_offset: float = 0.0
var _heartbeat_fov_offset: float = 0.0
var _hit_punch: float = 0.0
var _slam_shake_strength: float = 0.0
var _slam_shake_time_left: float = 0.0
var _stun_effect_intensity: float = 0.0
var _slide_effect_intensity: float = 0.0


func setup(
	head: Node3D,
	camera: Camera3D,
	stats: PlayerStats,
	stun_rect: ColorRect,
	slide_lines: ColorRect
) -> void:
	_head = head
	_camera = camera
	_stats = stats
	_stun_rect = stun_rect
	_slide_lines = slide_lines
	if _camera != null:
		_base_fov = _camera.fov


func update(
	delta: float,
	input_dir: Vector2,
	horiz_speed: float,
	is_sliding: bool,
	is_dashing: bool,
	is_stunned_now: bool
) -> void:
	var target_tilt: float = (
		-input_dir.x * deg_to_rad(_stats.camera_tilt_degrees)
		if _stats.camera_tilt_enabled
		else 0.0
	)
	if is_sliding:
		var slide_tilt_sign: float = -signf(input_dir.x) if absf(input_dir.x) > 0.1 else 1.0
		target_tilt += deg_to_rad(3.5) * slide_tilt_sign
	if is_stunned_now:
		target_tilt += deg_to_rad(4.5) * sin(float(Time.get_ticks_msec()) * 0.025)
	_head.rotation.z = lerpf(_head.rotation.z, target_tilt, 10.0 * delta)
	_update_slide_visual(delta, is_sliding)
	_update_stun_visual(delta, is_stunned_now)
	if _camera == null:
		return

	var target_fov_boost: float = 0.0
	if is_dashing:
		target_fov_boost = _stats.dash_fov_boost
	elif is_sliding:
		target_fov_boost = maxf(_stats.speed_fov_boost, 6.0)
	elif horiz_speed > _stats.move_speed * 1.15:
		var t: float = clampf(
			(horiz_speed - _stats.move_speed) / maxf(_stats.dash_residual_speed, 1.0), 0.0, 1.0
		)
		target_fov_boost = _stats.speed_fov_boost * t
	var fov_rate: float = 18.0 if target_fov_boost > _dynamic_fov_offset else 7.5
	_dynamic_fov_offset = lerpf(_dynamic_fov_offset, target_fov_boost, fov_rate * delta)

	if _hit_punch > 0.001:
		_hit_punch = move_toward(_hit_punch, 0.0, delta * 12.0)
	var envelope: float = 0.0
	if _slam_shake_time_left > 0.0:
		envelope = clampf(_slam_shake_time_left / maxf(_stats.slam_shake_duration, 0.01), 0.0, 1.0)
		_slam_shake_time_left = maxf(_slam_shake_time_left - delta, 0.0)
		if _slam_shake_time_left <= 0.0:
			_slam_shake_strength = 0.0
	var shake: float = _slam_shake_strength * envelope
	var rotation_shake: float = deg_to_rad(_stats.slam_shake_rotation_degrees) * envelope
	var impact: float = _hit_punch + shake
	if impact > 0.001:
		_camera.position = Vector3(
			randf_range(-0.06, 0.06) * impact,
			randf_range(-0.06, 0.06) * impact - 0.04 * shake,
			0.045 * impact
		)
	elif _camera.position != Vector3.ZERO:
		_camera.position = Vector3.ZERO
	if rotation_shake > 0.0001:
		_camera.rotation = Vector3(
			randf_range(-rotation_shake, rotation_shake),
			randf_range(-rotation_shake, rotation_shake),
			randf_range(-rotation_shake, rotation_shake) * 0.5
		)
	elif _camera.rotation != Vector3.ZERO:
		_camera.rotation = Vector3.ZERO
	_apply_fov()


func add_punch(strength: float = 1.0) -> void:
	_hit_punch = clampf(maxf(_hit_punch, strength), 0.0, 1.5)


func add_shake(strength: float, duration: float) -> void:
	_slam_shake_strength = maxf(_slam_shake_strength, strength)
	_slam_shake_time_left = maxf(_slam_shake_time_left, duration)


func set_heartbeat_fov_offset(offset: float) -> void:
	_heartbeat_fov_offset = offset
	_apply_fov()


func reset() -> void:
	_dynamic_fov_offset = 0.0
	_heartbeat_fov_offset = 0.0
	_hit_punch = 0.0
	_slam_shake_strength = 0.0
	_slam_shake_time_left = 0.0
	_stun_effect_intensity = 0.0
	_slide_effect_intensity = 0.0
	if _camera != null:
		_camera.fov = _base_fov
		_camera.position = Vector3.ZERO
		_camera.rotation = Vector3.ZERO


func _apply_fov() -> void:
	if _camera != null:
		_camera.fov = _base_fov + _dynamic_fov_offset + _heartbeat_fov_offset + (_hit_punch * 4.5)


func _update_stun_visual(delta: float, is_stunned_now: bool) -> void:
	var target: float = 1.0 if is_stunned_now else 0.0
	var rate: float = 22.0 if is_stunned_now else 8.0
	var next_intensity: float = move_toward(_stun_effect_intensity, target, rate * delta)
	if is_equal_approx(next_intensity, _stun_effect_intensity):
		return
	_stun_effect_intensity = next_intensity
	if _stun_rect != null and _stun_rect.material is ShaderMaterial:
		(_stun_rect.material as ShaderMaterial).set_shader_parameter(
			"intensity", _stun_effect_intensity
		)


func _update_slide_visual(delta: float, is_sliding: bool) -> void:
	var target: float = 1.0 if is_sliding else 0.0
	var rate: float = 18.0 if is_sliding else 10.0
	var next_intensity: float = move_toward(_slide_effect_intensity, target, rate * delta)
	if is_equal_approx(next_intensity, _slide_effect_intensity):
		return
	_slide_effect_intensity = next_intensity
	if _slide_lines != null and _slide_lines.material is ShaderMaterial:
		(_slide_lines.material as ShaderMaterial).set_shader_parameter(
			"intensity", _slide_effect_intensity
		)
