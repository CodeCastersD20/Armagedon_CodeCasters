class_name Pistol
extends Weapon
## Pistola: reproduce las animaciones del modelo (fire, reload) y aplica recoil e
## inclinación procedurales con los valores de su WeaponData (data/weapons/pistol.tres).

# Fracciones de la recarga: baja la inclinación, se mantiene y vuelve.
const TILT_IN: float = 0.18
const TILT_HOLD_END: float = 0.64
const TILT_OUT: float = 0.28
# Fracción del tiempo de recuperación que tarda la subida del recoil.
const KICK_IN: float = 0.12
const CHARGE_MIN_SECONDS: float = 0.45
const MAX_RICOCHET_BOUNCES: int = 5
# Disparo cargado (clic derecho): más fuerte que el normal.
const RICOCHET_RECOIL_MULT: float = 3.0
const RICOCHET_SHAKE: float = 0.9
const RICOCHET_SHAKE_SECONDS: float = 0.2
const RICOCHET_FLASH_SCALE: float = 2.4
const RICOCHET_FLASH_TIME_MULT: float = 2.5
const MAX_RICOCHET_HEAT: int = 3
const RICOCHET_COOL_INTERVAL: float = 2.5
const _RICOCHET_PROJECTILE = preload("res://scripts/Weapons/ricochet_projectile.gd")

static var _overheat_shader: Shader
static var _overheat_particle_mesh: BoxMesh

## Ricochet Ultrakill (Cañón Cielo): disparo cargado con clic derecho que rebota.
## Apagado = pistola normal.
@export var ricochet_ultrakill: bool = true:
	set(value):
		ricochet_ultrakill = value
		if not value and is_node_ready():
			_stop_charge_immediately()

var _base_rotation: Vector3
var _base_pos: Vector3
var _base_y: float
var _model_base_basis: Basis
var _model_base_pos: Vector3
var _pose_tween: Tween
var _fire_clip: StringName = &""
var _reload_clip: StringName = &""
var _charging: bool = false
var _charge_hold_time: float = 0.0
var _charge_ready_snapped: bool = false
var _ricochet_heat: int = 0
var _visual_heat: float = 0.0
var _heat_cool_timer: float = 0.0
var _gun_mesh: MeshInstance3D
var _overheat_material: ShaderMaterial
var _overheat_particles: CPUParticles3D

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _model: Node3D = get_node_or_null("Model")


func _ready() -> void:
	super._ready()
	_base_rotation = rotation
	_base_pos = position
	_base_y = position.y
	if _model != null:
		_model_base_basis = _model.transform.basis
		_model_base_pos = _model.position
	# Los nombres de clip se resuelven una vez, no en cada disparo.
	_fire_clip = _find_clip("fire")
	_reload_clip = _find_clip("reload")
	attacked.connect(_on_attacked)
	reload_started.connect(_on_reload_started)
	_setup_overheat_fx()


func _process(delta: float) -> void:
	super._process(delta)
	_update_overheat(delta)
	var wants_charge: bool = (
		is_ricochet_enabled()
		and _ricochet_heat < MAX_RICOCHET_HEAT
		and Input.is_action_pressed("block")
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not is_reloading()
		and _cooldown <= 0.0
	)
	if wants_charge:
		if not _charging:
			_charging = true
			_charge_hold_time = 0.0
			_charge_ready_snapped = false
			if _pose_tween != null and _pose_tween.is_valid():
				_pose_tween.kill()
		_charge_hold_time += delta
		var charge_t: float = clampf(_charge_hold_time / CHARGE_MIN_SECONDS, 0.0, 1.0)
		_update_charge_animation(delta, charge_t)
	elif _charging:
		if (
			_charge_hold_time >= CHARGE_MIN_SECONDS
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			and not is_reloading()
		):
			_try_fire_ricochet()
		else:
			_charge_hold_time = 0.0
			_charge_ready_snapped = false
			position.x = lerpf(position.x, _base_pos.x, 18.0 * delta)
			position.y = lerpf(position.y, _base_y, 18.0 * delta)
			position.z = lerpf(position.z, _base_pos.z, 18.0 * delta)
			rotation.x = lerp_angle(rotation.x, _base_rotation.x, 18.0 * delta)
			rotation.y = lerp_angle(rotation.y, _base_rotation.y, 18.0 * delta)
			rotation.z = lerp_angle(rotation.z, _base_rotation.z, 18.0 * delta)
			if (
				absf(position.y - _base_y) < 0.002
				and absf(angle_difference(rotation.x, _base_rotation.x)) < 0.01
				and absf(angle_difference(rotation.y, _base_rotation.y)) < 0.01
				and absf(angle_difference(rotation.z, _base_rotation.z)) < 0.01
			):
				_stop_charge_immediately()


func is_ricochet_enabled() -> bool:
	return ricochet_ultrakill


func _update_charge_animation(delta: float, charge_t: float) -> void:
	var just_ready: bool = charge_t >= 1.0 and not _charge_ready_snapped
	if just_ready:
		_charge_ready_snapped = true
	var target_pos := _base_pos + Vector3(0.0, -0.13, 0.05)
	position = position.lerp(target_pos, 15.0 * delta)
	rotation.x = lerp_angle(rotation.x, _base_rotation.x - deg_to_rad(24.0), 15.0 * delta)
	rotation.y = lerp_angle(rotation.y, _base_rotation.y, 15.0 * delta)
	rotation.z = lerp_angle(rotation.z, _base_rotation.z - deg_to_rad(8.0), 15.0 * delta)
	if just_ready:
		position.y -= 0.015
		rotation.x -= deg_to_rad(6.0)
	if _model != null:
		var jitter: float = 0.0025 * charge_t * charge_t
		_model.position = (
			_model_base_pos
			+ Vector3(randf_range(-jitter, jitter), randf_range(-jitter, jitter), 0.0)
		)


func _try_fire_ricochet() -> void:
	_stop_charge_immediately()
	if uses_magazine() and _ammo <= 0:
		try_reload()
		return
	_cooldown = maxf(data.attack_interval, 0.01)
	if uses_magazine():
		_ammo -= 1
		ammo_changed.emit(_ammo, data.magazine_size)
	_ricochet_heat = mini(_ricochet_heat + 1, MAX_RICOCHET_HEAT)
	_heat_cool_timer = RICOCHET_COOL_INTERVAL
	position.z = RECOIL_Z * RICOCHET_RECOIL_MULT
	_fire_ricochet_shot()
	attacked.emit()
	_play_sky_flick_recoil()
	var player := _player_body as Player
	if player != null:
		player.add_camera_punch(1.1)
		player.add_camera_shake(RICOCHET_SHAKE, RICOCHET_SHAKE_SECONDS)


func _play_sky_flick_recoil() -> void:
	_reset_pose_tween()
	var sky_rot: float = _base_rotation.x + deg_to_rad(72.0)
	var sky_y: float = _base_y + 0.06
	var sky_z: float = _base_pos.z + 0.14
	(
		_pose_tween
		. tween_property(self, "rotation:x", sky_rot, 0.065)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	_pose_tween.parallel().tween_property(self, "position:y", sky_y, 0.065)
	_pose_tween.parallel().tween_property(self, "position:z", sky_z, 0.065)
	(
		_pose_tween
		. tween_property(self, "rotation:x", _base_rotation.x, 0.18)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_pose_tween.parallel().tween_property(self, "position:y", _base_y, 0.18)
	_pose_tween.parallel().tween_property(self, "position:z", _base_pos.z, 0.18)


func _fire_ricochet_shot() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	_show_muzzle_flash()
	if _muzzle_flash != null:
		_muzzle_flash.scale *= RICOCHET_FLASH_SCALE
		_muzzle_left *= RICOCHET_FLASH_TIME_MULT
	var exclude: Array[RID] = _player_exclude()
	var cam_origin: Vector3 = camera.global_position
	var cam_dir: Vector3 = -camera.global_basis.z.normalized()
	var aim_query := PhysicsRayQueryParameters3D.create(
		cam_origin, cam_origin + cam_dir * data.max_range, 0xFFFFFFFF, exclude
	)
	var aim_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(aim_query)
	var target_pos: Vector3 = (
		aim_hit["position"] if not aim_hit.is_empty() else cam_origin + cam_dir * data.max_range
	)
	var spawn_pos: Vector3 = _muzzle_flash.global_position if _muzzle_flash != null else cam_origin
	var proj_dir: Vector3 = (target_pos - spawn_pos).normalized()
	if proj_dir.length_squared() < 0.0001:
		proj_dir = cam_dir
	(
		_RICOCHET_PROJECTILE
		. spawn(
			get_tree(),
			spawn_pos,
			proj_dir,
			MAX_RICOCHET_BOUNCES,
			data.damage,
			data.crit_chance,
			data.crit_multiplier,
			exclude,
			Callable(self, "_spawn_impact"),
		)
	)


func prewarm() -> void:
	await super.prewarm()
	if _overheat_particles != null:
		_overheat_particles.emitting = true
		await get_tree().process_frame
		if is_instance_valid(_overheat_particles) and _ricochet_heat <= 0:
			_overheat_particles.emitting = false
	if is_ricochet_enabled():
		await _RICOCHET_PROJECTILE.prewarm(get_tree())


func _setup_overheat_fx() -> void:
	if _model != null:
		_gun_mesh = _model.find_child("Gun", true, false) as MeshInstance3D
	if _overheat_shader == null:
		_overheat_shader = Shader.new()
		_overheat_shader.code = """shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float snap_resolution : hint_range(16.0, 640.0, 1.0) = 160.0;
varying float v_local_z;
void vertex() {
	v_local_z = VERTEX.z;
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 ndc = clip.xy / clip.w;
	ndc = floor(ndc * snap_resolution + 0.5) / snap_resolution;
	clip.xy = ndc * clip.w;
	POSITION = clip;
}
void fragment() {
	float barrel = smoothstep(0.55, 1.35, v_local_z);
	vec3 col = mix(vec3(0.95, 0.08, 0.02), vec3(1.0, 0.42, 0.06), heat);
	ALBEDO = col;
	ALPHA = barrel * heat * 0.88;
}
"""
	_overheat_material = ShaderMaterial.new()
	_overheat_material.shader = _overheat_shader
	_overheat_material.set_shader_parameter("heat", 0.0)

	if _overheat_particle_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.022, 0.022, 0.022)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		box.material = mat
		_overheat_particle_mesh = box

	_overheat_particles = CPUParticles3D.new()
	_overheat_particles.mesh = _overheat_particle_mesh
	_overheat_particles.amount = 16
	_overheat_particles.lifetime = 0.42
	_overheat_particles.local_coords = false
	_overheat_particles.emitting = false
	_overheat_particles.direction = Vector3(0.0, 1.0, 0.0)
	_overheat_particles.spread = 32.0
	_overheat_particles.gravity = Vector3(0.0, 1.4, 0.0)
	_overheat_particles.initial_velocity_min = 0.25
	_overheat_particles.initial_velocity_max = 0.7
	_overheat_particles.scale_amount_min = 0.6
	_overheat_particles.scale_amount_max = 1.4
	_overheat_particles.color = Color(0.88, 0.90, 0.94, 0.8)
	var muzzle_node := get_node_or_null("Muzzle") as Node3D
	_overheat_particles.position = muzzle_node.position if muzzle_node != null else muzzle_offset
	add_child(_overheat_particles)


func _update_overheat(delta: float) -> void:
	if _ricochet_heat > 0 and not _charging:
		_heat_cool_timer -= delta
		if _heat_cool_timer <= 0.0:
			_ricochet_heat = maxi(_ricochet_heat - 1, 0)
			_heat_cool_timer = RICOCHET_COOL_INTERVAL if _ricochet_heat > 0 else 0.0
	var target_heat: float = float(_ricochet_heat) / float(MAX_RICOCHET_HEAT)
	_visual_heat = move_toward(_visual_heat, target_heat, delta * 3.5)
	if _gun_mesh != null:
		if _visual_heat > 0.01:
			if _gun_mesh.material_overlay != _overheat_material:
				_gun_mesh.material_overlay = _overheat_material
			_overheat_material.set_shader_parameter("heat", _visual_heat)
		elif _gun_mesh.material_overlay != null:
			_gun_mesh.material_overlay = null
	if _overheat_particles != null:
		var should_emit: bool = _ricochet_heat > 0 and visible
		if _overheat_particles.emitting != should_emit:
			_overheat_particles.emitting = should_emit
		if should_emit:
			_overheat_particles.scale_amount_min = lerpf(0.35, 0.85, _visual_heat)
			_overheat_particles.scale_amount_max = lerpf(0.75, 1.55, _visual_heat)
			_overheat_particles.color = Color(
				lerpf(0.75, 0.96, _visual_heat),
				lerpf(0.78, 0.96, _visual_heat),
				lerpf(0.82, 1.0, _visual_heat),
				lerpf(0.35, 0.9, _visual_heat)
			)


func _stop_charge_immediately() -> void:
	_charging = false
	_charge_hold_time = 0.0
	_charge_ready_snapped = false
	if _model != null:
		_model.transform.basis = _model_base_basis
		_model.position = _model_base_pos
	rotation = _base_rotation
	position.x = _base_pos.x
	position.y = _base_y


func _on_attacked() -> void:
	_stop_charge_immediately()
	var clip: StringName = _fire_clip
	if clip != &"":
		_anim.stop()
		_anim.play(clip)
	_play_recoil()


func _on_reload_started(seconds: float) -> void:
	_stop_charge_immediately()
	var clip: StringName = _reload_clip
	if clip != &"":
		# Escala la velocidad para que dure lo que dice reload_seconds del .tres.
		var length: float = _anim.get_animation(clip).length
		_anim.play(clip, -1.0, length / maxf(seconds, 0.01))
	_play_reload_tilt(seconds)


## La pistola usa _play_recoil() con su propio _pose_tween.
func _play_base_recoil() -> void:
	pass


## Sube el cañón y el arma, y los devuelve a su sitio.
func _play_recoil(strength: float = 1.0) -> void:
	if data.recoil_kick_degrees == 0.0 and data.recoil_lift == 0.0:
		return
	_reset_pose_tween()
	var total: float = maxf(data.recoil_recovery_seconds, 0.01)
	var kick: float = _base_rotation.x + deg_to_rad(data.recoil_kick_degrees * strength)
	var up: float = _base_y + data.recoil_lift * strength
	_pose_tween.tween_property(self, "rotation:x", kick, total * KICK_IN)
	_pose_tween.parallel().tween_property(self, "position:y", up, total * KICK_IN)
	_pose_tween.tween_property(self, "rotation:x", _base_rotation.x, total * (1.0 - KICK_IN))
	_pose_tween.parallel().tween_property(self, "position:y", _base_y, total * (1.0 - KICK_IN))


## Inclina el arma mientras el cargador sale y entra.
func _play_reload_tilt(seconds: float) -> void:
	if (
		data.reload_tilt_pitch_degrees == 0.0
		and data.reload_tilt_roll_degrees == 0.0
		and data.reload_tilt_drop == 0.0
	):
		return
	_reset_pose_tween()
	var pitch: float = _base_rotation.x - deg_to_rad(data.reload_tilt_pitch_degrees)
	var roll: float = _base_rotation.z - deg_to_rad(data.reload_tilt_roll_degrees)
	var drop: float = _base_y - data.reload_tilt_drop
	var t_in: float = seconds * TILT_IN
	var t_hold: float = seconds * (TILT_HOLD_END - TILT_IN)
	var t_out: float = seconds * TILT_OUT
	(
		_pose_tween
		. tween_property(self, "rotation:x", pitch, t_in)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_pose_tween.parallel().tween_property(self, "rotation:z", roll, t_in)
	_pose_tween.parallel().tween_property(self, "position:y", drop, t_in)
	_pose_tween.tween_interval(t_hold)
	_pose_tween.tween_property(self, "rotation:x", _base_rotation.x, t_out)
	_pose_tween.parallel().tween_property(self, "rotation:z", _base_rotation.z, t_out)
	_pose_tween.parallel().tween_property(self, "position:y", _base_y, t_out)


## Al guardar el arma se cancela la recarga y se limpia la pose: sin esto el tween y el clip
## quedan pausados y se reanudan al volver a equiparla.
func cancel_reload() -> void:
	super.cancel_reload()
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_anim.stop()
	_stop_charge_immediately()
	position.y = _base_y


func _reset_pose_tween() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	_pose_tween = create_tween()


## Busca la animación por nombre, con o sin prefijo de librería ("fire" o "lib/fire").
func _find_clip(clip_name: String) -> StringName:
	for anim_name in _anim.get_animation_list():
		if anim_name == clip_name or anim_name.ends_with("/" + clip_name):
			return anim_name
	return &""
