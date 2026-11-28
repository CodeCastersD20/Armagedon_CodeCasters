class_name CircleSeal
extends Node3D
## Sello del Jefe: aparece tras vencerlo y el jugador lo rompe (tecla interact) para empezar la
## transición al siguiente círculo (GDD §2.2). Sprite 2D pixel art que mira a la cámara, haz de
## luz que marca el sitio, luz que late y aviso al acercarse.

const SPRITES: Texture2D = preload("res://assets/textures/transitions/transition_sprites.png")
const SEAL_CELL: int = 3
const SPARK_CELL: int = 5
const FLOAT_HEIGHT: float = 1.3
const BEAM_HEIGHT: float = 30.0
const PROMPT_TEXT: String = "[F] Romper el sello"

var _sprite: Sprite3D
var _light: OmniLight3D
var _beam: MeshInstance3D
var _prompt: Label3D
var _time: float = 0.0
var _broken: bool = false


func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = SPRITES
	_sprite.hframes = 4
	_sprite.vframes = 2
	_sprite.frame = SEAL_CELL
	_sprite.pixel_size = 0.03
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.position = Vector3.UP * FLOAT_HEIGHT
	add_child(_sprite)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.omni_range = 7.0
	_light.light_energy = 2.0
	_light.position = Vector3.UP * FLOAT_HEIGHT
	add_child(_light)
	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.35
	beam_mesh.bottom_radius = 0.6
	beam_mesh.height = BEAM_HEIGHT
	beam_mesh.radial_segments = 8
	beam_mesh.rings = 1
	beam_mesh.cap_top = false
	beam_mesh.cap_bottom = false
	_beam = MeshInstance3D.new()
	_beam.mesh = beam_mesh
	_beam.material_override = CircleTransition.make_unshaded(Color(1.0, 0.6, 0.3, 0.22), true)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3.UP * BEAM_HEIGHT * 0.5
	add_child(_beam)
	_prompt = Label3D.new()
	_prompt.text = LocalizationManager.t("seal.prompt", PROMPT_TEXT)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 40
	_prompt.outline_size = 10
	_prompt.pixel_size = 0.006
	_prompt.modulate = Color(1.0, 0.92, 0.75)
	_prompt.position = Vector3.UP * (FLOAT_HEIGHT + 0.9)
	_prompt.visible = false
	add_child(_prompt)
	# Aparece creciendo desde nada.
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_BACK)


func _process(delta: float) -> void:
	if _broken:
		return
	_time += delta
	_sprite.position.y = FLOAT_HEIGHT + sin(_time * 2.2) * 0.12
	_light.light_energy = 1.6 + sin(_time * 4.0) * 0.6


func set_prompt_visible(show_prompt: bool) -> void:
	if _prompt != null and not _broken:
		_prompt.visible = show_prompt


## Destello, chispas y desaparece. Esperar con await.
func break_open() -> void:
	if _broken:
		return
	_broken = true
	_prompt.visible = false
	for i in 10:
		var spark := Sprite3D.new()
		spark.texture = SPRITES
		spark.hframes = 4
		spark.vframes = 2
		spark.frame = SPARK_CELL
		spark.pixel_size = 0.02
		spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spark.shaded = false
		spark.position = _sprite.position
		add_child(spark)
		var ang: float = TAU * float(i) / 10.0
		var target: Vector3 = (
			_sprite.position + Vector3(cos(ang), randf_range(-0.4, 0.8), sin(ang)) * 1.6
		)
		var stw: Tween = create_tween()
		stw.tween_property(spark, "position", target, 0.45).set_ease(Tween.EASE_OUT)
		stw.parallel().tween_property(spark, "pixel_size", 0.0, 0.45)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_sprite, "pixel_size", 0.09, 0.25)
	tw.tween_property(_light, "light_energy", 8.0, 0.25)
	tw.chain().set_parallel(true)
	tw.tween_property(_sprite, "pixel_size", 0.0, 0.25)
	tw.tween_property(_light, "light_energy", 0.0, 0.4)
	tw.tween_property(_beam, "scale", Vector3(0.0, 1.0, 0.0), 0.4)
	await tw.finished
