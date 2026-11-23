class_name EnemyGib
extends Node3D
## Explosión de sangre estilo ULTRAKILL al morir un enemigo:
## nube/vapor líquido de sangre + estelas parabólicas gruesas de sangre.
## Reutiliza nodos (pool), mallas y materiales compartidos.

const MAX_ACTIVE_BURSTS: int = 24
const SPHERE_DURATION: float = 0.16
const SPHERE_ALPHA: float = 0.12
const TRAIL_LIFETIME: float = 0.32
const PARTICLE_LIFETIME: float = 0.75
const MIST_LIFETIME: float = 0.38
const MIST_AMOUNT: int = 10

static var _pool: Array[EnemyGib] = []
static var _active_count: int = 0
static var _sphere_mesh: SphereMesh
static var _sphere_material: StandardMaterial3D
static var _trail_mesh: RibbonTrailMesh
static var _trail_material: StandardMaterial3D
static var _process_material: ParticleProcessMaterial
static var _mist_mesh: QuadMesh
static var _mist_material: StandardMaterial3D
static var _mist_process_material: ParticleProcessMaterial

var _sphere: MeshInstance3D
var _particles: GPUParticles3D
var _mist: GPUParticles3D
var _age: float = 0.0
var _is_active: bool = false


## Lanza una explosión de sangre desde `origin`: nube líquida + arcos parabólicos.
static func spawn_burst(
	tree: SceneTree, origin: Vector3, count: int, colors: Array[Color] = []
) -> void:
	if tree == null or tree.current_scene == null or count <= 0:
		return
	if _active_count >= MAX_ACTIVE_BURSTS:
		return
	_ensure_shared_resources()
	var main_color: Color = colors[0] if not colors.is_empty() else Color(0.92, 0.05, 0.05)
	_sphere_material.albedo_color = Color(main_color.r, main_color.g, main_color.b, SPHERE_ALPHA)
	_trail_material.albedo_color = main_color
	_mist_material.albedo_color = Color(main_color.r, main_color.g, main_color.b, 0.6)

	var burst: EnemyGib = _take_or_create(tree)
	burst._activate(origin, count)


static func _ensure_shared_resources() -> void:
	if _sphere_mesh == null:
		_sphere_mesh = SphereMesh.new()
		_sphere_mesh.radius = 0.5
		_sphere_mesh.height = 1.0
		_sphere_mesh.radial_segments = 10
		_sphere_mesh.rings = 5
	if _sphere_material == null:
		_sphere_material = StandardMaterial3D.new()
		_sphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_sphere_material.albedo_color = Color(0.92, 0.05, 0.05, SPHERE_ALPHA)
	if _trail_material == null:
		_trail_material = StandardMaterial3D.new()
		_trail_material.use_particle_trails = true
		_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_trail_material.vertex_color_use_as_albedo = true
		_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_trail_material.albedo_color = Color(0.92, 0.05, 0.05)
	if _trail_mesh == null:
		var taper := Curve.new()
		taper.add_point(Vector2(0.0, 0.75))
		taper.add_point(Vector2(0.15, 1.0))
		taper.add_point(Vector2(1.0, 0.0))
		_trail_mesh = RibbonTrailMesh.new()
		_trail_mesh.shape = RibbonTrailMesh.SHAPE_CROSS
		_trail_mesh.size = 0.24
		_trail_mesh.sections = 8
		_trail_mesh.section_length = 0.10
		_trail_mesh.section_segments = 3
		_trail_mesh.curve = taper
		_trail_mesh.material = _trail_material
	if _process_material == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.10, 0.10, 1.0))
		grad.set_color(1, Color(0.45, 0.0, 0.0, 0.0))
		var grad_tex := GradientTexture1D.new()
		grad_tex.gradient = grad

		_process_material = ParticleProcessMaterial.new()
		_process_material.direction = Vector3(0.0, 1.0, 0.0)
		_process_material.spread = 125.0
		_process_material.initial_velocity_min = 5.5
		_process_material.initial_velocity_max = 12.0
		_process_material.gravity = Vector3(0.0, -18.0, 0.0)
		_process_material.damping_min = 1.2
		_process_material.damping_max = 2.5
		_process_material.scale_min = 0.85
		_process_material.scale_max = 1.45
		_process_material.color_ramp = grad_tex
	if _mist_material == null:
		_mist_material = StandardMaterial3D.new()
		_mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mist_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mist_material.vertex_color_use_as_albedo = true
		_mist_material.albedo_color = Color(0.92, 0.05, 0.05, 0.6)
	if _mist_mesh == null:
		_mist_mesh = QuadMesh.new()
		_mist_mesh.size = Vector2(0.85, 0.85)
		_mist_mesh.material = _mist_material
	if _mist_process_material == null:
		var mist_grad := Gradient.new()
		mist_grad.set_color(0, Color(0.95, 0.04, 0.04, 0.65))
		mist_grad.set_color(1, Color(0.40, 0.0, 0.0, 0.0))
		var mist_grad_tex := GradientTexture1D.new()
		mist_grad_tex.gradient = mist_grad

		var mist_scale := Curve.new()
		mist_scale.add_point(Vector2(0.0, 0.5))
		mist_scale.add_point(Vector2(0.35, 1.4))
		mist_scale.add_point(Vector2(1.0, 2.1))
		var mist_scale_tex := CurveTexture.new()
		mist_scale_tex.curve = mist_scale

		_mist_process_material = ParticleProcessMaterial.new()
		_mist_process_material.direction = Vector3(0.0, 1.0, 0.0)
		_mist_process_material.spread = 180.0
		_mist_process_material.initial_velocity_min = 1.2
		_mist_process_material.initial_velocity_max = 3.8
		_mist_process_material.gravity = Vector3(0.0, -3.5, 0.0)
		_mist_process_material.damping_min = 2.0
		_mist_process_material.damping_max = 4.0
		_mist_process_material.scale_min = 0.7
		_mist_process_material.scale_max = 1.3
		_mist_process_material.scale_curve = mist_scale_tex
		_mist_process_material.color_ramp = mist_grad_tex


static func _take_or_create(tree: SceneTree) -> EnemyGib:
	while not _pool.is_empty():
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			var burst := raw as EnemyGib
			if burst != null and burst.is_inside_tree():
				return burst
	var created := EnemyGib.new()
	created.top_level = true
	tree.current_scene.add_child(created)
	return created


func _init() -> void:
	_sphere = MeshInstance3D.new()
	_sphere.mesh = _sphere_mesh
	_sphere.material_override = _sphere_material
	add_child(_sphere)

	_particles = GPUParticles3D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.lifetime = PARTICLE_LIFETIME
	_particles.trail_enabled = true
	_particles.trail_lifetime = TRAIL_LIFETIME
	_particles.fixed_fps = 60
	_particles.process_material = _process_material
	_particles.draw_pass_1 = _trail_mesh
	add_child(_particles)

	_mist = GPUParticles3D.new()
	_mist.emitting = false
	_mist.one_shot = true
	_mist.explosiveness = 1.0
	_mist.amount = MIST_AMOUNT
	_mist.lifetime = MIST_LIFETIME
	_mist.fixed_fps = 60
	_mist.process_material = _mist_process_material
	_mist.draw_pass_1 = _mist_mesh
	add_child(_mist)


func _ready() -> void:
	if not _is_active:
		set_process(false)


func _exit_tree() -> void:
	if _is_active:
		_is_active = false
		_active_count = maxi(_active_count - 1, 0)


func _process(delta: float) -> void:
	if not _is_active:
		return
	_age += delta
	if _age < SPHERE_DURATION:
		var progress: float = clampf(_age / SPHERE_DURATION, 0.0, 1.0)
		if progress < 0.65:
			var expand_t: float = progress / 0.65
			var ease_t: float = 1.0 - (1.0 - expand_t) * (1.0 - expand_t)
			_sphere.scale = Vector3.ONE * lerpf(0.35, 1.85, ease_t)
		else:
			var shrink_t: float = (progress - 0.65) / 0.35
			_sphere.scale = Vector3.ONE * lerpf(1.85, 0.0, shrink_t)
		_sphere.visible = true
	else:
		_sphere.visible = false

	if _age >= PARTICLE_LIFETIME + TRAIL_LIFETIME:
		_release()


func _activate(pos: Vector3, count: int) -> void:
	global_position = pos
	_sphere.mesh = _sphere_mesh
	_sphere.material_override = _sphere_material
	_sphere.scale = Vector3.ONE * 0.35
	_sphere.visible = true

	_particles.process_material = _process_material
	_particles.draw_pass_1 = _trail_mesh
	_particles.amount = maxi(count, 1)
	_particles.restart()
	_particles.emitting = true

	_mist.process_material = _mist_process_material
	_mist.draw_pass_1 = _mist_mesh
	_mist.restart()
	_mist.emitting = true

	_age = 0.0
	if not _is_active:
		_is_active = true
		_active_count += 1
	visible = true
	set_process(true)


func _release() -> void:
	if _is_active:
		_is_active = false
		_active_count = maxi(_active_count - 1, 0)
	_particles.emitting = false
	_mist.emitting = false
	visible = false
	set_process(false)
	if not _pool.has(self):
		_pool.append(self)
