class_name SkeletonEnemy
extends Enemy

const BASE_TEXTURE: Texture2D = preload("res://assets/models/enemies/skeleton/base.png")
const MODEL_HEIGHT: float = 1.8
const SNAP_RESOLUTION: float = 320.0
const WALK_ENTER: float = 0.15
const WALK_EXIT: float = 0.05
const SCRATCH_HYSTERESIS: float = 0.25
const ANIM_IDLE: String = "Zombie_Idle"
const ANIM_WALK: String = "Zombie_Walk_Fwd"
const ANIM_SCRATCH: String = "Zombie_Scratch"

@onready var _model: Node3D = get_node_or_null("Model")
@onready var _anim: AnimationPlayer = get_node_or_null("AnimationPlayer")

var _current_animation: String = ""


func _ready() -> void:
	if _model != null:
		PsxStyle.apply(_model, BASE_TEXTURE, SNAP_RESOLUTION)
		_fit_model()
	super._ready()
	_play_animation(ANIM_IDLE)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead or data == null or _model == null:
		return
	var distance: float = INF
	if _player != null and is_instance_valid(_player):
		distance = _player.global_position.distance_to(global_position)
	var speed: float = Vector2(velocity.x, velocity.z).length()
	var next_animation: String = ANIM_IDLE
	if _current_animation == ANIM_SCRATCH:
		if distance <= data.contact_range + SCRATCH_HYSTERESIS:
			next_animation = ANIM_SCRATCH
	elif distance <= data.contact_range:
		next_animation = ANIM_SCRATCH
	elif _current_animation == ANIM_WALK:
		if speed > WALK_EXIT:
			next_animation = ANIM_WALK
	elif speed > WALK_ENTER:
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
	var correction: Vector3 = Vector3(
		-center.x, -bounds.position.y, -center.z
	) * factor
	_model.scale = Vector3.ONE * factor
	_model.position = _model.transform.basis.orthonormalized() * correction


func _play_animation(name: String) -> void:
	if name == _current_animation:
		return
	_current_animation = name
	if _anim != null and _anim.has_animation(name):
		_anim.play(name, 0.15)
