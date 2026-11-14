class_name DamageNumber
extends Label3D
## Número flotante de daño: sube, se desvanece y se libera solo.

const COLOR_NORMAL := Color.WHITE
const COLOR_CRITICAL := Color(1.0, 0.1, 0.1)

@export var rise_height: float = 1.0
@export var lifetime: float = 1.2


## Crea el número en `world_pos` y lo añade a la escena actual.
static func spawn(tree: SceneTree, world_pos: Vector3, amount: float, is_critical: bool = false) -> void:
	var number := DamageNumber.new()
	number.top_level = true
	number.text = str(roundi(amount))
	number.modulate = COLOR_CRITICAL if is_critical else COLOR_NORMAL
	number.pixel_size = 0.012 if is_critical else 0.009
	tree.current_scene.add_child(number)
	number.global_position = world_pos
	number._animate()


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	outline_size = 12
	outline_modulate = Color.BLACK
	font_size = 64
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _animate() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", global_position.y + rise_height, lifetime).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.tween_property(self, "outline_modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.chain().tween_callback(queue_free)
