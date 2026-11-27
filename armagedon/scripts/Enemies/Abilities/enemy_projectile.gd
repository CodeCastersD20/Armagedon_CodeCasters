class_name EnemyProjectile
extends Node3D
## Proyectil de enemigo con pooling. Recto (gravity 0) o parabólico; puede dejar un CreepZone.

const MAX_LIFETIME: float = 6.0
const WORLD_MASK: int = 2
const HIT_RADIUS: float = 0.7
const GROUND_SEARCH_DISTANCE: float = 30.0

static var _pool: Array = []
static var _mesh: SphereMesh
static var _materials: Dictionary = {}
static var _ray: PhysicsRayQueryParameters3D

var _velocity: Vector3 = Vector3.ZERO
var _gravity: float = 0.0
var _damage: float = 0.0
var _splash_radius: float = 0.0
var _creep: bool = false
var _creep_duration: float = 0.0
var _creep_tick: float = 0.5
var _life: float = 0.0
var _player: Node3D
var _visual: MeshInstance3D


static func launch(
	tree: SceneTree,
	from: Vector3,
	velocity: Vector3,
	cfg: AbilityData,
	damage: float,
	player: Node3D,
) -> void:
	if tree == null or tree.current_scene == null:
		return
	var projectile: EnemyProjectile = _take_from_pool()
	if projectile == null:
		projectile = EnemyProjectile.new()
		projectile._build()
	if projectile.get_parent() == null:
		tree.current_scene.add_child(projectile)
	projectile._activate(from, velocity, cfg, damage, player)


static func _take_from_pool() -> EnemyProjectile:
	while not _pool.is_empty():
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			return raw as EnemyProjectile
	return null


func _build() -> void:
	if _mesh == null:
		_mesh = SphereMesh.new()
		_mesh.radius = 0.2
		_mesh.height = 0.4
		_mesh.radial_segments = 6
		_mesh.rings = 3
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	add_child(_visual)
	set_physics_process(false)
	visible = false


func _activate(
	from: Vector3, velocity: Vector3, cfg: AbilityData, damage: float, player: Node3D
) -> void:
	global_position = from
	_velocity = velocity
	_gravity = cfg.gravity
	_damage = damage
	_splash_radius = cfg.radius if cfg.gravity > 0.0 else 0.0
	_creep = cfg.leaves_creep
	_creep_duration = cfg.duration
	_creep_tick = cfg.tick_interval
	_life = MAX_LIFETIME
	_player = player
	_visual.material_override = _get_material(cfg.color)
	visible = true
	set_physics_process(true)


static func _get_material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = mat
	return _materials[key]


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_recycle()
		return
	var prev: Vector3 = global_position
	_velocity.y -= _gravity * delta
	var next: Vector3 = prev + _velocity * delta
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = WORLD_MASK
	_ray.from = prev
	_ray.to = next
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray)
	if not hit.is_empty():
		global_position = hit["position"]
		_impact(false)
		return
	global_position = next
	if _player != null and is_instance_valid(_player):
		var center: Vector3 = _player.global_position + Vector3.UP
		if center.distance_to(next) <= HIT_RADIUS:
			_impact(true)


func _impact(direct_hit: bool) -> void:
	if _player != null and is_instance_valid(_player) and _player.has_method("take_damage"):
		var center: Vector3 = _player.global_position + Vector3.UP
		var reach: float = HIT_RADIUS if _splash_radius <= 0.0 else _splash_radius
		if direct_hit or center.distance_to(global_position) <= reach:
			_player.call("take_damage", _damage, global_position)
	if _creep:
		CreepZone.spawn(
			get_tree(),
			_find_ground(global_position),
			_splash_radius_or_default(),
			_damage,
			_creep_duration,
			_creep_tick,
			_player
		)
	_recycle()


## Proyecta hacia abajo para que el creep quede en el suelo aunque el proyectil impacte en el aire.
func _find_ground(from: Vector3) -> Vector3:
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = WORLD_MASK
	_ray.from = from + Vector3.UP * 0.3
	_ray.to = from + Vector3.DOWN * GROUND_SEARCH_DISTANCE
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray)
	return hit["position"] if not hit.is_empty() else Vector3(from.x, 0.0, from.z)


func _splash_radius_or_default() -> float:
	return maxf(_splash_radius, 1.5)


func _recycle() -> void:
	set_physics_process(false)
	visible = false
	_player = null
	_pool.append(self)
