class_name GameFlow
extends Node
## Controla la cinemática 100% en primera persona:
## - Entrada: descenso divino lento mirando la arena -> suelta y caída fuerte -> cráter y piedras
##   -> levantarse poco a poco mirando al frente + sacar escudo y espada desde abajo hacia arriba.
## - Escape (HP 0): slow-mo -> aro de luz -> flotar viendo la arena -> voltear al portal blanco
##   en el cielo -> salir disparado hacia él -> regreso a PlayMenu.

const DAMAGE_VIGNETTE_SHADER: Shader = preload("res://assets/shaders/damage_vignette.gdshader")
const WHITE_PORTAL_SHADER: Shader = preload("res://assets/shaders/white_portal.gdshader")
const PLAY_MENU_SCENE_PATH: String = "res://scenes/UI/PlayMenu.tscn"
const SKY_START_Y: float = 34.0
const DIVINE_RELEASE_Y: float = 15.0
const PORTAL_Y: float = 42.0
const ROCK_COUNT: int = 12
const STREAK_COUNT: int = 16
const ENTRY_DESCENT_SECONDS: float = 2.0
const ENTRY_DROP_SECONDS: float = 0.42
const ENTRY_STAND_SECONDS: float = 0.95
const ESCAPE_SLOWMO_SCALE: float = 0.50
const ESCAPE_FALL_SECONDS: float = 2.50
const ESCAPE_HALO_APPEAR_SECONDS: float = 1.00
const ESCAPE_FLOAT_SECONDS: float = 2.60
const ESCAPE_TURN_SECONDS: float = 0.60
const ESCAPE_LAUNCH_SECONDS: float = 1.05
const CIRCLE_FOG_COLORS: Array[Color] = [
	Color(0.28, 0.28, 0.30, 1.0),  # 1-10: Limbo (gris ceniza)
	Color(0.45, 0.05, 0.25, 1.0),  # 11-20: Lujuria
	Color(0.16, 0.34, 0.08, 1.0),  # 21-30: Gula
	Color(0.48, 0.28, 0.04, 1.0),  # 31-40: Avaricia y Prodigalidad
	Color(0.55, 0.02, 0.02, 1.0),  # 41-50: Ira y Pereza
	Color(0.55, 0.16, 0.02, 1.0),  # 51-60: Herejía
	Color(0.38, 0.01, 0.03, 1.0),  # 61-70: Violencia
	Color(0.26, 0.06, 0.38, 1.0),  # 71-80: Fraude
	Color(0.08, 0.22, 0.42, 1.0),  # 81-90: Traición
	Color(0.22, 0.01, 0.05, 1.0),  # 91-100: Castillo de Lucifer / Lucifer
	Color(0.05, 0.02, 0.10, 1.0),  # 101+: El Vacío
]
const CIRCLE_NAMES: Array[String] = [
	"1. LIMBO",
	"2. LUJURIA",
	"3. GULA",
	"4. AVARICIA Y PRODIGALIDAD",
	"5. IRA Y PEREZA",
	"6. HEREJÍA",
	"7. VIOLENCIA",
	"8. FRAUDE",
	"9. TRAICIÓN",
	"CASTILLO DE LUCIFER",
	"EL VACÍO",
]
const LOW_HP_THRESHOLD: float = 0.35

@export_enum("Tinte Rojo", "Manchas de Sangre", "Ambos") var damage_fx_mode: int = 0
@export var world_path: NodePath = NodePath("../World")
@export var hud_path: NodePath = NodePath("../MainHud")
@export var round_manager_path: NodePath = NodePath("../RoundManager")

var _world: Node3D
var _world_env: WorldEnvironment
var _hud: Node
var _round_manager: RoundManager
var _player: Player
var _player_head: Node3D
var _player_camera: Camera3D
var _weapon_holder: Node3D
var _shield: Shield
var _light_halo: MeshInstance3D
var _streak_ring: Node3D
var _streak_speeds: Array[float] = []
var _white_portal: MeshInstance3D
var _portal_ring_outer: MeshInstance3D
var _portal_ring_inner: MeshInstance3D
var _crater: MeshInstance3D
var _rocks: Array[MeshInstance3D] = []
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _circle_label: Label
var _circle_tween: Tween
var _current_circle_idx: int = -1
var _damage_rect: ColorRect
var _damage_mat: ShaderMaterial
var _tween: Tween
var _weapon_holder_base_y: float = -0.3
var _shield_base_y: float = -0.26
var _base_fov: float = 90.0
var _hp_ratio: float = 1.0
var _heartbeat_timer: float = 0.0
var _entry_land_pos: Vector3 = Vector3.ZERO
var _in_transition: bool = false


func _ready() -> void:
	add_to_group("game_flow")
	_world = get_node_or_null(world_path) as Node3D
	if _world != null:
		_world_env = _world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_hud = get_node_or_null(hud_path)
	_round_manager = get_node_or_null(round_manager_path) as RoundManager
	if _world == null:
		push_error("GameFlow: falta referencia a World")
		set_process(false)
		return

	_set_gameplay_active(false)
	set_process(false)
	if _hud != null:
		_hud.visible = false

	_build_fx_once()
	_resolve_world_refs.call_deferred()


func _resolve_world_refs() -> void:
	_set_gameplay_active(false)
	_player = get_tree().get_first_node_in_group("player") as Player
	if _round_manager == null:
		_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _player == null:
		push_error("GameFlow: no se encontró Player en el grupo 'player'")
		return

	_player_head = _player.get_node_or_null("Head") as Node3D
	_player_camera = _player.get_node_or_null("Head/Camera3D") as Camera3D
	if _player_camera != null:
		_base_fov = _player_camera.fov
	_weapon_holder = _player.get_node_or_null("Head/Camera3D/WeaponHolder") as Node3D
	_shield = _player.get_node_or_null("Head/Camera3D/Shield") as Shield
	if _weapon_holder != null:
		_weapon_holder_base_y = _weapon_holder.position.y
	if _shield != null:
		_shield_base_y = _shield.rest_position.y

	_entry_land_pos = _find_entry_landing_pos(_player.global_position)

	if not _player.player_escaped.is_connected(_on_player_escaped):
		_player.player_escaped.connect(_on_player_escaped)
	if not _player.health_changed.is_connected(_on_player_health_changed):
		_player.health_changed.connect(_on_player_health_changed)
	if not _player.slam_landed.is_connected(_on_player_slam_landed):
		_player.slam_landed.connect(_on_player_slam_landed)
	if _round_manager != null and not _round_manager.round_started.is_connected(_on_round_started):
		_round_manager.round_started.connect(_on_round_started)

	await _prewarm_fx()
	_run_entry_cinematic()


func _run_entry_cinematic() -> void:
	_in_transition = true
	_kill_tween()
	_set_gameplay_active(false)
	_player.reset_for_new_run()
	_player.set_cinematic_mode(true)
	if _hud != null:
		_hud.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if _player_camera != null:
		_player_camera.current = true
		_player_camera.fov = _base_fov
		_player_camera.position = Vector3.ZERO
		_player_camera.rotation = Vector3.ZERO
	_hp_ratio = 1.0
	_heartbeat_timer = 0.0
	_update_damage_shader(0.0, 0.0)
	_apply_circle_fog(1, true)

	# Posición inicial en el cielo sobre el punto de spawn del jugador en la escena.
	_player.global_position = Vector3(
		_entry_land_pos.x, _entry_land_pos.y + SKY_START_Y, _entry_land_pos.z
	)
	_player.rotation.y = 0.0
	if _player_head != null:
		_player_head.rotation.x = deg_to_rad(-65.0)
	_player.set_head_height(_player.get_head_stand_y())

	# Ocultar armas abajo hasta el momento de sacarlas al levantarse.
	if _weapon_holder != null:
		_weapon_holder.visible = false
		_weapon_holder.position.y = _weapon_holder_base_y - 0.8
	if _shield != null:
		_shield.visible = false
		_shield.position.y = _shield_base_y - 0.8

	# Aro de luz místico + líneas brillantes orbitando alrededor durante el descenso divino.
	_light_halo.global_position = _player.global_position + Vector3(0.0, 0.9, 0.0)
	_light_halo.scale = Vector3.ONE * 1.15
	_light_halo.visible = true
	_streak_ring.global_position = _player.global_position + Vector3(0.0, 0.9, 0.0)
	_streak_ring.visible = true
	set_process(true)
	_fade_rect.color = Color(1.0, 0.96, 0.85, 0.55)

	# 1. Descenso lento místico: un poder divino te baja poco a poco mientras miras la arena.
	var release_y: float = _entry_land_pos.y + DIVINE_RELEASE_Y
	_tween = create_tween().set_parallel(true)
	(
		_tween
		. tween_property(_player, "global_position:y", release_y, ENTRY_DESCENT_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		_tween
		. tween_property(_light_halo, "global_position:y", release_y + 0.9, ENTRY_DESCENT_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	if _player_head != null:
		(
			_tween
			. tween_property(_player_head, "rotation:x", deg_to_rad(-78.0), ENTRY_DESCENT_SECONDS)
			. set_trans(Tween.TRANS_SINE)
		)
	_tween.tween_property(_fade_rect, "color:a", 0.0, 1.1)
	await _tween.finished

	# 2. El poder divino te suelta y caes rápido con tu propio poder.
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_light_halo, "scale", Vector3.ONE * 0.1, 0.22)
	(
		_tween
		. tween_property(_player, "global_position:y", _entry_land_pos.y, ENTRY_DROP_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	await _tween.finished
	_light_halo.visible = false
	_streak_ring.visible = false
	_update_process_state()

	# 3. Impacto al suelo: cráter + piedras volando alrededor + golpe de cámara en 1ra persona.
	_spawn_crater(_entry_land_pos)
	_spawn_rocks(_entry_land_pos)
	_player.set_head_height(0.48)
	await _shake_first_person_cam(0.24, 0.16)

	# 4. Levantarse poco a poco, enderezar la vista y sacar escudo + espada desde abajo.
	if _weapon_holder != null:
		_weapon_holder.visible = true
	if _shield != null:
		_shield.visible = true
	var stand_y: float = _player.get_head_stand_y()
	_tween = create_tween().set_parallel(true)
	(
		_tween
		. tween_method(_player.set_head_height, 0.48, stand_y, ENTRY_STAND_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	if _player_head != null:
		(
			_tween
			. tween_property(_player_head, "rotation:x", 0.0, ENTRY_STAND_SECONDS)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_OUT)
		)
	if _weapon_holder != null:
		(
			_tween
			. tween_property(
				_weapon_holder, "position:y", _weapon_holder_base_y, ENTRY_STAND_SECONDS
			)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	if _shield != null:
		(
			_tween
			. tween_property(_shield, "position:y", _shield_base_y, ENTRY_STAND_SECONDS)
			. set_trans(Tween.TRANS_BACK)
			. set_ease(Tween.EASE_OUT)
		)
	await _tween.finished

	# 5. Inicia partida normal.
	_hide_rocks()
	_set_gameplay_active(true)
	_player.set_cinematic_mode(false)
	if _hud != null:
		_hud.visible = true
	if _round_manager != null:
		_round_manager.start_game()
	_in_transition = false


func _on_player_escaped() -> void:
	if _in_transition or _player == null:
		return
	_in_transition = true
	_run_escape_cinematic()


func _run_escape_cinematic() -> void:
	_kill_tween()
	_player.set_cinematic_mode(true)
	_update_process_state()
	if _hud != null:
		_hud.visible = false
	if _player_camera != null:
		_player_camera.current = true
		_player_camera.fov = _base_fov
	_hp_ratio = 0.0
	_update_damage_shader(1.0, 0.0)

	# Quitar armas y escudo de la mano inmediatamente al morir.
	if _weapon_holder != null:
		_weapon_holder.visible = false
	if _shield != null:
		_shield.visible = false

	# 1. Slow-motion (0.5x) por 2.5 s: enemigos y animaciones siguen a mitad de velocidad
	#    mientras el jugador cae empujado de lado al piso.
	Engine.time_scale = ESCAPE_SLOWMO_SCALE

	var origin: Vector3 = _player.global_position
	var side_dir: Vector3 = _player.global_basis.x
	side_dir.y = 0.0
	side_dir = side_dir.normalized() if side_dir.length_squared() > 0.001 else Vector3.RIGHT
	var fall_pos: Vector3 = origin + side_dir * 0.9

	var fall_tw: Tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	(
		fall_tw
		. tween_property(_player, "global_position:x", fall_pos.x, ESCAPE_FALL_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		fall_tw
		. tween_property(_player, "global_position:z", fall_pos.z, ESCAPE_FALL_SECONDS)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		fall_tw
		. tween_method(
			_player.set_head_height, _player.get_head_stand_y(), 0.28, ESCAPE_FALL_SECONDS
		)
		. set_trans(Tween.TRANS_BOUNCE)
		. set_ease(Tween.EASE_OUT)
	)
	if _player_camera != null:
		(
			fall_tw
			. tween_property(_player_camera, "rotation:z", deg_to_rad(-58.0), ESCAPE_FALL_SECONDS)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	if _player_head != null:
		(
			fall_tw
			. tween_property(_player_head, "rotation:x", deg_to_rad(14.0), ESCAPE_FALL_SECONDS)
			. set_trans(Tween.TRANS_QUAD)
		)
	_tween = fall_tw
	await _tween.finished

	# 2. Durante 1.0 s aparece el halo de luz + líneas brillantes antes de empezar a flotar.
	_light_halo.global_position = fall_pos + Vector3(0.0, 1.1, 0.0)
	_light_halo.scale = Vector3.ONE * 0.15
	_light_halo.visible = true
	_streak_ring.global_position = fall_pos + Vector3(0.0, 1.1, 0.0)
	_streak_ring.visible = true
	set_process(true)

	_tween = create_tween().set_ignore_time_scale(true)
	(
		_tween
		. tween_property(_light_halo, "scale", Vector3.ONE * 1.15, ESCAPE_HALO_APPEAR_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	await _tween.finished

	# 3. Apenas aquí se detiene el combate y el aro de luz empieza a elevar al personaje.
	_set_gameplay_active(false)
	_white_portal.global_position = Vector3(fall_pos.x, PORTAL_Y, fall_pos.z)
	_white_portal.visible = true
	_update_process_state()

	var start_yaw: float = _player.rotation.y
	var stand_y: float = _player.get_head_stand_y()
	_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	_tween.tween_property(_player, "global_position:y", fall_pos.y + 4.8, ESCAPE_FLOAT_SECONDS)
	_tween.tween_property(_light_halo, "global_position:y", fall_pos.y + 5.9, ESCAPE_FLOAT_SECONDS)
	_tween.tween_method(_player.set_head_height, 0.28, stand_y, 0.65).set_trans(Tween.TRANS_CUBIC)
	if _player_camera != null:
		_tween.tween_property(_player_camera, "rotation:z", 0.0, 0.65).set_trans(Tween.TRANS_CUBIC)
	if _player_head != null:
		_tween.tween_property(_player_head, "rotation:x", deg_to_rad(-28.0), 0.75).set_trans(
			Tween.TRANS_SINE
		)

	# Mirar a ambos lados viendo la arena mientras se eleva.
	var look_tw: Tween = create_tween().set_ignore_time_scale(true)
	(
		look_tw
		. tween_property(
			_player, "rotation:y", start_yaw - deg_to_rad(38.0), ESCAPE_FLOAT_SECONDS * 0.45
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	(
		look_tw
		. tween_property(
			_player, "rotation:y", start_yaw + deg_to_rad(42.0), ESCAPE_FLOAT_SECONDS * 0.55
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	await _tween.finished

	# 2. Voltear en primera persona hacia arriba mirando directo al portal blanco en el cielo.
	Engine.time_scale = 1.0
	if _player_head != null:
		_tween = create_tween().set_ignore_time_scale(true)
		(
			_tween
			. tween_property(_player_head, "rotation:x", deg_to_rad(86.0), ESCAPE_TURN_SECONDS)
			. set_trans(Tween.TRANS_CUBIC)
			. set_ease(Tween.EASE_IN_OUT)
		)
		await _tween.finished

	# 3. Salir disparado hacia el portal blanco + flash blanco al entrar.
	_fade_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_tween = create_tween().set_ignore_time_scale(true).set_parallel(true)
	(
		_tween
		. tween_property(_player, "global_position:y", PORTAL_Y, ESCAPE_LAUNCH_SECONDS)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_IN)
	)
	(
		_tween
		. tween_property(_light_halo, "global_position:y", PORTAL_Y + 0.8, ESCAPE_LAUNCH_SECONDS)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_IN)
	)
	_tween.tween_property(_fade_rect, "color:a", 1.0, 0.30).set_delay(ESCAPE_LAUNCH_SECONDS - 0.30)
	await _tween.finished

	# 4. Restaurar tiempo, liberar mouse y volver a la pantalla Play.
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _round_manager != null:
		_round_manager.reset_to_idle()
	get_tree().change_scene_to_file(PLAY_MENU_SCENE_PATH)


func _spawn_crater(center: Vector3) -> void:
	_crater.global_position = Vector3(center.x, 0.06, center.z)
	_crater.scale = Vector3(0.1, 1.0, 0.1)
	_crater.visible = true
	var crater_tw: Tween = create_tween()
	(
		crater_tw
		. tween_property(_crater, "scale", Vector3.ONE, 0.25)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)


func _spawn_rocks(center: Vector3) -> void:
	for i: int in ROCK_COUNT:
		var rock: MeshInstance3D = _rocks[i]
		var angle: float = (TAU / float(ROCK_COUNT)) * float(i) + randf_range(-0.2, 0.2)
		var dist: float = randf_range(1.4, 3.6)
		var end_pos := Vector3(center.x + cos(angle) * dist, 0.15, center.z + sin(angle) * dist)
		rock.global_position = Vector3(center.x, 0.2, center.z)
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		rock.visible = true

		var peak_y: float = randf_range(1.2, 2.5)
		var dur: float = randf_range(0.45, 0.75)
		var r_tw: Tween = create_tween().set_parallel(true)
		r_tw.tween_property(rock, "global_position:x", end_pos.x, dur)
		r_tw.tween_property(rock, "global_position:z", end_pos.z, dur)
		r_tw.tween_property(rock, "rotation", rock.rotation + Vector3(4.0, 3.0, 2.0), dur)
		var y_tw: Tween = create_tween()
		y_tw.tween_property(rock, "global_position:y", peak_y, dur * 0.45).set_ease(Tween.EASE_OUT)
		y_tw.tween_property(rock, "global_position:y", 0.15, dur * 0.55).set_ease(Tween.EASE_IN)


func _shake_first_person_cam(duration: float, intensity: float) -> void:
	if _player_camera == null:
		return
	var base_pos: Vector3 = _player_camera.position
	var steps: int = 5
	var step_time: float = duration / float(steps)
	for i: int in steps:
		_player_camera.position = (
			base_pos
			+ Vector3(randf_range(-intensity, intensity), randf_range(-intensity, intensity), 0.0)
		)
		await get_tree().create_timer(step_time).timeout
	_player_camera.position = base_pos


func _set_gameplay_active(active: bool) -> void:
	var mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_world.process_mode = mode
	var em: Node = get_parent().get_node_or_null("EnemyManager")
	if em != null:
		em.process_mode = mode


func _build_fx_once() -> void:
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.albedo_color = Color(1.8, 1.6, 0.9, 1.0)
	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.85
	halo_mesh.outer_radius = 1.05
	_light_halo = MeshInstance3D.new()
	_light_halo.mesh = halo_mesh
	_light_halo.material_override = halo_mat
	add_child(_light_halo)

	_streak_ring = Node3D.new()
	add_child(_streak_ring)
	var streak_mat := StandardMaterial3D.new()
	streak_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	streak_mat.albedo_color = Color(2.0, 1.85, 1.15, 1.0)
	var streak_mesh := BoxMesh.new()
	streak_mesh.size = Vector3(0.035, 1.35, 0.035)
	for i: int in STREAK_COUNT:
		var streak := MeshInstance3D.new()
		streak.mesh = streak_mesh
		streak.material_override = streak_mat
		var angle: float = (TAU / float(STREAK_COUNT)) * float(i)
		var radius: float = 1.45 + float(i % 3) * 0.35
		streak.position = Vector3(cos(angle) * radius, randf_range(-1.5, 2.2), sin(angle) * radius)
		_streak_ring.add_child(streak)
		_streak_speeds.append(randf_range(3.5, 6.5))

	var portal_mat := ShaderMaterial.new()
	portal_mat.shader = WHITE_PORTAL_SHADER
	var portal_mesh := PlaneMesh.new()
	portal_mesh.size = Vector2(12.0, 12.0)
	_white_portal = MeshInstance3D.new()
	_white_portal.mesh = portal_mesh
	_white_portal.material_override = portal_mat
	add_child(_white_portal)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(2.0, 1.75, 0.9, 1.0)

	var outer_mesh := TorusMesh.new()
	outer_mesh.inner_radius = 4.6
	outer_mesh.outer_radius = 4.95
	_portal_ring_outer = MeshInstance3D.new()
	_portal_ring_outer.mesh = outer_mesh
	_portal_ring_outer.material_override = ring_mat
	_white_portal.add_child(_portal_ring_outer)

	var inner_mesh := TorusMesh.new()
	inner_mesh.inner_radius = 3.2
	inner_mesh.outer_radius = 3.45
	_portal_ring_inner = MeshInstance3D.new()
	_portal_ring_inner.mesh = inner_mesh
	_portal_ring_inner.material_override = ring_mat
	_portal_ring_inner.rotation = Vector3(deg_to_rad(14.0), 0.0, deg_to_rad(-10.0))
	_white_portal.add_child(_portal_ring_inner)

	var crater_mat := StandardMaterial3D.new()
	crater_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crater_mat.albedo_color = Color(0.12, 0.08, 0.08, 1.0)
	var crater_mesh := CylinderMesh.new()
	crater_mesh.top_radius = 2.4
	crater_mesh.bottom_radius = 2.7
	crater_mesh.height = 0.04
	_crater = MeshInstance3D.new()
	_crater.mesh = crater_mesh
	_crater.material_override = crater_mat
	add_child(_crater)

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.35, 0.30, 0.28, 1.0)
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(0.28, 0.22, 0.28)
	for i: int in ROCK_COUNT:
		var rock := MeshInstance3D.new()
		rock.mesh = rock_mesh
		rock.material_override = rock_mat
		add_child(rock)
		_rocks.append(rock)

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 20
	add_child(_fade_layer)

	var damage_layer := CanvasLayer.new()
	damage_layer.layer = 5
	add_child(damage_layer)
	_damage_mat = ShaderMaterial.new()
	_damage_mat.shader = DAMAGE_VIGNETTE_SHADER
	_damage_mat.set_shader_parameter("mode", damage_fx_mode)
	_damage_rect = ColorRect.new()
	_damage_rect.material = _damage_mat
	_damage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_layer.add_child(_damage_rect)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)

	_circle_label = Label.new()
	_circle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_circle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_circle_label.offset_top = 18.0
	_circle_label.offset_bottom = 48.0
	_circle_label.add_theme_font_size_override("font_size", 18)
	_circle_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
	_circle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_circle_label.add_theme_constant_override("outline_size", 4)
	_circle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle_label.visible = false
	damage_layer.add_child(_circle_label)


func _prewarm_fx() -> void:
	_light_halo.visible = true
	_streak_ring.visible = true
	_white_portal.visible = true
	_crater.visible = true
	for rock: MeshInstance3D in _rocks:
		rock.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_hide_all_fx()


func _hide_all_fx() -> void:
	_light_halo.visible = false
	_streak_ring.visible = false
	_white_portal.visible = false
	_crater.visible = false
	_hide_rocks()
	_update_process_state()


func _process(delta: float) -> void:
	if _streak_ring != null and _streak_ring.visible and _player != null:
		_streak_ring.global_position = _player.global_position + Vector3(0.0, 0.9, 0.0)
		_streak_ring.rotate_y(delta * 1.8)
		var count: int = _streak_ring.get_child_count()
		for i: int in count:
			var streak := _streak_ring.get_child(i) as Node3D
			if streak == null:
				continue
			streak.position.y += _streak_speeds[i] * delta
			if streak.position.y > 2.6:
				streak.position.y = -1.6

	if _white_portal != null and _white_portal.visible:
		if _portal_ring_outer != null:
			_portal_ring_outer.rotate_y(delta * 1.4)
		if _portal_ring_inner != null:
			_portal_ring_inner.rotate_y(-delta * 2.2)
			_portal_ring_inner.rotate_z(delta * 0.7)

	if not _in_transition and _hp_ratio <= LOW_HP_THRESHOLD and _player_camera != null:
		var severity: float = clampf(1.0 - (_hp_ratio / LOW_HP_THRESHOLD), 0.0, 1.0)
		var beat_period: float = lerpf(0.95, 0.55, severity)
		_heartbeat_timer = fmod(_heartbeat_timer + delta, beat_period)
		var phase: float = _heartbeat_timer / beat_period
		# Doble pulso de corazón ("lub-dub") suave en FOV y viñeta.
		var beat1: float = exp(-pow((phase - 0.12) / 0.055, 2.0))
		var beat2: float = exp(-pow((phase - 0.28) / 0.065, 2.0)) * 0.72
		var pulse_val: float = clampf(beat1 + beat2, 0.0, 1.0)
		_player.set_heartbeat_fov_offset(pulse_val * lerpf(1.2, 3.0, severity))
		_update_damage_shader(_damage_intensity_from_hp(), pulse_val * severity)
	elif _player != null:
		_player.set_heartbeat_fov_offset(0.0)


func _on_round_started(round_number: int, _is_boss: bool) -> void:
	_apply_circle_fog(round_number, false)


func _apply_circle_fog(round_number: int, instant: bool) -> void:
	if _world_env == null or _world_env.environment == null:
		return
	var idx: int = 0
	if round_number >= 101:
		idx = 10
	elif round_number >= 91:
		idx = 9
	else:
		idx = clampi((maxi(round_number, 1) - 1) / 10, 0, 8)
	var target_color: Color = CIRCLE_FOG_COLORS[idx]
	var env: Environment = _world_env.environment
	if instant:
		env.fog_light_color = target_color
		_current_circle_idx = -1
		if _circle_label != null:
			_circle_label.visible = false
	else:
		var fog_tw: Tween = create_tween()
		fog_tw.tween_property(env, "fog_light_color", target_color, 1.5)
		if idx != _current_circle_idx:
			_current_circle_idx = idx
			_show_circle_banner(CIRCLE_NAMES[idx])


func _show_circle_banner(circle_name: String) -> void:
	if _circle_label == null:
		return
	if _circle_tween != null and _circle_tween.is_running():
		_circle_tween.kill()
	_circle_label.text = circle_name
	_circle_label.modulate.a = 0.0
	_circle_label.visible = true
	_circle_tween = create_tween()
	_circle_tween.tween_property(_circle_label, "modulate:a", 1.0, 0.4)
	_circle_tween.tween_interval(2.2)
	_circle_tween.tween_property(_circle_label, "modulate:a", 0.0, 0.8)
	_circle_tween.tween_callback(func() -> void: _circle_label.visible = false)


func _on_player_slam_landed(impact_pos: Vector3) -> void:
	if _in_transition:
		return
	_spawn_rocks(impact_pos)
	await get_tree().create_timer(0.85).timeout
	if not _in_transition:
		_hide_rocks()


func _on_player_health_changed(current: float, maximum: float) -> void:
	_hp_ratio = clampf(current / maxf(maximum, 0.01), 0.0, 1.0)
	_update_damage_shader(_damage_intensity_from_hp(), 0.0)
	_update_process_state()


func _damage_intensity_from_hp() -> float:
	if _hp_ratio >= 0.85:
		return 0.0
	return clampf((0.85 - _hp_ratio) / 0.85, 0.0, 1.0)


func _update_damage_shader(intensity: float, pulse: float) -> void:
	if _damage_mat == null:
		return
	_damage_mat.set_shader_parameter("mode", damage_fx_mode)
	_damage_mat.set_shader_parameter("intensity", intensity)
	_damage_mat.set_shader_parameter("pulse", pulse)


func _update_process_state() -> void:
	var needs_streaks: bool = _streak_ring != null and _streak_ring.visible
	var needs_portal: bool = _white_portal != null and _white_portal.visible
	var needs_heartbeat: bool = not _in_transition and _hp_ratio <= LOW_HP_THRESHOLD
	set_process(needs_streaks or needs_portal or needs_heartbeat)


## Alterna entre Tinte Rojo (0), Manchas de Sangre (1) y Ambos (2) para pruebas.
func cycle_damage_fx_mode() -> int:
	damage_fx_mode = (damage_fx_mode + 1) % 3
	_update_damage_shader(_damage_intensity_from_hp(), 0.0)
	return damage_fx_mode


func get_damage_fx_mode_name() -> String:
	match damage_fx_mode:
		0:
			return "Tinte"
		1:
			return "Sangre"
		_:
			return "Ambos"


func _hide_rocks() -> void:
	for rock: MeshInstance3D in _rocks:
		rock.visible = false


func _find_entry_landing_pos(spawn_pos: Vector3) -> Vector3:
	var world_3d: World3D = _world.get_world_3d()
	if world_3d != null:
		var from := Vector3(spawn_pos.x, maxf(spawn_pos.y + 5.0, 20.0), spawn_pos.z)
		var to := Vector3(spawn_pos.x, -30.0, spawn_pos.z)
		var query := PhysicsRayQueryParameters3D.create(from, to, 2)
		var hit: Dictionary = world_3d.direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			return hit["position"] as Vector3
	return Vector3(spawn_pos.x, 0.0, spawn_pos.z)


func _kill_tween() -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()


## Reproduce la animación de entrada desde el menú de depuración.
func debug_replay_entry() -> void:
	if _player == null:
		return
	Engine.time_scale = 1.0
	_hide_all_fx()
	_fade_rect.color.a = 0.0
	if _round_manager != null:
		_round_manager.reset_to_idle()
	_run_entry_cinematic()


## Reproduce la animación de escape/muerte desde el menú de depuración.
func debug_replay_escape() -> void:
	if _player == null:
		return
	Engine.time_scale = 1.0
	_hide_all_fx()
	_fade_rect.color.a = 0.0
	_run_escape_cinematic()
