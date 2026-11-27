class_name Flamethrower
extends EnemyAbility
## Lanzallamas (#4): chorro de fuego en cono cerrado hecho con partículas (GPUParticles3D en espacio
## mundo, así la llama se arrastra al girar el enemigo). Al alcanzar al jugador lo quema
## `duration` s con daño por tick, aunque salga del cono.

const FLAME_LIFETIME: float = 0.6
const FLAME_AMOUNT: int = 28
const EMITTER_OFFSET: Vector3 = Vector3(0.0, 1.2, -0.7)
## El chorro se ve a esta distancia (múltiplo del alcance) aunque aún no queme.
const VISIBLE_RANGE_FACTOR: float = 1.5

static var _quad: QuadMesh
static var _material: StandardMaterial3D
static var _process_cache: Dictionary = {}

var _burn_left: float = 0.0
var _tick_left: float = 0.0
var _flames: GPUParticles3D


func _on_setup() -> void:
	_ensure_shared()
	_flames = GPUParticles3D.new()
	_flames.amount = FLAME_AMOUNT
	_flames.lifetime = FLAME_LIFETIME
	_flames.local_coords = false
	_flames.process_material = _get_process_material()
	_flames.draw_pass_1 = _quad
	_flames.visibility_aabb = AABB(
		Vector3(-cfg.max_range, -2.0, -cfg.max_range * 2.0),
		Vector3(cfg.max_range * 2.0, 6.0, cfg.max_range * 2.5)
	)
	_flames.position = EMITTER_OFFSET
	_flames.emitting = false
	enemy.add_child.call_deferred(_flames)


static func _ensure_shared() -> void:
	if _quad != null:
		return
	_quad = QuadMesh.new()
	_quad.size = Vector2(0.55, 0.55)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.no_depth_test = false
	_quad.material = _material


## Un ParticleProcessMaterial por combinación alcance/ángulo (compartido entre enemigos iguales).
func _get_process_material() -> ParticleProcessMaterial:
	var key: String = "%s|%s" % [cfg.max_range, cfg.arc_degrees]
	if _process_cache.has(key):
		return _process_cache[key]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(
		[
			Color(1.0, 0.95, 0.6, 0.9),
			Color(1.0, 0.5, 0.1, 0.8),
			Color(0.8, 0.12, 0.02, 0.5),
			Color(0.15, 0.05, 0.05, 0.0),
		]
	)
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.3))
	scale_curve.add_point(Vector2(1.0, 1.6))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 0.0, -1.0)
	mat.spread = cfg.arc_degrees * 0.5
	var speed: float = cfg.max_range / FLAME_LIFETIME
	mat.initial_velocity_min = speed * 0.8
	mat.initial_velocity_max = speed * 1.1
	mat.gravity = Vector3(0.0, 1.5, 0.0)
	mat.scale_min = 0.7
	mat.scale_max = 1.2
	mat.scale_curve = scale_tex
	mat.color_ramp = ramp
	_process_cache[key] = mat
	return mat


func step(delta: float, player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var distance: float = _flat_distance(player)
	var firing: bool = distance <= cfg.max_range * VISIBLE_RANGE_FACTOR
	_set_flames(firing)
	if firing:
		enemy.trigger_ability_attack_anim(0.2)
	if _is_in_cone(player, distance):
		_burn_left = cfg.duration
	if _burn_left > 0.0:
		BurnOverlay.ping(enemy.get_tree())
		_burn_left -= delta
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left = maxf(cfg.tick_interval, 0.05)
			_damage_player(player, cfg.damage)
	return false


func _set_flames(value: bool) -> void:
	if _flames != null and _flames.emitting != value:
		_flames.emitting = value


func _is_in_cone(player: Node3D, distance: float) -> bool:
	if distance > cfg.max_range:
		return false
	if distance < 0.001:
		return true
	var to_player: Vector3 = player.global_position - enemy.global_position
	to_player.y = 0.0
	var forward: Vector3 = -enemy.global_basis.z
	forward.y = 0.0
	return (
		forward.normalized().dot(to_player.normalized()) >= cos(deg_to_rad(cfg.arc_degrees * 0.5))
	)
