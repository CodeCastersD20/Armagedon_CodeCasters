class_name SkeletonEnemy
extends AnimatedEnemy

const BASE_TEXTURE: Texture2D = preload("res://assets/models/enemies/skeleton/base.png")
const ANIM_LOD_NEAR_DIST_SQ: float = 100.0
const ANIM_LOD_MID_DIST_SQ: float = 400.0
const ANIM_LOD_MID_INTERVAL: float = 1.0 / 20.0
const ANIM_LOD_FAR_INTERVAL: float = 1.0 / 8.0
const CAM_CULL_DIST_SQ: float = 16.0

var _anim_accum: float = 0.0
var _last_dist_sq: float = INF


func _ready() -> void:
	fallback_texture = BASE_TEXTURE
	super._ready()
	if _anim != null:
		_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_anim_accum = randf_range(0.0, ANIM_LOD_FAR_INTERVAL)
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
	if _player != null and is_instance_valid(_player):
		_last_dist_sq = _player.global_position.distance_squared_to(global_position)
	else:
		_last_dist_sq = INF


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
