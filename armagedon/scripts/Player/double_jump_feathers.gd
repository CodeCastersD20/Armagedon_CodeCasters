class_name DoubleJumpFeathers
extends MultiMeshInstance3D
## Ráfaga de plumas blancas con borde dorado brillante al hacer doble salto.

const FEATHER_SCENE: PackedScene = preload("res://assets/models/props/feather/feather.glb")
const FEATHER_SHADER: Shader = preload("res://assets/shaders/feather_glow.gdshader")

const POOL_SIZE: int = 36
const FEATHERS_PER_JUMP: int = 10
const MIN_RADIUS: float = 0.55
const MAX_RADIUS: float = 1.15
const MIN_HEIGHT_OFFSET: float = 0.25
const MAX_HEIGHT_OFFSET: float = 1.35
const MIN_SCALE: float = 0.26
const MAX_SCALE: float = 0.40
const MIN_LIFETIME: float = 1.05
const MAX_LIFETIME: float = 1.55
const FADE_OUT_FRACTION: float = 0.35

var _active: PackedByteArray = PackedByteArray()
var _positions: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _rotations: PackedVector3Array = PackedVector3Array()
var _spin_speeds: PackedVector3Array = PackedVector3Array()
var _scales: PackedFloat32Array = PackedFloat32Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _lifetimes: PackedFloat32Array = PackedFloat32Array()
var _phases: PackedFloat32Array = PackedFloat32Array()
var _cursor: int = 0
var _active_count: int = 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var merged_mesh: ArrayMesh = _build_merged_feather_mesh()
	if merged_mesh == null:
		push_error("DoubleJumpFeathers: no se pudo construir la malla de la pluma.")
		set_process(false)
		return

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.instance_count = POOL_SIZE
	mm.mesh = merged_mesh
	multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = FEATHER_SHADER
	material_override = mat

	_active.resize(POOL_SIZE)
	_positions.resize(POOL_SIZE)
	_velocities.resize(POOL_SIZE)
	_rotations.resize(POOL_SIZE)
	_spin_speeds.resize(POOL_SIZE)
	_scales.resize(POOL_SIZE)
	_ages.resize(POOL_SIZE)
	_lifetimes.resize(POOL_SIZE)
	_phases.resize(POOL_SIZE)

	for i: int in POOL_SIZE:
		_hide_instance(i)

	var player := get_parent() as Player
	if player != null:
		player.double_jumped.connect(_on_player_double_jumped)

	set_process(false)


func _process(delta: float) -> void:
	if multimesh == null:
		set_process(false)
		return

	var any_active: bool = false
	for i: int in POOL_SIZE:
		if _active[i] == 0:
			continue
		var age: float = _ages[i] + delta
		var lifetime: float = _lifetimes[i]
		if age >= lifetime:
			_hide_instance(i)
			_active_count = maxi(_active_count - 1, 0)
			continue

		any_active = true
		_ages[i] = age

		var vel: Vector3 = _velocities[i]
		# Caída suave con frenado de aire y vaivén horizontal como pluma.
		vel.x = lerpf(vel.x, 0.0, 2.2 * delta)
		vel.z = lerpf(vel.z, 0.0, 2.2 * delta)
		vel.y = lerpf(vel.y, -0.85, 2.8 * delta)
		_velocities[i] = vel

		var sway_angle: float = age * 4.5 + _phases[i]
		var sway := Vector3(cos(sway_angle), 0.0, sin(sway_angle)) * (0.45 * delta)
		var pos: Vector3 = _positions[i] + vel * delta + sway
		_positions[i] = pos

		var rot: Vector3 = _rotations[i] + _spin_speeds[i] * delta
		_rotations[i] = rot

		var life_t: float = age / maxf(lifetime, 0.01)
		var fade_start: float = 1.0 - FADE_OUT_FRACTION
		var alpha: float = 1.0
		if life_t > fade_start:
			alpha = 1.0 - (life_t - fade_start) / maxf(FADE_OUT_FRACTION, 0.01)
		alpha = clampf(alpha, 0.0, 1.0)

		var scale_factor: float = _scales[i] * (0.75 + 0.25 * alpha)
		var feather_basis := Basis.from_euler(rot) * scale_factor
		multimesh.set_instance_transform(i, Transform3D(feather_basis, pos))
		multimesh.set_instance_custom_data(i, Color(alpha, 0.0, 0.0, 1.0))

	if not any_active:
		set_process(false)


func _on_player_double_jumped(origin: Vector3) -> void:
	if multimesh == null:
		return

	var base_angle: float = randf() * TAU
	for n: int in FEATHERS_PER_JUMP:
		var idx: int = _cursor
		_cursor = (_cursor + 1) % POOL_SIZE
		if _active[idx] == 0:
			_active_count += 1
		_active[idx] = 1

		var angle: float = base_angle + (float(n) / float(FEATHERS_PER_JUMP)) * TAU
		angle += randf_range(-0.22, 0.22)
		var radius: float = randf_range(MIN_RADIUS, MAX_RADIUS)
		var height_off: float = randf_range(MIN_HEIGHT_OFFSET, MAX_HEIGHT_OFFSET)
		var radial := Vector3(cos(angle), 0.0, sin(angle))

		var pos: Vector3 = origin + radial * radius + Vector3(0.0, height_off, 0.0)
		var vel: Vector3 = radial * randf_range(1.6, 3.1) + Vector3(0.0, randf_range(1.4, 2.8), 0.0)

		_positions[idx] = pos
		_velocities[idx] = vel
		_rotations[idx] = Vector3(
			randf_range(-0.9, 0.9), randf_range(0.0, TAU), randf_range(-0.9, 0.9)
		)
		_spin_speeds[idx] = Vector3(
			randf_range(-2.2, 2.2), randf_range(-3.5, 3.5), randf_range(-2.2, 2.2)
		)
		_scales[idx] = randf_range(MIN_SCALE, MAX_SCALE)
		_ages[idx] = 0.0
		_lifetimes[idx] = randf_range(MIN_LIFETIME, MAX_LIFETIME)
		_phases[idx] = randf() * TAU

		var feather_basis := Basis.from_euler(_rotations[idx]) * _scales[idx]
		multimesh.set_instance_transform(idx, Transform3D(feather_basis, pos))
		multimesh.set_instance_custom_data(idx, Color(1.0, 0.0, 0.0, 1.0))

	set_process(true)


func _hide_instance(idx: int) -> void:
	_active[idx] = 0
	if multimesh != null:
		multimesh.set_instance_transform(idx, Transform3D(Basis.IDENTITY * 0.0001, Vector3.ZERO))
		multimesh.set_instance_custom_data(idx, Color(0.0, 0.0, 0.0, 1.0))


func _build_merged_feather_mesh() -> ArrayMesh:
	var scene_root := FEATHER_SCENE.instantiate()
	if scene_root == null:
		return null

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_geometry: bool = false

	var mesh_nodes: Array[Node] = scene_root.find_children("*", "MeshInstance3D", true, false)
	for node: Node in mesh_nodes:
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var xform: Transform3D = _relative_transform(scene_root, mi)
		for surf_idx: int in mi.mesh.get_surface_count():
			st.append_from(mi.mesh, surf_idx, xform)
			has_geometry = true

	scene_root.queue_free()
	if not has_geometry:
		return null
	st.generate_normals()
	return st.commit()


func _relative_transform(root: Node, target: Node3D) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var current: Node = target
	while current != null and current != root:
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
