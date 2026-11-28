class_name TransitionSoul
extends StaticBody3D
## Alma condenada de las transiciones de círculo: sprite 2D que se mueve sola y se puede
## disparar o cortar (capa Enemy) para deshacerla en chispas. Solo decorativa: no daña.

const SPRITES: Texture2D = preload("res://assets/textures/transitions/transition_sprites.png")
const SPARK_CELL: int = 5
const ENEMY_LAYER: int = 4

var _sprite: Sprite3D
var _time: float = 0.0
var _frame_time: float = 0.0
var _popped: bool = false


func _ready() -> void:
	collision_layer = ENEMY_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	add_child(shape)
	_sprite = Sprite3D.new()
	_sprite.texture = SPRITES
	_sprite.hframes = 4
	_sprite.vframes = 2
	_sprite.frame = randi() % 3
	_sprite.pixel_size = 0.035
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.shaded = false
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
	_time = randf() * TAU


func _process(delta: float) -> void:
	if _popped:
		return
	_time += delta
	_frame_time += delta
	if _frame_time >= 0.18:
		_frame_time = 0.0
		_sprite.frame = (_sprite.frame + 1) % 3
	_sprite.position.x = sin(_time * 1.7) * 0.15


## Las armas llaman a esto: el alma estalla en chispas.
func take_damage(_amount: float, _is_critical: bool = false, _ignore_armor: bool = false) -> void:
	if _popped:
		return
	_popped = true
	collision_layer = 0
	_sprite.frame = SPARK_CELL
	var tw: Tween = create_tween()
	tw.tween_property(_sprite, "pixel_size", 0.08, 0.12)
	tw.tween_property(_sprite, "pixel_size", 0.0, 0.2)
	tw.tween_callback(queue_free)
