class_name RicochetProjectile
extends Node3D
## Proyectil de ricochet con pooling: viaja a alta velocidad, rebota en paredes/suelo
## y daña enemigos al impactar hasta agotar sus rebotes.

const SPEED: float = 160.0
const MAX_LIFETIME: float = 2.5
const BOLT_LENGTH: float = 0.9
const BOLT_RADIUS: float = 0.055
const IMPACT_SCALE: float = 1.6
const SMART_BOUNCE_RANGE: float = 22.0
const SMART_BOUNCE_MIN_DOT: float = -0.15
const SMART_BOUNCE_CHANCE: float = 0.85
const TARGET_CHEST_HEIGHT: float = 1.0

static var _pool: Array = []
static var _mesh: BoxMesh
static var _material: StandardMaterial3D
static var _ray: PhysicsRayQueryParameters3D
static var _self_script: GDScript

var _velocity: Vector3 = Vector3.ZERO
var _bounces_left: int = 5
var _damage: float = 10.0
var _crit_chance: float = 0.05
var _crit_multiplier: float = 2.0
var _life: float = 0.0
var _exclude: Array[RID] = []
var _visual: MeshInstance3D
var _impact_callback: Callable


static func spawn(
	tree: SceneTree,
	origin: Vector3,
	direction: Vector3,
	bounces: int,
	damage: float,
	crit_chance: float,
	crit_multiplier: float,
	exclude: Array[RID],
	impact_callback: Callable = Callable()
) -> Node3D:
	if tree == null or tree.current_scene == null:
		return null
	var proj: Node3D = _take_from_pool(tree.current_scene)
	proj.global_position = origin
	var dir: Vector3 = direction.normalized()
	proj.set("_velocity", dir * SPEED)
	proj.set("_bounces_left", bounces)
	proj.set("_damage", damage)
	proj.set("_crit_chance", crit_chance)
	proj.set("_crit_multiplier", crit_multiplier)
	proj.set("_life", MAX_LIFETIME)
	proj.set("_exclude", exclude.duplicate())
	proj.set("_impact_callback", impact_callback)
	proj.call("_orient_to", dir)
	return proj


static func prewarm(tree: SceneTree) -> void:
	if tree == null or tree.current_scene == null:
		return
	var proj: Node3D = _take_from_pool(tree.current_scene)
	var camera: Camera3D = tree.root.get_camera_3d()
	if camera != null:
		proj.global_position = camera.global_position - camera.global_basis.z * 0.6
	proj.set_physics_process(false)
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(proj):
		proj.call("_release")


static func _take_from_pool(scene: Node) -> Node3D:
	var proj: Node3D = null
	while not _pool.is_empty() and proj == null:
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			var candidate := raw as Node3D
			if candidate != null and candidate.is_inside_tree():
				proj = candidate
	if proj == null:
		if _self_script == null:
			_self_script = load("res://scripts/Weapons/ricochet_projectile.gd") as GDScript
		proj = _self_script.new() as Node3D
		proj.call("_build_visual")
		scene.add_child(proj)
	proj.visible = true
	proj.set_physics_process(true)
	return proj


func _build_visual() -> void:
	if _mesh == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.albedo_color = Color(1.0, 0.6, 0.15)
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(BOLT_RADIUS, BOLT_RADIUS, BOLT_LENGTH)
		_mesh.material = _material
	_visual = MeshInstance3D.new()
	_visual.mesh = _mesh
	add_child(_visual)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or _bounces_left <= 0:
		_release()
		return
	var step: Vector3 = _velocity * delta
	var dist: float = step.length()
	if dist < 0.0001:
		return
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, 0xFFFFFFFF)
	_ray.from = global_position
	_ray.to = global_position + step
	_ray.exclude = _exclude
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(_ray)
	if hit.is_empty():
		global_position += step
		return
	var hit_pos: Vector3 = hit["position"]
	var hit_norm: Vector3 = hit["normal"]
	var collider: Object = hit["collider"]
	if _impact_callback.is_valid():
		_impact_callback.call(hit_pos, hit_norm, IMPACT_SCALE)
	var is_enemy: bool = collider != null and collider.has_method("take_damage")
	if is_enemy:
		var is_crit: bool = randf() < _crit_chance
		var dmg: float = _damage * (_crit_multiplier if is_crit else 1.0)
		collider.call("take_damage", dmg, is_crit)
		if collider is CollisionObject3D:
			_exclude.append((collider as CollisionObject3D).get_rid())
	_bounces_left -= 1
	if _bounces_left <= 0:
		_release()
		return
	var incoming_dir: Vector3 = _velocity.normalized()
	var bounced_dir: Vector3 = incoming_dir.bounce(hit_norm).normalized()
	var spawn_origin: Vector3 = hit_pos + hit_norm * 0.06
	var search_dir: Vector3 = incoming_dir if is_enemy else bounced_dir
	var next_dir: Vector3 = _pick_next_direction(spawn_origin, search_dir, bounced_dir)
	_velocity = next_dir * SPEED
	global_position = spawn_origin
	_orient_to(next_dir)


func _pick_next_direction(origin: Vector3, search_dir: Vector3, fallback_dir: Vector3) -> Vector3:
	if randf() <= SMART_BOUNCE_CHANCE:
		var target_dir: Vector3 = _find_smart_target_dir(origin, search_dir)
		if target_dir != Vector3.ZERO:
			return target_dir
	var flat_fallback := Vector3(fallback_dir.x, fallback_dir.y * 0.45, fallback_dir.z)
	if flat_fallback.length_squared() > 0.0001:
		return flat_fallback.normalized()
	return fallback_dir


func _find_smart_target_dir(origin: Vector3, search_dir: Vector3) -> Vector3:
	var tree: SceneTree = get_tree()
	if tree == null:
		return Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best_dir: Vector3 = Vector3.ZERO
	var best_dist_sq: float = SMART_BOUNCE_RANGE * SMART_BOUNCE_RANGE
	for node in tree.get_nodes_in_group("enemies"):
		var enemy := node as CollisionObject3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if _exclude.has(enemy.get_rid()):
			continue
		if enemy.has_method("is_dead") and enemy.call("is_dead"):
			continue
		var target_pos: Vector3 = enemy.global_position + Vector3.UP * TARGET_CHEST_HEIGHT
		var to_target: Vector3 = target_pos - origin
		var dist_sq: float = to_target.length_squared()
		if dist_sq < 0.01 or dist_sq >= best_dist_sq:
			continue
		var dir: Vector3 = to_target / sqrt(dist_sq)
		if search_dir.dot(dir) < SMART_BOUNCE_MIN_DOT:
			continue
		_ray.from = origin
		_ray.to = target_pos
		_ray.exclude = _exclude
		var los_hit: Dictionary = space.intersect_ray(_ray)
		if not los_hit.is_empty() and los_hit["collider"] != enemy:
			continue
		best_dist_sq = dist_sq
		best_dir = dir
	return best_dir


func _orient_to(dir: Vector3) -> void:
	if dir.length_squared() < 0.0001:
		return
	var up: Vector3 = Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	look_at(global_position + dir, up)


func _release() -> void:
	visible = false
	set_physics_process(false)
	if not _pool.has(self):
		_pool.append(self)
