class_name DamageVignette
extends Node
## Controla la viñeta de daño y el pulso de latido cuando el jugador tiene poca vida.

const DAMAGE_VIGNETTE_SHADER: Shader = preload("res://assets/shaders/damage_vignette.gdshader")
const LOW_HP_THRESHOLD: float = 0.35

var mode: int = 2
var _rect: ColorRect
var _mat: ShaderMaterial
var _hp_ratio: float = 1.0
var _heartbeat_timer: float = 0.0


func setup(layer: CanvasLayer, initial_mode: int) -> void:
	mode = initial_mode
	_mat = ShaderMaterial.new()
	_mat.shader = DAMAGE_VIGNETTE_SHADER
	_mat.set_shader_parameter("mode", mode)
	_rect = ColorRect.new()
	_rect.material = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	layer.add_child(_rect)


func reset() -> void:
	_hp_ratio = 1.0
	_heartbeat_timer = 0.0
	update_shader(0.0, 0.0)


func on_health_changed(current: float, maximum: float) -> void:
	_hp_ratio = clampf(current / maxf(maximum, 0.01), 0.0, 1.0)
	update_shader(intensity_from_hp(), 0.0)


func intensity_from_hp() -> float:
	if _hp_ratio >= 0.85:
		return 0.0
	return clampf((0.85 - _hp_ratio) / 0.85, 0.0, 1.0)


func needs_heartbeat(in_transition: bool) -> bool:
	return not in_transition and _hp_ratio <= LOW_HP_THRESHOLD


func step_heartbeat(delta: float, in_transition: bool, player: Player) -> void:
	if not in_transition and _hp_ratio <= LOW_HP_THRESHOLD and player != null:
		var severity: float = clampf(1.0 - (_hp_ratio / LOW_HP_THRESHOLD), 0.0, 1.0)
		var beat_period: float = lerpf(0.95, 0.55, severity)
		_heartbeat_timer = fmod(_heartbeat_timer + delta, beat_period)
		var phase: float = _heartbeat_timer / beat_period
		var beat1: float = exp(-pow((phase - 0.12) / 0.055, 2.0))
		var beat2: float = exp(-pow((phase - 0.28) / 0.065, 2.0)) * 0.72
		var pulse_val: float = clampf(beat1 + beat2, 0.0, 1.0)
		player.set_heartbeat_fov_offset(pulse_val * lerpf(1.2, 3.0, severity))
		update_shader(intensity_from_hp(), pulse_val * severity)
	elif player != null:
		player.set_heartbeat_fov_offset(0.0)


func update_shader(intensity: float, pulse: float) -> void:
	if _mat == null:
		return
	if _rect != null:
		_rect.visible = intensity > 0.001 or pulse > 0.001
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("intensity", intensity)
	_mat.set_shader_parameter("pulse", pulse)


func cycle_mode() -> int:
	mode = (mode + 1) % 3
	update_shader(intensity_from_hp(), 0.0)
	return mode


func get_mode_name() -> String:
	match mode:
		0:
			return "Tinte"
		1:
			return "Sangre"
		_:
			return "Ambos"
