class_name CatacombShaft
extends Node3D
## Pozo de catacumba bajo el hueco central (elevador y derrumbe): cilindro visto por dentro con
## paredes de osario y nichos, anillos de antorchas, cráneos y brazos que se lanzan al pasar y
## almas que cruzan gritando. Todo es hijo de este nodo: se libera de una vez.

const WALL_SHADER: Shader = preload("res://assets/shaders/catacomb_wall.gdshader")
const WALL_TEXTURE: Texture2D = preload("res://assets/textures/transitions/catacomb_wall.png")
## Metros que cubre una repetición de la textura (64x128 px) en ancho y alto.
const TILE_METERS: Vector2 = Vector2(2.0, 4.0)
const TORCH_RING_SPACING: float = 5.0
const TORCHES_PER_RING: int = 4

var radius: float = 5.3
var height: float = 44.0
## Y del borde de arriba del pozo (bajo el suelo de la arena).
var top_y: float = -0.5
var lurker_count: int = 40
var soul_count: int = 10


## Construye todo. Llamar después de add_child(), con el pozo en el origen y sin girar.
func build() -> void:
	_build_walls()
	_build_torches()
	_build_lurkers()
	_build_souls()


func _build_walls() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 6
	mesh.cap_top = false
	mesh.cap_bottom = true
	var mat := ShaderMaterial.new()
	mat.shader = WALL_SHADER
	mat.set_shader_parameter("wall_texture", WALL_TEXTURE)
	var circumference: float = TAU * radius
	mat.set_shader_parameter(
		"tiles", Vector2(roundf(circumference / TILE_METERS.x), height / TILE_METERS.y)
	)
	var walls := MeshInstance3D.new()
	walls.mesh = mesh
	walls.material_override = mat
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walls)
	walls.global_position = Vector3(0.0, top_y - height * 0.5, 0.0)


func _build_torches() -> void:
	var rings: int = int(height / TORCH_RING_SPACING)
	for r in rings:
		var y: float = top_y - 2.5 - float(r) * TORCH_RING_SPACING
		for i in TORCHES_PER_RING:
			var ang: float = TAU * (float(i) + 0.5 * float(r % 2)) / float(TORCHES_PER_RING)
			var torch := CatacombTorch.new()
			add_child(torch)
			torch.global_position = Vector3(cos(ang), 0.0, sin(ang)) * (radius - 0.25)
			torch.global_position.y = y


func _build_lurkers() -> void:
	for i in maxi(lurker_count, 0):
		var lurker := WallLurker.new()
		lurker.kind = WallLurker.Kind.ARM if i % 4 == 3 else WallLurker.Kind.SKULL
		var ang: float = randf() * TAU
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		lurker.outward = -dir
		lurker.trigger_distance = 3.2
		# Posición antes de add_child: el lurker guarda su hueco en _ready (el pozo está en el
		# origen, así que local = mundo).
		lurker.position = (
			dir * (radius - 0.3) + Vector3.UP * (top_y - randf_range(1.0, height * 0.6))
		)
		add_child(lurker)


func _build_souls() -> void:
	for i in maxi(soul_count, 0):
		var soul := TransitionSoul.new()
		add_child(soul)
		var ang: float = randf() * TAU
		soul.global_position = Vector3(cos(ang) * (radius - 1.0), 0.0, sin(ang) * (radius - 1.0))
		soul.global_position.y = top_y - randf_range(2.0, height * 0.6)
		# Cruzan el pozo de pared a pared mientras suben, gritando.
		var across: Vector3 = -soul.global_position * Vector3(2.0, 0.0, 2.0)
		var tw: Tween = soul.create_tween().set_loops()
		var dur: float = randf_range(3.0, 5.0)
		tw.tween_property(soul, "global_position", across + Vector3.UP * 3.0, dur).as_relative()
		tw.tween_property(soul, "global_position", -across - Vector3.UP * 3.0, dur).as_relative()
