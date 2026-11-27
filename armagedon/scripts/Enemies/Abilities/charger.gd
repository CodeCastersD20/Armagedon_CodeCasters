class_name Charger
extends EnemyAbility
## Cargador (#6): aviso de `windup` s con línea roja en el suelo y embestida recta hasta chocar
## con el jugador o una pared.

enum State { IDLE, WINDUP, DASH, RECOVER }

const MIN_TRIGGER_DISTANCE: float = 4.0
const RECOVER_SECONDS: float = 0.6
const LINE_WIDTH: float = 0.5
const WORLD_MASK: int = 2

static var _line_mesh: BoxMesh
static var _line_material: StandardMaterial3D

var _state: State = State.IDLE
var _timer: float = 0.0
var _cooldown_left: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _saved_collision_mask: int = 0
var _line: MeshInstance3D


func _on_setup() -> void:
	_saved_collision_mask = enemy.collision_mask
	_cooldown_left = randf_range(0.0, cfg.cooldown)
	if _line_mesh == null:
		_line_mesh = BoxMesh.new()
		_line_mesh.size = Vector3(1.0, 0.02, 1.0)
		_line_material = StandardMaterial3D.new()
		_line_material.albedo_color = Color(1.0, 0.1, 0.1, 0.5)
		_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = _line_material
	_line.scale = Vector3(LINE_WIDTH, 1.0, cfg.max_range)
	_line.position = Vector3(0.0, 0.05, -cfg.max_range * 0.5)
	_line.visible = false
	enemy.add_child.call_deferred(_line)


func step(delta: float, player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var to_player: Vector3 = player.global_position - enemy.global_position
	to_player.y = 0.0
	match _state:
		State.IDLE:
			_cooldown_left -= delta
			var distance: float = to_player.length()
			if (
				_cooldown_left <= 0.0
				and distance <= cfg.max_range
				and distance >= MIN_TRIGGER_DISTANCE
			):
				_state = State.WINDUP
				_timer = cfg.windup
				enemy.override_animation = "Scream_lol"
				_set_line(true)
			return false
		State.WINDUP:
			enemy.velocity.x = 0.0
			enemy.velocity.z = 0.0
			enemy.face_direction(to_player)
			_timer -= delta
			if _timer <= 0.0:
				_dash_dir = (
					to_player.normalized()
					if to_player.length_squared() > 0.0001
					else -enemy.global_basis.z
				)
				_state = State.DASH
				_timer = cfg.duration
				_saved_collision_mask = enemy.collision_mask
				enemy.collision_mask = WORLD_MASK
				enemy.animation_speed_boost = maxf(cfg.animation_speed, 0.1)
				enemy.override_animation = "Run_Frantic"
				_set_line(false)
			return true
		State.DASH:
			_timer -= delta
			var dash_speed: float = (
				cfg.charge_speed if cfg.charge_speed > 0.0 else cfg.projectile_speed
			)
			enemy.velocity.x = _dash_dir.x * dash_speed
			enemy.velocity.z = _dash_dir.z * dash_speed
			enemy.face_direction(_dash_dir)
			if to_player.length() <= enemy.data.contact_range:
				_damage_player(player, cfg.damage)
				if cfg.player_stun_seconds > 0.0 and player.has_method("apply_stun"):
					player.call("apply_stun", cfg.player_stun_seconds)
				if cfg.knockback_speed > 0.0 and player.has_method("apply_knockback"):
					player.call("apply_knockback", _dash_dir * cfg.knockback_speed)
				_end_dash(false)
			elif enemy.is_on_wall():
				_end_dash(true)
			elif _timer <= 0.0:
				_end_dash(false)
			return true
		State.RECOVER:
			enemy.velocity.x = 0.0
			enemy.velocity.z = 0.0
			_timer -= delta
			if _timer <= 0.0:
				_state = State.IDLE
				enemy.override_animation = ""
				_cooldown_left = cfg.cooldown
			return true
	return false


func _end_dash(hit_wall: bool) -> void:
	if _saved_collision_mask != 0:
		enemy.collision_mask = _saved_collision_mask
	enemy.animation_speed_boost = 1.0
	enemy.override_animation = "WallSlam_Recover" if hit_wall else ""
	_state = State.RECOVER
	_timer = maxf(cfg.wall_stun_seconds, 0.01) if hit_wall else RECOVER_SECONDS


func _set_line(value: bool) -> void:
	if _line != null:
		_line.visible = value
