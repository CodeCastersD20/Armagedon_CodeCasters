class_name AnimatedEnemy
extends Enemy

@export var model_height: float = 1.8
@export var fallback_texture: Texture2D
@export var snap_resolution: float = 320.0
@export var walk_enter_speed: float = 0.15
@export var walk_exit_speed: float = 0.05
@export var attack_hysteresis: float = 0.25
@export var attack_hit_window: float = 0.08
@export var animation_crossfade: float = 0.15
@export var walk_animation_speed: float = 1.0
@export var fit_to_visual_mesh: bool = false
@export var ground_offset: float = 0.0
@export var idle_animation: String = "Zombie_Idle"
@export var walk_animation: String = "Zombie_Walk_Fwd"
@export var attack_animation: String = "Zombie_Scratch"

var _current_animation: String = ""

@onready var _model: Node3D = get_node_or_null("Model")
@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")


func _ready() -> void:
	if _anim == null and _model != null:
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _model != null:
		if use_psx_style:
			PsxStyle.apply(_model, fallback_texture, snap_resolution)
		_fit_model()
	super._ready()
	_play_animation(idle_animation)


func step_physics(delta: float, player_node: Node3D, allow_nav: bool = true) -> void:
	super.step_physics(delta, player_node, allow_nav)
	if _dead or data == null or _model == null:
		return
	var distance: float = INF
	if _player != null and is_instance_valid(_player):
		distance = _player.global_position.distance_to(global_position)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var next_animation: String = idle_animation
	if _current_animation == attack_animation:
		if distance <= data.contact_range + attack_hysteresis:
			next_animation = attack_animation
	elif distance <= data.contact_range:
		next_animation = attack_animation
	elif _current_animation == walk_animation:
		if speed > walk_exit_speed:
			next_animation = walk_animation
	elif speed > walk_enter_speed:
		next_animation = walk_animation
	_play_animation(next_animation)


func _can_apply_contact_damage() -> bool:
	if _anim == null or data == null:
		return false
	if _anim.current_animation != attack_animation:
		return false
	var impact_time: float = maxf(data.contact_hit_delay_seconds, 0.0)
	return absf(_anim.current_animation_position - impact_time) <= attack_hit_window


func _fit_model() -> void:
	var to_model: Transform3D = _model.global_transform.affine_inverse()
	if fit_to_visual_mesh:
		var visual_bounds: AABB = _get_visual_bounds(to_model)
		if visual_bounds.size.y > 0.001:
			_apply_fit(visual_bounds)
			return
	var skeleton: Skeleton3D = _model as Skeleton3D
	if skeleton == null:
		skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		var skeleton_to_model: Transform3D = to_model * skeleton.global_transform
		var min_pos: Vector3 = Vector3(INF, INF, INF)
		var max_pos: Vector3 = Vector3(-INF, -INF, -INF)
		for bone_index in skeleton.get_bone_count():
			var bone_pos: Vector3 = (
				skeleton_to_model * skeleton.get_bone_global_pose(bone_index).origin
			)
			min_pos = Vector3(
				minf(min_pos.x, bone_pos.x),
				minf(min_pos.y, bone_pos.y),
				minf(min_pos.z, bone_pos.z)
			)
			max_pos = Vector3(
				maxf(max_pos.x, bone_pos.x),
				maxf(max_pos.y, bone_pos.y),
				maxf(max_pos.z, bone_pos.z)
			)
		var size: Vector3 = max_pos - min_pos
		if size.y > 0.001:
			_apply_fit(AABB(min_pos, size))
			return
	var mesh_bounds: AABB = _get_all_mesh_bounds(to_model)
	if mesh_bounds.size.y > 0.001:
		_apply_fit(mesh_bounds)


func _get_visual_bounds(to_model: Transform3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = mesh as MeshInstance3D
		if mesh_instance == null or mesh_instance.skin == null:
			continue
		var mesh_box: AABB = to_model * mesh_instance.global_transform * mesh_instance.get_aabb()
		if mesh_box.size.length_squared() <= 0.0:
			continue
		if has_bounds:
			bounds = bounds.merge(mesh_box)
		else:
			bounds = mesh_box
			has_bounds = true
	return bounds


func _get_all_mesh_bounds(to_model: Transform3D) -> AABB:
	var bounds: AABB = AABB()
	var has_bounds: bool = false
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = mesh as MeshInstance3D
		if mesh_instance == null:
			continue
		var mesh_box: AABB = to_model * mesh_instance.global_transform * mesh_instance.get_aabb()
		if mesh_box.size.length_squared() <= 0.0:
			continue
		if has_bounds:
			bounds = bounds.merge(mesh_box)
		else:
			bounds = mesh_box
			has_bounds = true
	return bounds


func _apply_fit(bounds: AABB) -> void:
	var factor: float = model_height / bounds.size.y
	var center: Vector3 = bounds.get_center()
	var correction: Vector3 = Vector3(-center.x, -bounds.position.y, -center.z) * factor
	_model.scale = Vector3.ONE * factor
	_model.position = _model.transform.basis.orthonormalized() * correction
	_model.position.y += ground_offset


func _play_animation(name: String) -> void:
	if _anim != null:
		_anim.speed_scale = walk_animation_speed if name == walk_animation else 1.0
	if name == _current_animation:
		if _anim == null or _anim.is_playing():
			return
		_current_animation = ""
	_current_animation = name
	if _anim != null and _anim.has_animation(name):
		_anim.play(name, animation_crossfade)
