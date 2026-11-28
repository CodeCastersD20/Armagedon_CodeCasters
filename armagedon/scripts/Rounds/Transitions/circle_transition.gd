class_name CircleTransition
extends Node3D
## Base de las transiciones entre círculos (GDD §2.2). El director la instancia, la mete en la
## escena, llama a prepare() antes de mostrar el sello y a play() al romperlo; play() termina
## cuando el jugador ya está en la arena del nuevo círculo. Cada subclase construye su propia
## geometría como hijos de este nodo (se libera entera al terminar).

const SPRITES: Texture2D = preload("res://assets/textures/transitions/transition_sprites.png")
## Celdas del atlas (4x2 de 32x32): almas 0-2, sello 3, polvo 4, chispa 5, eslabón 6, brazo 7.
const SPRITE_SOUL: int = 0
const SPRITE_SEAL: int = 3
const SPRITE_DUST: int = 4
const SPRITE_SPARK: int = 5
const SPRITE_CHAIN: int = 6
const SPRITE_ARM: int = 7
const SFX_RUMBLE: AudioStream = preload("res://assets/audio/sfx/transitions/SFX_Rumble.ogg")
const SFX_STONE: AudioStream = preload("res://assets/audio/sfx/transitions/SFX_Stone_Crack.ogg")
const SFX_SOUL: AudioStream = preload("res://assets/audio/sfx/transitions/SFX_Soul_Wail.ogg")

var ctx: CircleTransitionContext
var cfg: CircleTransitionData
## true tras cancel(): las subclases lo comprueban después de cada await (alive()).
var cancelled: bool = false


func setup(context: CircleTransitionContext, data: CircleTransitionData) -> void:
	ctx = context
	cfg = data


## Antes de que aparezca el sello (p. ej. nivelar la plataforma). Puede esperar con await.
func prepare() -> void:
	await get_tree().process_frame


## Dónde aparece el sello. Por defecto donde murió el jefe, fuera del hueco central.
func get_seal_position() -> Vector3:
	return ctx.safe_floor_point(ctx.boss_death_position)


## La transición entera. Al volver, el jugador debe estar en la arena del nuevo círculo y con
## el control devuelto.
func play() -> void:
	await get_tree().process_frame
	ctx.swap_circle(true)


## Corta la transición (cambio de escena, escape): deja al jugador libre y la arena intacta.
func cancel() -> void:
	cancelled = true
	ctx.restore_player()


## Seguir tras un await solo si no se canceló ni se liberó.
func alive() -> bool:
	return not cancelled and is_inside_tree()


## Espera `seconds` (con await) respetando la cancelación.
func wait(seconds: float) -> bool:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	return alive()


## SFX por el AudioManager (bus SFX). Null = sin sonido.
static func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream != null:
		AudioManager.play_sfx(stream, volume_db)


## Sprite 2D pixel art del atlas que siempre mira a la cámara.
func make_sprite(cell: int, pixel_size: float, parent: Node = self) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = SPRITES
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.frame = cell
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	return sprite


## Material simple sin luz (para haces, núcleos, letras).
static func make_unshaded(color: Color, additive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0 or additive:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Ráfaga de polvo de sprites que se abre y se desvanece (aterrizajes, derrumbes).
func dust_burst(center: Vector3, radius: float, count: int) -> void:
	for i in count:
		var dust := make_sprite(SPRITE_DUST, 0.05)
		var ang: float = TAU * float(i) / float(maxi(count, 1)) + randf_range(-0.3, 0.3)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		dust.global_position = center + dir * radius * 0.6 + Vector3.UP * 0.2
		dust.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		dust.modulate = Color(1.0, 1.0, 1.0, 0.95)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(dust, "global_position", dust.global_position + dir * radius, 1.1)
		tw.tween_property(dust, "pixel_size", 0.11, 1.1)
		tw.tween_property(dust, "modulate:a", 0.0, 1.1).set_delay(0.3)
		tw.chain().tween_callback(dust.queue_free)
