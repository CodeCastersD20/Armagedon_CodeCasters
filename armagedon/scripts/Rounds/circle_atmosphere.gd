class_name CircleAtmosphere
extends Node
## Controla niebla, cielo, luna, cartel y tinte del coliseo por círculo del Infierno,
## además del fundido de pantalla completa (`fade_screen`).

const CIRCLE_FOG_COLORS: Array[Color] = [
	Color(0.28, 0.28, 0.30, 1.0),  # 1-10: Limbo (gris ceniza)
	Color(0.45, 0.05, 0.25, 1.0),  # 11-20: Lujuria
	Color(0.16, 0.34, 0.08, 1.0),  # 21-30: Gula
	Color(0.48, 0.28, 0.04, 1.0),  # 31-40: Avaricia y Prodigalidad
	Color(0.55, 0.02, 0.02, 1.0),  # 41-50: Ira y Pereza
	Color(0.55, 0.16, 0.02, 1.0),  # 51-60: Herejía
	Color(0.38, 0.01, 0.03, 1.0),  # 61-70: Violencia
	Color(0.26, 0.06, 0.38, 1.0),  # 71-80: Fraude
	Color(0.08, 0.22, 0.42, 1.0),  # 81-90: Traición
	Color(0.22, 0.01, 0.05, 1.0),  # 91-100: Castillo de Lucifer / Lucifer
	Color(0.05, 0.02, 0.10, 1.0),  # 101+: El Vacío
]
const CIRCLE_NAMES: Array[String] = [
	"1. LIMBO",
	"2. LUJURIA",
	"3. GULA",
	"4. AVARICIA Y PRODIGALIDAD",
	"5. IRA Y PEREZA",
	"6. HEREJÍA",
	"7. VIOLENCIA",
	"8. FRAUDE",
	"9. TRAICIÓN",
	"CASTILLO DE LUCIFER",
	"EL VACÍO",
]
const ARENA_STONE_COLOR: Color = Color(0.62, 0.6, 0.58, 1.0)
const ARENA_TINT_AMOUNT: float = 0.45
const SFX_CIRCLE_BELL: AudioStream = preload("res://assets/audio/sfx/transitions/SFX_Bell_Toll.ogg")
const MOON_PHASE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/textures/moon/moon_phase_1.png"),
	preload("res://assets/textures/moon/moon_phase_2.png"),
	preload("res://assets/textures/moon/moon_phase_3.png"),
	preload("res://assets/textures/moon/moon_phase_4.png"),
	preload("res://assets/textures/moon/moon_phase_5.png"),
	preload("res://assets/textures/moon/moon_phase_6.png"),
	preload("res://assets/textures/moon/moon_phase_7.png"),
	preload("res://assets/textures/moon/moon_phase_8.png"),
]
const MOON_LUCIFER_COLOR: Color = Color(0.95, 0.14, 0.12, 1.0)
const MOON_NEUTRAL_COLOR: Color = Color(0.86, 0.84, 0.80, 1.0)

var _world: Node3D
var _world_env: WorldEnvironment
var _moon_mat: ShaderMaterial
var _moon_color: Color = Color(0.92, 0.12, 0.1, 1.0)
var _circle_tint_moon: bool = true
var _circle_label: Label
var _circle_tween: Tween
var _fade_rect: ColorRect
var _current_circle_idx: int = -1
var _arena_shapes: Array[CSGPrimitive3D] = []
var _arena_materials: Dictionary = {}


func setup(
	world: Node3D,
	tint_moon: bool,
	banner_layer: CanvasLayer,
	fade_layer: CanvasLayer
) -> void:
	_world = world
	_circle_tint_moon = tint_moon
	if _world != null:
		_world_env = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
		var moon := _world.get_node_or_null("LunaRoja") as MeshInstance3D
		if moon != null:
			_moon_mat = moon.get_active_material(0) as ShaderMaterial
			if _moon_mat != null:
				var initial: Variant = _moon_mat.get_shader_parameter("albedo_color")
				if initial is Color:
					_moon_color = initial as Color

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.visible = false
	fade_layer.add_child(_fade_rect)

	_circle_label = Label.new()
	_circle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_circle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_circle_label.offset_top = 18.0
	_circle_label.offset_bottom = 48.0
	_circle_label.add_theme_font_size_override("font_size", 18)
	_circle_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	_circle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_circle_label.add_theme_constant_override("outline_size", 4)
	_circle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle_label.visible = false
	banner_layer.add_child(_circle_label)


func get_fade_rect() -> ColorRect:
	return _fade_rect


func set_fade_immediate(color: Color, is_visible: bool) -> void:
	if _fade_rect == null:
		return
	_fade_rect.color = color
	_fade_rect.visible = is_visible


func circle_index_for_round(round_number: int) -> int:
	if round_number >= 101:
		return 10
	if round_number >= 91:
		return 9
	return clampi(floori(float(maxi(round_number, 1) - 1) / 10.0), 0, 8)


func get_circle_fog_color(circle_idx: int) -> Color:
	return CIRCLE_FOG_COLORS[clampi(circle_idx, 0, CIRCLE_FOG_COLORS.size() - 1)]


func get_circle_name(circle_idx: int) -> String:
	var clamped: int = clampi(circle_idx, 0, CIRCLE_NAMES.size() - 1)
	return LocalizationManager.t("circle.%d" % clamped, CIRCLE_NAMES[clamped])


func apply_circle_fog(round_number: int, instant: bool) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var idx: int = circle_index_for_round(round_number)
	var target_color: Color = CIRCLE_FOG_COLORS[idx]
	var env: Environment = _world_env.environment
	if instant:
		env.fog_light_color = target_color
		_current_circle_idx = -1
		if _circle_label != null:
			_circle_label.visible = false
	else:
		var fog_tw: Tween = create_tween()
		fog_tw.tween_property(env, "fog_light_color", target_color, 1.5)
		if idx != _current_circle_idx:
			_current_circle_idx = idx
			_show_circle_banner(get_circle_name(idx))
	_apply_moon_for_round(round_number, idx, target_color, instant)
	_apply_arena_tint(idx)


func apply_circle_for_round(round_number: int, show_banner: bool) -> void:
	var idx: int = circle_index_for_round(round_number)
	var color: Color = CIRCLE_FOG_COLORS[idx]
	if _world_env != null and _world_env.environment != null:
		_world_env.environment.fog_light_color = color
	_apply_moon_for_round(round_number, idx, color, true)
	_apply_arena_tint(idx)
	_current_circle_idx = idx
	if show_banner:
		show_circle_banner_for_index(idx)


func show_circle_banner_for_index(circle_idx: int) -> void:
	_show_circle_banner(get_circle_name(circle_idx))


func fade_screen(color: Color, target_alpha: float, seconds: float) -> Tween:
	if _fade_rect == null:
		return null
	var clamped: float = clampf(target_alpha, 0.0, 1.0)
	_fade_rect.color = Color(color.r, color.g, color.b, _fade_rect.color.a)
	_fade_rect.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_fade_rect, "color:a", clamped, maxf(seconds, 0.01))
	if clamped <= 0.001:
		tw.tween_callback(func() -> void: _fade_rect.visible = false)
	return tw


func _apply_arena_tint(circle_idx: int) -> void:
	if _arena_shapes.is_empty():
		var root: Node = get_tree().current_scene
		var structure: Node = root.find_child("EstructuraFija", true, false) if root else null
		if structure == null:
			return
		for node in structure.find_children("*", "CSGPrimitive3D", true, false):
			var shape := node as CSGPrimitive3D
			if shape != null and shape.operation == CSGShape3D.OPERATION_UNION:
				_arena_shapes.append(shape)
	var material: StandardMaterial3D = null
	if circle_idx > 0:
		if not _arena_materials.has(circle_idx):
			var tinted := StandardMaterial3D.new()
			var fog: Color = CIRCLE_FOG_COLORS[circle_idx]
			tinted.albedo_color = ARENA_STONE_COLOR.lerp(fog.lightened(0.25), ARENA_TINT_AMOUNT)
			tinted.roughness = 1.0
			_arena_materials[circle_idx] = tinted
		material = _arena_materials[circle_idx]
	for shape in _arena_shapes:
		if shape.material != material:
			shape.material = material


func _apply_moon_for_round(
	round_number: int, circle_idx: int, circle_color: Color, instant: bool
) -> void:
	var is_lucifer: bool = circle_idx == 9
	var phase_idx: int = (
		0 if is_lucifer else posmod(maxi(round_number, 1) - 1, MOON_PHASE_TEXTURES.size())
	)
	var tinted_circle: Color = Color.from_hsv(
		circle_color.h, circle_color.s, clampf(circle_color.v + 0.45, 0.75, 1.0), 1.0
	)
	var target_moon_color: Color = (
		MOON_LUCIFER_COLOR
		if is_lucifer
		else (tinted_circle if _circle_tint_moon else MOON_NEUTRAL_COLOR)
	)
	if _moon_mat != null:
		_moon_mat.set_shader_parameter("albedo_texture", MOON_PHASE_TEXTURES[phase_idx])
		if instant:
			_set_moon_color(target_moon_color)
		else:
			create_tween().tween_method(_set_moon_color, _moon_color, target_moon_color, 1.5)
	if _circle_tint_moon and _world_env != null and _world_env.environment != null:
		var sky := _world_env.environment.sky
		var sky_mat := sky.sky_material as ProceduralSkyMaterial if sky != null else null
		if sky_mat != null:
			var horizon: Color = circle_color.darkened(0.2)
			if instant:
				sky_mat.sky_horizon_color = horizon
				sky_mat.ground_horizon_color = horizon
			else:
				var sky_tw: Tween = create_tween()
				sky_tw.set_parallel(true)
				sky_tw.tween_property(sky_mat, "sky_horizon_color", horizon, 1.5)
				sky_tw.tween_property(sky_mat, "ground_horizon_color", horizon, 1.5)


func _set_moon_color(color: Color) -> void:
	_moon_color = color
	if _moon_mat != null:
		_moon_mat.set_shader_parameter("albedo_color", color)


func _show_circle_banner(circle_name: String) -> void:
	if _circle_label == null:
		return
	if _circle_tween != null and _circle_tween.is_running():
		_circle_tween.kill()
	_circle_label.text = circle_name
	AudioManager.play_sfx(SFX_CIRCLE_BELL, -2.0)
	_circle_label.modulate.a = 0.0
	_circle_label.visible = true
	_circle_tween = create_tween()
	_circle_tween.tween_property(_circle_label, "modulate:a", 1.0, 0.4)
	_circle_tween.tween_interval(2.2)
	_circle_tween.tween_property(_circle_label, "modulate:a", 0.0, 0.8)
	_circle_tween.tween_callback(func() -> void: _circle_label.visible = false)
