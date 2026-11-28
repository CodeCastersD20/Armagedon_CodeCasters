class_name CatacombTorch
extends Node3D
## Antorcha de catacumba: soporte de hierro y fuego 2D pixel art animado (sprites billboard),
## con una luz cálida que parpadea. Decorativa.

const SPRITES: Texture2D = preload("res://assets/textures/transitions/catacomb_sprites.png")
const FLAME: Texture2D = preload("res://assets/textures/fire/flame_sprites.png")
const SCONCE_CELL: int = 4
const FLAME_FPS: float = 10.0

var light_range: float = 6.0
var light_energy: float = 2.2
var _flame: Sprite3D
var _light: OmniLight3D
var _time: float = 0.0
var _frame_time: float = 0.0


func _ready() -> void:
	var sconce := Sprite3D.new()
	sconce.texture = SPRITES
	sconce.hframes = 4
	sconce.vframes = 2
	sconce.frame = SCONCE_CELL
	sconce.pixel_size = 0.028
	sconce.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sconce.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sconce.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sconce.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sconce)
	_flame = Sprite3D.new()
	_flame.texture = FLAME
	_flame.hframes = 4
	_flame.frame = randi() % 4
	_flame.pixel_size = 0.04
	_flame.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_flame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flame.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_flame.shaded = false
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.position = Vector3(0.0, 0.75, 0.0)
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.light_energy = light_energy
	_light.omni_range = light_range
	_light.omni_attenuation = 1.4
	_light.position = Vector3(0.0, 1.0, 0.0)
	add_child(_light)
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	_frame_time += delta
	if _frame_time >= 1.0 / FLAME_FPS:
		_frame_time = 0.0
		_flame.frame = (_flame.frame + 1) % 4
	var flicker: float = sin(_time * 13.0) * 0.12 + sin(_time * 7.3) * 0.1
	_light.light_energy = light_energy * (1.0 + flicker)
