class_name DamageNumber
extends Label3D
## Número flotante de daño: sube, se desvanece y se libera solo.

const COLOR_NORMAL := Color.WHITE
const COLOR_CRITICAL := Color(1.0, 0.1, 0.1)

## Números libres para reutilizar: evita crear y liberar un nodo por golpe.
static var _pool: Array[DamageNumber] = []

@export var rise_height: float = 1.0
@export var lifetime: float = 1.2


## Crea el número en `world_pos` y lo añade a la escena actual.
static func spawn(
	tree: SceneTree, world_pos: Vector3, amount: float, is_critical: bool = false
) -> void:
	var number: DamageNumber = _take_from_pool()
	if number == null:
		number = DamageNumber.new()
		number.top_level = true
	number.text = str(roundi(amount))
	number.modulate = COLOR_CRITICAL if is_critical else COLOR_NORMAL
	number.outline_modulate = Color.BLACK
	number.pixel_size = 0.012 if is_critical else 0.009
	if number.get_parent() == null:
		tree.current_scene.add_child(number)
	number.visible = true
	number.global_position = world_pos
	number._animate()


## Dibuja una vez los dígitos 0-9 (invisibles) para generar los glifos de la fuente al cargar,
## no en el primer golpe.
static func prewarm(tree: SceneTree) -> void:
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	if tree.current_scene == null or camera == null:
		return
	var number: DamageNumber = _take_from_pool()
	if number == null:
		number = DamageNumber.new()
		number.top_level = true
		tree.current_scene.add_child(number)
	number.text = "0123456789"
	number.modulate.a = 0.0
	number.outline_modulate.a = 0.0
	number.visible = true
	number.global_position = camera.global_position - camera.global_basis.z * 1.0
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(number):
		number._release()


static func _take_from_pool() -> DamageNumber:
	while not _pool.is_empty():
		var raw: Variant = _pool.pop_back()
		# Si cambió la escena, los números del pool pueden estar liberados; validar antes de tipar.
		if is_instance_valid(raw):
			var number := raw as DamageNumber
			if number != null and number.is_inside_tree():
				return number
	return null


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
	(
		tween
		. tween_property(self, "global_position:y", global_position.y + rise_height, lifetime)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.tween_property(self, "outline_modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.chain().tween_callback(_release)


func _release() -> void:
	visible = false
	_pool.append(self)
