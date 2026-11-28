class_name EnemyGib
extends Node3D
## Explosión de sangre estilo ULTRAKILL al morir un enemigo:
## nube/vapor líquido de sangre + estelas parabólicas gruesas de sangre
## + salpicaduras pixel art (billboard, siempre de cara a la cámara) que salen por todas partes.
## Estilo BONES (esqueletos): sin sangre; astillas de hueso y polvo pixel art.

enum Style { BLOOD, BONES }
## Reutiliza nodos (pool), mallas y materiales compartidos.

const MAX_ACTIVE_BURSTS: int = 12
const SPHERE_DURATION: float = 0.16
const SPHERE_ALPHA: float = 0.12
const TRAIL_LIFETIME: float = 0.32
const PARTICLE_LIFETIME: float = 0.75
const PARTICLE_MAX: int = 24
const MIST_LIFETIME: float = 0.38
const MIST_AMOUNT: int = 6
## Atlas pixel art 4x2 de salpicaduras (generado con diseños/blood_sprites.py).
const BLOOD_ATLAS: Texture2D = preload("res://assets/textures/blood/blood_splats.png")
## Atlas pixel art 4x2 de huesos y polvo (generado con diseños/bone_sprites.py).
const BONE_ATLAS: Texture2D = preload("res://assets/textures/blood/bone_shards.png")
const SPRITE_LIFETIME: float = 1.1
const SPRITE_MIN: int = 36
const SPRITE_MAX: int = 64
const SPLASH_LIFETIME: float = 0.42
const SPLASH_AMOUNT: int = 6

static var _pool: Array = []
static var _active_count: int = 0
static var _sphere_mesh: SphereMesh
static var _sphere_material: StandardMaterial3D
static var _drop_mesh: BoxMesh
static var _drop_material: StandardMaterial3D
static var _process_material: ParticleProcessMaterial
static var _mist_mesh: QuadMesh
static var _mist_material: StandardMaterial3D
static var _mist_process_material: ParticleProcessMaterial
## Un material/malla de sprite por estilo (índice = Style).
static var _sprite_meshes: Array[QuadMesh] = []
static var _splash_meshes: Array[QuadMesh] = []
static var _sprite_process_material: ParticleProcessMaterial
static var _splash_process_material: ParticleProcessMaterial

var _sphere: MeshInstance3D
var _particles: GPUParticles3D
var _mist: GPUParticles3D
var _sprites: GPUParticles3D
var _splash: GPUParticles3D
var _age: float = 0.0
var _is_active: bool = false


## Lanza una explosión de sangre desde `origin`: nube líquida + arcos parabólicos.
static func spawn_burst(
	tree: SceneTree,
	origin: Vector3,
	count: int,
	colors: Array[Color] = [],
	style: Style = Style.BLOOD
) -> void:
	if tree == null or tree.current_scene == null or count <= 0:
		return
	if _active_count >= MAX_ACTIVE_BURSTS:
		return
	_ensure_shared_resources()
	var main_color: Color = colors[0] if not colors.is_empty() else Color(0.92, 0.05, 0.05)
	_sphere_material.albedo_color = Color(main_color.r, main_color.g, main_color.b, SPHERE_ALPHA)
	_drop_material.albedo_color = main_color
	_mist_material.albedo_color = Color(main_color.r, main_color.g, main_color.b, 0.6)

	var burst: EnemyGib = _take_or_create(tree)
	burst._activate(origin, count, style)


## Compila los shaders de la explosión al cargar (un burst diminuto frente a la cámara 2 frames),
## para que la primera muerte no dé un tirón.
static func prewarm(tree: SceneTree) -> void:
	if tree == null or tree.current_scene == null:
		return
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	if camera == null:
		return
	_ensure_shared_resources()
	var burst: EnemyGib = _take_or_create(tree)
	var bones_burst: EnemyGib = _take_or_create(tree)
	var spot: Vector3 = camera.global_position - camera.global_basis.z * 2.0
	burst._activate(spot, 8, Style.BLOOD)
	bones_burst._activate(spot, 8, Style.BONES)
	burst.scale = Vector3.ONE * 0.001
	bones_burst.scale = Vector3.ONE * 0.001
	await tree.process_frame
	await tree.process_frame
	for prewarmed: EnemyGib in [burst, bones_burst]:
		if is_instance_valid(prewarmed):
			prewarmed.scale = Vector3.ONE
			prewarmed._release()


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
	if _drop_material == null:
		_drop_material = StandardMaterial3D.new()
		_drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_drop_material.vertex_color_use_as_albedo = true
		_drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_drop_material.albedo_color = Color(0.92, 0.05, 0.05)
	if _drop_mesh == null:
		_drop_mesh = BoxMesh.new()
		_drop_mesh.size = Vector3(0.08, 0.28, 0.08)
		_drop_mesh.material = _drop_material
	if _process_material == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 0.10, 0.10, 1.0))
		grad.set_color(1, Color(0.45, 0.0, 0.0, 0.0))
		var grad_tex := GradientTexture1D.new()
		grad_tex.gradient = grad

		_process_material = ParticleProcessMaterial.new()
		_process_material.direction = Vector3(0.0, 1.0, 0.0)
		_process_material.spread = 160.0
		_process_material.initial_velocity_min = 6.0
		_process_material.initial_velocity_max = 16.0
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
	if _sprite_meshes.is_empty():
		for atlas: Texture2D in [BLOOD_ATLAS, BONE_ATLAS]:
			var sprite_material: StandardMaterial3D = _make_sprite_material(atlas)
			var sprite_mesh := QuadMesh.new()
			sprite_mesh.size = Vector2(0.8, 0.8)
			sprite_mesh.material = sprite_material
			_sprite_meshes.append(sprite_mesh)
			var splash_mesh := QuadMesh.new()
			splash_mesh.size = Vector2(2.6, 2.6)
			splash_mesh.material = sprite_material
			_splash_meshes.append(splash_mesh)
	if _sprite_process_material == null:
		# Se encogen al final en vez de volverse transparentes (alpha scissor = píxel nítido).
		var sprite_scale := Curve.new()
		sprite_scale.add_point(Vector2(0.0, 0.6))
		sprite_scale.add_point(Vector2(0.15, 1.25))
		sprite_scale.add_point(Vector2(0.75, 1.0))
		sprite_scale.add_point(Vector2(1.0, 0.0))
		var sprite_scale_tex := CurveTexture.new()
		sprite_scale_tex.curve = sprite_scale
		_sprite_process_material = ParticleProcessMaterial.new()
		_sprite_process_material.direction = Vector3(0.0, 1.0, 0.0)
		_sprite_process_material.spread = 180.0
		_sprite_process_material.initial_velocity_min = 4.0
		_sprite_process_material.initial_velocity_max = 19.0
		_sprite_process_material.gravity = Vector3(0.0, -16.0, 0.0)
		_sprite_process_material.damping_min = 0.8
		_sprite_process_material.damping_max = 2.2
		_sprite_process_material.scale_min = 0.55
		_sprite_process_material.scale_max = 2.4
		_sprite_process_material.scale_curve = sprite_scale_tex
		_sprite_process_material.angle_min = -180.0
		_sprite_process_material.angle_max = 180.0
		_sprite_process_material.emission_shape = (ParticleProcessMaterial.EMISSION_SHAPE_SPHERE)
		_sprite_process_material.emission_sphere_radius = 0.45
		# Frame al azar del atlas (sin animar).
		_sprite_process_material.anim_offset_min = 0.0
		_sprite_process_material.anim_offset_max = 1.0
		_sprite_process_material.anim_speed_min = 0.0
		_sprite_process_material.anim_speed_max = 0.0
	if _splash_process_material == null:
		var splash_scale := Curve.new()
		splash_scale.add_point(Vector2(0.0, 0.3))
		splash_scale.add_point(Vector2(0.3, 1.5))
		splash_scale.add_point(Vector2(1.0, 0.0))
		var splash_scale_tex := CurveTexture.new()
		splash_scale_tex.curve = splash_scale
		_splash_process_material = ParticleProcessMaterial.new()
		_splash_process_material.direction = Vector3(0.0, 1.0, 0.0)
		_splash_process_material.spread = 180.0
		_splash_process_material.initial_velocity_min = 0.6
		_splash_process_material.initial_velocity_max = 2.2
		_splash_process_material.gravity = Vector3(0.0, -2.0, 0.0)
		_splash_process_material.scale_min = 0.8
		_splash_process_material.scale_max = 1.4
		_splash_process_material.scale_curve = splash_scale_tex
		_splash_process_material.angle_min = -180.0
		_splash_process_material.angle_max = 180.0
		_splash_process_material.anim_offset_min = 0.0
		_splash_process_material.anim_offset_max = 1.0


static func _make_sprite_material(atlas: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.particles_anim_h_frames = 4
	material.particles_anim_v_frames = 2
	material.particles_anim_loop = false
	material.albedo_texture = atlas
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


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
	_particles.amount = PARTICLE_MAX
	_particles.lifetime = PARTICLE_LIFETIME
	_particles.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Y_TO_VELOCITY
	_particles.fixed_fps = 30
	_particles.process_material = _process_material
	_particles.draw_pass_1 = _drop_mesh
	add_child(_particles)

	_mist = GPUParticles3D.new()
	_mist.emitting = false
	_mist.one_shot = true
	_mist.explosiveness = 1.0
	_mist.amount = MIST_AMOUNT
	_mist.lifetime = MIST_LIFETIME
	_mist.fixed_fps = 30
	_mist.process_material = _mist_process_material
	_mist.draw_pass_1 = _mist_mesh
	add_child(_mist)

	_sprites = GPUParticles3D.new()
	_sprites.emitting = false
	_sprites.one_shot = true
	_sprites.explosiveness = 0.95
	_sprites.amount = SPRITE_MAX
	_sprites.lifetime = SPRITE_LIFETIME
	_sprites.fixed_fps = 30
	_sprites.process_material = _sprite_process_material
	_sprites.draw_pass_1 = _sprite_meshes[Style.BLOOD]
	_sprites.visibility_aabb = AABB(Vector3(-8.0, -6.0, -8.0), Vector3(16.0, 14.0, 16.0))
	add_child(_sprites)

	_splash = GPUParticles3D.new()
	_splash.emitting = false
	_splash.one_shot = true
	_splash.explosiveness = 1.0
	_splash.amount = SPLASH_AMOUNT
	_splash.lifetime = SPLASH_LIFETIME
	_splash.fixed_fps = 30
	_splash.process_material = _splash_process_material
	_splash.draw_pass_1 = _splash_meshes[Style.BLOOD]
	add_child(_splash)


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
			_sphere.scale = Vector3.ONE * lerpf(0.35, 2.6, ease_t)
		else:
			var shrink_t: float = (progress - 0.65) / 0.35
			_sphere.scale = Vector3.ONE * lerpf(2.6, 0.0, shrink_t)
		_sphere.visible = true
	else:
		_sphere.visible = false

	if _age >= maxf(PARTICLE_LIFETIME, SPRITE_LIFETIME):
		_release()


func _activate(pos: Vector3, count: int, style: Style = Style.BLOOD) -> void:
	global_position = pos
	_sphere.mesh = _sphere_mesh
	_sphere.material_override = _sphere_material
	_sphere.scale = Vector3.ONE * 0.35
	_sphere.visible = true

	_particles.process_material = _process_material
	_particles.draw_pass_1 = _drop_mesh
	_particles.amount_ratio = clampf(float(maxi(count, 1)) / float(PARTICLE_MAX), 0.15, 1.0)
	# Estelas y niebla son de sangre (rampa roja): los esqueletos no las usan.
	var bloody: bool = style == Style.BLOOD
	_particles.visible = bloody
	_mist.visible = bloody
	if bloody:
		_particles.restart()
		_particles.emitting = true

	_mist.process_material = _mist_process_material
	_mist.draw_pass_1 = _mist_mesh
	if bloody:
		_mist.restart()
		_mist.emitting = true

	_sprites.process_material = _sprite_process_material
	_sprites.draw_pass_1 = _sprite_meshes[style]
	var target_sprites: int = clampi(count * 3, SPRITE_MIN, SPRITE_MAX)
	_sprites.amount_ratio = clampf(float(target_sprites) / float(SPRITE_MAX), 0.2, 1.0)
	_sprites.restart()
	_sprites.emitting = true

	_splash.process_material = _splash_process_material
	_splash.draw_pass_1 = _splash_meshes[style]
	_splash.restart()
	_splash.emitting = true

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
	_sprites.emitting = false
	_splash.emitting = false
	visible = false
	set_process(false)
	if not _pool.has(self):
		_pool.append(self)
