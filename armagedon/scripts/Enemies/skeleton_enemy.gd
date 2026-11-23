class_name SkeletonEnemy
extends AnimatedEnemy

const BASE_TEXTURE: Texture2D = preload("res://assets/models/enemies/skeleton/base.png")
const MODEL_HEIGHT: float = 1.8
const SNAP_RESOLUTION: float = 320.0
const WALK_ENTER: float = 0.15
const WALK_EXIT: float = 0.05
const SCRATCH_HYSTERESIS: float = 0.25
const ANIM_IDLE: String = "Zombie_Idle"
const ANIM_WALK: String = "Zombie_Walk_Fwd"
const ANIM_SCRATCH: String = "Zombie_Scratch"
const ANIM_LOD_NEAR_DIST_SQ: float = 100.0
const ANIM_LOD_MID_DIST_SQ: float = 400.0
const ANIM_LOD_MID_INTERVAL: float = 1.0 / 20.0
const ANIM_LOD_FAR_INTERVAL: float = 1.0 / 8.0
const CAM_CULL_DIST_SQ: float = 16.0

var _current_animation: String = ""
var _anim_accum: float = 0.0
var _last_dist_sq: float = INF

@onready var _model: Node3D = get_node_or_null("Model")
@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _ready() -> void:
	fallback_texture = BASE_TEXTURE
	super._ready()
	if _anim != null:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim_accum = randf_range(0.0, ANIM_LOD_FAR_INTERVAL)
	_play_animation(ANIM_IDLE)
	if _anim != null:
		_anim.advance(0.0)


func step_process(
	delta: float,
	cam_pos: Vector3 = Vector3.ZERO,
	cam_forward: Vector3 = Vector3.FORWARD,
	has_cam: bool = false,
) -> void:
	if _dead or _anim == null:
		return
	if has_cam:
		var to_enemy: Vector3 = global_position - cam_pos
		if to_enemy.length_squared() > CAM_CULL_DIST_SQ and to_enemy.dot(cam_forward) < 0.0:
			_anim_accum = minf(_anim_accum + delta, 0.25)
			return
	_step_animation_lod(delta, _last_dist_sq)


func step_physics(delta: float, player_node: Node3D, allow_nav: bool = true) -> void:
	super.step_physics(delta, player_node, allow_nav)
	if _dead or data == null or _model == null:
		return
	var dist_sq: float = INF
	if _player != null and is_instance_valid(_player):
		dist_sq = _player.global_position.distance_squared_to(global_position)
	_last_dist_sq = dist_sq
	var speed_sq: float = velocity.x * velocity.x + velocity.z * velocity.z
	var next_animation: String = ANIM_IDLE
	var scratch_enter_sq: float = data.contact_range * data.contact_range
	var scratch_exit: float = data.contact_range + SCRATCH_HYSTERESIS
	if _current_animation == ANIM_SCRATCH:
		if dist_sq <= scratch_exit * scratch_exit:
			next_animation = ANIM_SCRATCH
	elif dist_sq <= scratch_enter_sq:
		next_animation = ANIM_SCRATCH
	elif _current_animation == ANIM_WALK:
		if speed_sq > WALK_EXIT * WALK_EXIT:
			next_animation = ANIM_WALK
	elif speed_sq > WALK_ENTER * WALK_ENTER:
		next_animation = ANIM_WALK
	_play_animation(next_animation)


func _fit_model() -> void:
	var inverse: Transform3D = _model.transform.affine_inverse()
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = mesh as MeshInstance3D
		var mesh_box: AABB = inverse * mesh_instance.transform * mesh_instance.get_aabb()
		if mesh_box.size.length_squared() <= 0.0:
			continue
		if has_bounds:
			bounds = bounds.merge(mesh_box)
		else:
			bounds = mesh_box
			has_bounds = true
	if not has_bounds or bounds.size.y <= 0.001:
		return
	var factor: float = MODEL_HEIGHT / bounds.size.y
	var center: Vector3 = bounds.get_center()
	var correction: Vector3 = Vector3(-center.x, -bounds.position.y, -center.z) * factor
	_model.scale = Vector3.ONE * factor
	_model.position = _model.transform.basis.orthonormalized() * correction


func _play_animation(anim_name: String) -> void:
	if anim_name == _current_animation:
		return
	_current_animation = anim_name
	if _anim != null and _anim.has_animation(anim_name):
		_anim.play(anim_name, 0.15)


func _step_animation_lod(delta: float, dist_sq: float) -> void:
	if _anim == null:
		return
	_anim_accum += delta
	var interval: float = 0.0
	if dist_sq > ANIM_LOD_MID_DIST_SQ:
		interval = ANIM_LOD_FAR_INTERVAL
	elif dist_sq > ANIM_LOD_NEAR_DIST_SQ:
		interval = ANIM_LOD_MID_INTERVAL
	if _anim_accum >= interval:
		_anim.advance(_anim_accum)
		_anim_accum = 0.0
