class_name CreepZone
extends Node3D
## Zona de suelo dañina que deja el lanzador de creep (con pooling).

static var _pool: Array = []
static var _mesh: CylinderMesh
static var _material: StandardMaterial3D

var _radius: float = 1.5
var _damage: float = 0.0
var _tick: float = 0.5
var _tick_left: float = 0.0
var _life: float = 0.0
var _player: Node3D
var _visual: MeshInstance3D


static func spawn(
	tree: SceneTree,
	pos: Vector3,
	radius: float,
	damage: float,
	duration: float,
	tick: float,
	player: Node3D,
) -> void:
	if tree == null or tree.current_scene == null:
		return
	var zone: CreepZone = null
	while not _pool.is_empty():
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			zone = raw as CreepZone
			break
	if zone == null:
		zone = CreepZone.new()
		zone._build()
	if zone.get_parent() == null:
		tree.current_scene.add_child(zone)
	zone._activate(pos, radius, damage, duration, tick, player)


func _build() -> void:
	if _mesh == null:
		_mesh = CylinderMesh.new()
		_mesh.top_radius = 1.0
		_mesh.bottom_radius = 1.0
		_mesh.height = 0.04
		_mesh.radial_segments = 12
		_mesh.rings = 1
		_material = StandardMaterial3D.new()
		_material.albedo_color = Color(0.7, 0.2, 1.0, 0.45)
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	_visual.material_override = _material
	add_child(_visual)
	set_physics_process(false)
	visible = false


func _activate(
	pos: Vector3, radius: float, damage: float, duration: float, tick: float, player: Node3D
) -> void:
	global_position = pos + Vector3.UP * 0.05
	_radius = radius
	_damage = damage
	_tick = maxf(tick, 0.05)
	_tick_left = 0.0
	_life = duration
	_player = player
	_visual.scale = Vector3(radius, 1.0, radius)
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		set_physics_process(false)
		visible = false
		_player = null
		_pool.append(self)
		return
	_tick_left -= delta
	if _tick_left > 0.0 or _player == null or not is_instance_valid(_player):
		return
	var diff: Vector3 = _player.global_position - global_position
	if Vector2(diff.x, diff.z).length() <= _radius and absf(diff.y) < 1.5:
		_tick_left = _tick
		if _player.has_method("take_damage"):
			# Daño de suelo: sin posición de origen, así el escudo no lo bloquea.
			_player.call("take_damage", _damage, Vector3.INF)
