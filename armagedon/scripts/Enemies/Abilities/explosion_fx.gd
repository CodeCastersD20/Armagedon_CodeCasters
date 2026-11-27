class_name ExplosionFx
extends Node3D
## Explosión visual con pooling: destello esférico que se expande, chispas (GPUParticles3D de un
## disparo) y luz breve. Mallas y materiales compartidos.

const POOL_SIZE_HINT: int = 4
const FLASH_SECONDS: float = 0.35
const PARTICLE_LIFETIME: float = 0.8
const LIGHT_ENERGY: float = 6.0

static var _pool: Array = []
static var _flash_mesh: SphereMesh
static var _flash_material: StandardMaterial3D
static var _spark_mesh: QuadMesh
static var _spark_material: StandardMaterial3D
static var _spark_process: ParticleProcessMaterial

var _flash: MeshInstance3D
var _sparks: GPUParticles3D
var _light: OmniLight3D
var _time_left: float = 0.0
var _radius: float = 1.0


static func spawn(tree: SceneTree, pos: Vector3, radius: float) -> void:
	if tree == null or tree.current_scene == null:
		return
	var fx: ExplosionFx = null
	while not _pool.is_empty():
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			fx = raw as ExplosionFx
			break
	if fx == null:
		fx = ExplosionFx.new()
		fx._build()
	if fx.get_parent() == null:
		tree.current_scene.add_child(fx)
	fx._play(pos, radius)


func _build() -> void:
	_ensure_shared()
	_flash = MeshInstance3D.new()
	_flash.mesh = _flash_mesh
	_flash.material_override = _flash_material
	add_child(_flash)
	_sparks = GPUParticles3D.new()
	_sparks.amount = 28
	_sparks.lifetime = PARTICLE_LIFETIME
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.local_coords = false
	_sparks.process_material = _spark_process
	_sparks.draw_pass_1 = _spark_mesh
	_sparks.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 14, 24))
	_sparks.emitting = false
	add_child(_sparks)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.2)
	_light.omni_range = 9.0
	_light.shadow_enabled = false
	add_child(_light)
	visible = false
	set_process(false)


static func _ensure_shared() -> void:
	if _flash_mesh != null:
		return
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 1.0
	_flash_mesh.height = 2.0
	_flash_mesh.radial_segments = 8
	_flash_mesh.rings = 4
	_flash_material = StandardMaterial3D.new()
	_flash_material.albedo_color = Color(1.0, 0.7, 0.25)
	_flash_material.emission_enabled = true
	_flash_material.emission = Color(1.0, 0.55, 0.15)
	_flash_material.emission_energy_multiplier = 2.0
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.35, 0.35)
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.vertex_color_use_as_albedo = true
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mesh.material = _spark_material
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(
		[Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.4, 0.1, 0.8), Color(0.3, 0.05, 0.0, 0.0)]
	)
	gradient.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	_spark_process = ParticleProcessMaterial.new()
	_spark_process.direction = Vector3.UP
	_spark_process.spread = 180.0
	_spark_process.initial_velocity_min = 4.0
	_spark_process.initial_velocity_max = 10.0
	_spark_process.gravity = Vector3(0.0, -6.0, 0.0)
	_spark_process.scale_min = 0.6
	_spark_process.scale_max = 1.6
	_spark_process.color_ramp = ramp


func _play(pos: Vector3, radius: float) -> void:
	global_position = pos + Vector3.UP * 0.8
	_radius = maxf(radius, 0.5)
	_time_left = FLASH_SECONDS
	_flash.scale = Vector3.ONE * 0.3
	_flash.transparency = 0.0
	_light.light_energy = LIGHT_ENERGY
	visible = true
	_sparks.restart()
	_sparks.emitting = true
	set_process(true)


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		_flash.visible = false
		_light.light_energy = 0.0
		if _time_left <= -PARTICLE_LIFETIME + FLASH_SECONDS:
			set_process(false)
			visible = false
			_flash.visible = true
			_pool.append(self)
		return
	var t: float = 1.0 - _time_left / FLASH_SECONDS
	_flash.scale = Vector3.ONE * lerpf(0.3, _radius * 0.6, sqrt(t))
	_flash.transparency = t
	_light.light_energy = LIGHT_ENERGY * (1.0 - t)
