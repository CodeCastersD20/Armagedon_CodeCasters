class_name PsxPostProcess
extends CanvasLayer
## Aplica los ajustes de data/psx_style.tres: resolución interna y dithering.

@export var settings: PsxStyleSettings

@onready var _screen: ColorRect = $Dither


func _ready() -> void:
	if settings == null:
		settings = load("res://data/psx_style.tres")
	apply_settings()


func apply_settings() -> void:
	get_window().content_scale_size = settings.internal_resolution
	var material := _screen.material as ShaderMaterial
	material.set_shader_parameter("strength", settings.dither_strength)
	material.set_shader_parameter("color_levels", settings.color_levels)
	set_dither_enabled(settings.dither_enabled)


func set_dither_enabled(enabled: bool) -> void:
	settings.dither_enabled = enabled
	_screen.visible = enabled
