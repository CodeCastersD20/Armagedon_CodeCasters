class_name BonePiece
extends MultiMeshInstance3D
## Piezas de hueso low-poly (cráneo, costillas, fémures) que salen disparadas al morir un
## esqueleto, rebotan brevemente, quedan en el suelo y desaparecen tras unos segundos.
## Usa un único MultiMeshInstance3D (1 draw call) y buffers planos preasignados.

const WORLD_MASK: int = 2
const MAX_ACTIVE: int = 120
const MAX_AIR_TIME: float = 4.0
const SHRINK_DURATION: float = 0.25
const SPEED_MIN: float = 3.5
const SPEED_MAX: float = 7.5
const UP_SPEED_MIN: float = 3.0
const UP_SPEED_MAX: float = 6.5
const SPIN_MAX: float = 11.0
const PIECE_HALF_HEIGHT: float = 0.06
const BONE_COLOR: Color = Color(0.82, 0.78, 0.66)
const BONE_SIZES: Array[Vector3] = [
	Vector3(0.22, 0.22, 0.22),
	Vector3(0.09, 0.09, 0.44),
	Vector3(0.07, 0.07, 0.34),
	Vector3(0.22, 0.10, 0.16),
]

static var _instance: BonePiece
static var _shared_mesh: BoxMesh
static var _shared_material: ShaderMaterial
static var _ray_query: PhysicsRayQueryParameters3D

var _active_count: int = 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _pos: PackedVector3Array = PackedVector3Array()
var _rot: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _ang_vel: PackedVector3Array = PackedVector3Array()
var _base_scale: PackedVector3Array = PackedVector3Array()
var _scale: PackedVector3Array = PackedVector3Array()
var _age: PackedFloat32Array = PackedFloat32Array()
var _floor_timer: PackedFloat32Array = PackedFloat32Array()
var _floor_lifetime: PackedFloat32Array = PackedFloat32Array()
var _bounces: PackedInt32Array = PackedInt32Array()
var _on_floor: PackedByteArray = PackedByteArray()


## Lanza piezas de hueso desde `origin` que caen al suelo y desaparecen tras `floor_lifetime`.
static func spawn_burst(
	tree: SceneTree, origin: Vector3, count: int, floor_lifetime: float = 2.5
) -> void:
	if tree == null or tree.current_scene == null or count <= 0:
		return
	var mgr: BonePiece = _get_or_create_manager(tree)
	mgr._spawn(origin, count, floor_lifetime)


static func _get_or_create_manager(tree: SceneTree) -> BonePiece:
	if is_instance_valid(_instance) and _instance.is_inside_tree():
		return _instance
	_ensure_shared_resources()
	var created := BonePiece.new()
	created.top_level = true
	tree.current_scene.add_child(created)
	_instance = created
	return created


static func _ensure_shared_resources() -> void:
	if _shared_mesh == null:
		_shared_mesh = BoxMesh.new()
		_shared_mesh.size = Vector3.ONE
	if _shared_material == null:
		_shared_material = ShaderMaterial.new()
		_shared_material.shader = PsxStyle.SHADER
		_shared_material.set_shader_parameter("albedo_color", BONE_COLOR)
	if _ray_query == null:
		_ray_query = PhysicsRayQueryParameters3D.new()
		_ray_query.collision_mask = WORLD_MASK


func _init() -> void:
	_ensure_shared_resources()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _shared_mesh
	mm.instance_count = MAX_ACTIVE
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = _shared_material

	_pos.resize(MAX_ACTIVE)
	_rot.resize(MAX_ACTIVE)
	_vel.resize(MAX_ACTIVE)
	_ang_vel.resize(MAX_ACTIVE)
	_base_scale.resize(MAX_ACTIVE)
	_scale.resize(MAX_ACTIVE)
	_age.resize(MAX_ACTIVE)
	_floor_timer.resize(MAX_ACTIVE)
	_floor_lifetime.resize(MAX_ACTIVE)
	_bounces.resize(MAX_ACTIVE)
	_on_floor.resize(MAX_ACTIVE)


func _ready() -> void:
	set_physics_process(false)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _physics_process(delta: float) -> void:
	if _active_count <= 0:
		set_physics_process(false)
		return
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var i: int = _active_count - 1
	while i >= 0:
		if _step_piece(i, delta, space_state):
			var xform := Transform3D(Basis.from_euler(_rot[i]).scaled(_scale[i]), _pos[i])
			multimesh.set_instance_transform(i, xform)
		else:
			_swap_remove(i)
		i -= 1
	multimesh.visible_instance_count = _active_count
	if _active_count <= 0:
		set_physics_process(false)


func _spawn(origin: Vector3, count: int, floor_lifetime: float) -> void:
	var free_slots: int = MAX_ACTIVE - _active_count
	var spawn_count: int = mini(count, free_slots)
	if spawn_count <= 0:
		return
	var safe_lifetime: float = maxf(floor_lifetime, 0.2)
	for _k in spawn_count:
		var idx: int = _active_count
		_active_count += 1
		var angle: float = randf_range(0.0, TAU)
		var horiz_speed: float = randf_range(SPEED_MIN, SPEED_MAX)
		var size_vec: Vector3 = BONE_SIZES[randi() % BONE_SIZES.size()]
		var scale_vec: Vector3 = size_vec * randf_range(0.85, 1.2)
		var offset := Vector3(
			randf_range(-0.20, 0.20),
			randf_range(-0.35, 0.45),
			randf_range(-0.20, 0.20),
		)
		_pos[idx] = origin + offset
		_rot[idx] = Vector3(randf_range(0.0, TAU), randf_range(0.0, TAU), randf_range(0.0, TAU))
		_vel[idx] = Vector3(
			cos(angle) * horiz_speed,
			randf_range(UP_SPEED_MIN, UP_SPEED_MAX),
			sin(angle) * horiz_speed,
		)
		_ang_vel[idx] = Vector3(
			randf_range(-SPIN_MAX, SPIN_MAX),
			randf_range(-SPIN_MAX, SPIN_MAX),
			randf_range(-SPIN_MAX, SPIN_MAX),
		)
		_base_scale[idx] = scale_vec
		_scale[idx] = scale_vec
		_age[idx] = 0.0
		_floor_timer[idx] = 0.0
		_floor_lifetime[idx] = safe_lifetime
		_bounces[idx] = 0
		_on_floor[idx] = 0

		var xform := Transform3D(Basis.from_euler(_rot[idx]).scaled(_scale[idx]), _pos[idx])
		multimesh.set_instance_transform(idx, xform)

	multimesh.visible_instance_count = _active_count
	set_physics_process(true)


func _step_piece(i: int, delta: float, space_state: PhysicsDirectSpaceState3D) -> bool:
	if _on_floor[i] != 0:
		_floor_timer[i] += delta
		var life: float = _floor_lifetime[i]
		if _floor_timer[i] >= life:
			var shrink_t: float = clampf((_floor_timer[i] - life) / SHRINK_DURATION, 0.0, 1.0)
			_scale[i] = _base_scale[i] * (1.0 - shrink_t)
			if shrink_t >= 1.0:
				return false
		return true

	_age[i] += delta
	if _age[i] >= MAX_AIR_TIME:
		return false

	var v: Vector3 = _vel[i]
	v.y -= _gravity * delta
	var prev_pos: Vector3 = _pos[i]
	var next_pos: Vector3 = prev_pos + v * delta
	var r: Vector3 = _rot[i] + _ang_vel[i] * delta

	if prev_pos.distance_squared_to(next_pos) > 0.000001:
		_ray_query.from = prev_pos
		_ray_query.to = next_pos
		var hit: Dictionary = space_state.intersect_ray(_ray_query)
		if not hit.is_empty():
			var hit_pos: Vector3 = hit["position"] as Vector3
			_pos[i] = hit_pos + Vector3.UP * PIECE_HALF_HEIGHT
			if _bounces[i] == 0 and v.length() > 2.0:
				_bounces[i] = 1
				_vel[i] = Vector3(v.x * 0.45, absf(v.y) * 0.28, v.z * 0.45)
				_ang_vel[i] = _ang_vel[i] * 0.4
			else:
				_vel[i] = Vector3.ZERO
				_on_floor[i] = 1
				_floor_timer[i] = 0.0
				r.x = 0.0
				r.z = 0.0
			_rot[i] = r
			return true

	_vel[i] = v
	_pos[i] = next_pos
	_rot[i] = r
	return true


func _swap_remove(i: int) -> void:
	var last: int = _active_count - 1
	if i != last:
		_pos[i] = _pos[last]
		_rot[i] = _rot[last]
		_vel[i] = _vel[last]
		_ang_vel[i] = _ang_vel[last]
		_base_scale[i] = _base_scale[last]
		_scale[i] = _scale[last]
		_age[i] = _age[last]
		_floor_timer[i] = _floor_timer[last]
		_floor_lifetime[i] = _floor_lifetime[last]
		_bounces[i] = _bounces[last]
		_on_floor[i] = _on_floor[last]
		var xform := Transform3D(Basis.from_euler(_rot[i]).scaled(_scale[i]), _pos[i])
		multimesh.set_instance_transform(i, xform)
	_active_count = last
