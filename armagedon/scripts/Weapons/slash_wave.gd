class_name SlashWave
extends MeshInstance3D
## Onda en media luna del Tajo a distancia. Avanza en línea recta, daña una vez a cada enemigo
## que atraviesa y se detiene al chocar con el mundo. Se reutiliza desde un pool estático.

## Capa 3 "Enemy" (los enemigos no chocan entre sí).
const ENEMY_MASK: int = 4
const WORLD_MASK: int = 2
const MAX_TARGETS: int = 16
const ARC_SEGMENTS: int = 14
const ARC_DEGREES: float = 120.0

static var _pool: Array = []
static var _mesh: ArrayMesh
static var _material: StandardMaterial3D

var _dir: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _config: SlashWaveData
var _crit_chance: float = 0.0
var _crit_multiplier: float = 1.0
var _exclude: Array[RID] = []
var _hit: Array = []
var _on_hit: Callable
var _box: BoxShape3D
var _query: PhysicsShapeQueryParameters3D
var _ray: PhysicsRayQueryParameters3D
var _own_material: StandardMaterial3D


## Saca una onda del pool (o crea una) y la lanza desde `origin` hacia `dir`.
static func launch(
	scene: Node,
	origin: Vector3,
	dir: Vector3,
	roll_degrees: float,
	config: SlashWaveData,
	crit_chance: float,
	crit_multiplier: float,
	exclude: Array[RID],
	on_hit: Callable
) -> SlashWave:
	var wave: SlashWave = null
	while not _pool.is_empty() and wave == null:
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			wave = raw as SlashWave
	if wave == null:
		wave = SlashWave.new()
	if wave.get_parent() != scene:
		if wave.get_parent() != null:
			wave.get_parent().remove_child(wave)
		scene.add_child(wave)
	wave._start(origin, dir, roll_degrees, config, crit_chance, crit_multiplier, exclude, on_hit)
	return wave


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mesh == null:
		_build_shared_mesh()
	mesh = _mesh
	# Material propio por instancia (se crea una vez): cada onda se desvanece por su cuenta.
	_own_material = _material.duplicate() as StandardMaterial3D
	material_override = _own_material
	_box = BoxShape3D.new()
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = _box
	_query.collision_mask = ENEMY_MASK
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = WORLD_MASK


func _start(
	origin: Vector3,
	dir: Vector3,
	roll_degrees: float,
	config: SlashWaveData,
	crit_chance: float,
	crit_multiplier: float,
	exclude: Array[RID],
	on_hit: Callable
) -> void:
	_config = config
	_dir = dir.normalized()
	_travelled = 0.0
	_crit_chance = crit_chance
	_crit_multiplier = crit_multiplier
	_exclude = exclude
	_on_hit = on_hit
	_hit.clear()
	var up: Vector3 = Vector3.UP if absf(_dir.y) < 0.99 else Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(_dir, up), origin)
	rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_degrees))
	scale = Vector3.ONE * (maxf(config.width, 0.1) / 2.0)
	_own_material.albedo_color.a = 0.95
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _config == null:
		_release()
		return
	var step: float = maxf(_config.speed, 0.1) * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _dir * step
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	_ray.from = from
	_ray.to = to
	var wall: Dictionary = space.intersect_ray(_ray)
	if not wall.is_empty():
		to = wall["position"]
	global_position = to
	_travelled += step
	_damage_enemies(space, from, to)
	var t: float = clampf(_travelled / maxf(_config.max_range, 0.1), 0.0, 1.0)
	scale = Vector3.ONE * (maxf(_config.width, 0.1) / 2.0) * lerpf(1.0, 1.35, t)
	_own_material.albedo_color.a = lerpf(0.95, 0.0, t * t)
	if not wall.is_empty() or t >= 1.0:
		_release()


func _damage_enemies(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> void:
	var length: float = from.distance_to(to) + 0.5
	_box.size = Vector3(maxf(_config.width, 0.1), maxf(_config.height, 0.1), length)
	_query.transform = Transform3D(global_basis.orthonormalized(), (from + to) * 0.5)
	_query.exclude = _exclude
	for result in space.intersect_shape(_query, MAX_TARGETS):
		var collider := result["collider"] as Node3D
		if collider == null or _hit.has(collider) or not collider.has_method("take_damage"):
			continue
		_hit.append(collider)
		var crit: bool = randf() < _crit_chance
		var amount: float = _config.damage * (_crit_multiplier if crit else 1.0)
		collider.call("take_damage", amount, crit)
		if _on_hit.is_valid():
			_on_hit.call(collider, collider.global_position + Vector3.UP * 0.9, -_dir)


func _release() -> void:
	visible = false
	set_physics_process(false)
	_on_hit = Callable()
	_config = null
	_pool.append(self)


## Media luna plana en el plano XY local (mira hacia -Z), curvada hacia adelante.
static func _build_shared_mesh() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = Color(1.0, 1.0, 1.0, 0.95)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var half: float = deg_to_rad(ARC_DEGREES * 0.5)
	for i in range(ARC_SEGMENTS + 1):
		var t: float = float(i) / float(ARC_SEGMENTS)
		var a: float = lerpf(-half, half, t)
		# Más grueso en el centro, afilado en las puntas.
		var thick: float = 0.32 * sin(t * PI) + 0.02
		var outer := Vector3(sin(a), 0.0, -cos(a) * 0.55)
		var inner := Vector3(
			sin(a) * (1.0 - thick), 0.0, -cos(a) * 0.55 * (1.0 - thick) + thick * 0.5
		)
		verts.append(outer)
		verts.append(inner)
		colors.append(Color(1.0, 0.95, 0.7, 1.0))
		colors.append(Color(0.55, 0.85, 1.0, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	_mesh.surface_set_material(0, _material)
