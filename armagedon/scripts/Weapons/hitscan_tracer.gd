class_name HitscanTracer
extends MeshInstance3D
## Estela de disparo hitscan con pooling: la cola avanza rápido hacia el impacto para que
## el arma del jugador nunca la alcance ni la atraviese al caminar hacia adelante.

const DURATION: float = 0.06
const WIDTH: float = 0.025
const TAIL_SPEED: float = 45.0

static var _pool: Array = []
static var _mesh: BoxMesh
static var _material: StandardMaterial3D
static var _self_script: GDScript

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _age: float = 0.0


static func spawn(tree: SceneTree, from_pos: Vector3, to_pos: Vector3) -> MeshInstance3D:
	if tree == null or tree.current_scene == null:
		return null
	if from_pos.distance_squared_to(to_pos) < 0.0004:
		return null
	var tracer: MeshInstance3D = _take_from_pool(tree.current_scene)
	tracer.set("_from", from_pos)
	tracer.set("_to", to_pos)
	tracer.set("_age", 0.0)
	tracer.call("_update_segment", 0.0)
	return tracer


static func prewarm(tree: SceneTree) -> void:
	if tree == null or tree.current_scene == null:
		return
	var camera: Camera3D = tree.root.get_camera_3d()
	if camera == null:
		return
	var pos: Vector3 = camera.global_position - camera.global_basis.z * 0.5
	var tracer: MeshInstance3D = _take_from_pool(tree.current_scene)
	tracer.set("_from", pos)
	tracer.set("_to", pos - camera.global_basis.z * 0.4)
	tracer.call("_update_segment", 0.0)
	tracer.set_process(false)
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(tracer):
		tracer.call("_release")


static func _take_from_pool(scene: Node) -> MeshInstance3D:
	var tracer: MeshInstance3D = null
	while not _pool.is_empty() and tracer == null:
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			var candidate := raw as MeshInstance3D
			if candidate != null and candidate.is_inside_tree():
				tracer = candidate
	if tracer == null:
		if _mesh == null:
			_material = StandardMaterial3D.new()
			_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_material.albedo_color = Color(1.0, 0.85, 0.35)
			_mesh = BoxMesh.new()
			_mesh.size = Vector3(WIDTH, WIDTH, 1.0)
			_mesh.material = _material
		if _self_script == null:
			_self_script = load("res://scripts/Weapons/hitscan_tracer.gd") as GDScript
		tracer = _self_script.new() as MeshInstance3D
		tracer.top_level = true
		tracer.mesh = _mesh
		scene.add_child(tracer)
	tracer.visible = true
	tracer.set_process(true)
	return tracer


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		_release()
		return
	_update_segment(_age * TAIL_SPEED)


func _update_segment(advance: float) -> void:
	var full_diff: Vector3 = _to - _from
	var full_len: float = full_diff.length()
	if full_len <= advance + 0.01:
		_release()
		return
	var dir: Vector3 = full_diff / full_len
	var tail: Vector3 = _from + dir * advance
	var length: float = full_len - advance
	global_position = (tail + _to) * 0.5
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	look_at(_to, up)
	scale = Vector3(1.0, 1.0, length)


func _release() -> void:
	visible = false
	set_process(false)
	if not _pool.has(self):
		_pool.append(self)
