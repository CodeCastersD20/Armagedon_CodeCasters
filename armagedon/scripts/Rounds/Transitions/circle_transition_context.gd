class_name CircleTransitionContext
extends RefCounted
## Todo lo que una transición de círculo necesita, resuelto una vez por el director:
## jugador, cámara, arena (plataforma, hueco, suelo), GameFlow y las rondas implicadas.
## También trae los helpers comunes (fundidos, cambio de círculo, mover y bloquear al jugador).

## Radio del hueco central del coliseo (HuecoCentral) y margen para no dejar cosas encima.
const HOLE_RADIUS: float = 5.0
const HOLE_MARGIN: float = 2.0
const ARENA_RADIUS: float = 25.0

var tree: SceneTree
var scene_root: Node
var player: Player
var camera: Camera3D
var game_flow: Node
var round_manager: RoundManager
var platform: AnimatableBody3D
var floor_shape: CSGShape3D
var boss_death_position: Vector3 = Vector3.ZERO
## Ronda del jefe vencido y primera ronda del círculo siguiente.
var boss_round: int = 0
var next_circle_round: int = 1
var platform_rest_position: Vector3 = Vector3.ZERO
var _swapped: bool = false


func setup(p_tree: SceneTree, boss_position: Vector3) -> bool:
	tree = p_tree
	scene_root = tree.current_scene
	player = tree.get_first_node_in_group("player") as Player
	game_flow = tree.get_first_node_in_group("game_flow")
	round_manager = tree.get_first_node_in_group("round_manager") as RoundManager
	if scene_root == null or player == null or round_manager == null:
		push_error("CircleTransitionContext: falta escena, jugador o RoundManager")
		return false
	camera = player.get_node_or_null("Head/Camera3D") as Camera3D
	platform = scene_root.find_child("PlataformaMercader", true, false) as AnimatableBody3D
	floor_shape = scene_root.find_child("SueloArena", true, false) as CSGShape3D
	if platform != null:
		platform_rest_position = platform.global_position
	boss_death_position = boss_position
	boss_round = maxi(round_manager.get_current_round(), 1)
	# Primera ronda del círculo siguiente (tras la 10 → 11, tras la 3 en debug → 11).
	next_circle_round = (floori(float(boss_round - 1) / 10.0) + 1) * 10 + 1
	return true


## Cambia niebla, luna, cielo y tinte de la arena al círculo siguiente (solo una vez).
func swap_circle(show_banner: bool = false) -> void:
	if game_flow == null:
		return
	if not _swapped:
		_swapped = true
		game_flow.call("apply_circle_for_round", next_circle_round, false)
	if show_banner:
		show_banner_now()


func show_banner_now() -> void:
	if game_flow != null:
		var idx: int = game_flow.call("circle_index_for_round", next_circle_round)
		game_flow.call("show_circle_banner_for_index", idx)


func next_circle_name() -> String:
	if game_flow == null:
		return ""
	var idx: int = game_flow.call("circle_index_for_round", next_circle_round)
	return game_flow.call("get_circle_name", idx)


func next_circle_fog_color() -> Color:
	if game_flow == null:
		return Color(0.3, 0.3, 0.3)
	var idx: int = game_flow.call("circle_index_for_round", next_circle_round)
	return game_flow.call("get_circle_fog_color", idx)


## Fundido de pantalla; esperar con `await ctx.fade(...)`.
func fade(color: Color, target_alpha: float, seconds: float) -> void:
	if game_flow == null:
		await tree.create_timer(seconds).timeout
		return
	var tw: Tween = game_flow.call("fade_screen", color, target_alpha, seconds)
	if tw != null:
		await tw.finished


## Punto del suelo dentro de la arena y fuera del hueco central.
func safe_floor_point(point: Vector3) -> Vector3:
	var flat := Vector2(point.x, point.z)
	var dist: float = flat.length()
	var min_dist: float = HOLE_RADIUS + HOLE_MARGIN
	var max_dist: float = ARENA_RADIUS - 3.0
	if dist < 0.01:
		flat = Vector2(min_dist, 0.0)
	elif dist < min_dist:
		flat = flat / dist * min_dist
	elif dist > max_dist:
		flat = flat / dist * max_dist
	return Vector3(flat.x, 0.0, flat.y)


func lock_movement(locked: bool) -> void:
	player.set_movement_locked(locked)
	player.set_fall_respawn_suspended(locked)


## Sin reaparecer al caer (escenas de bolsillo y bajadas), pero moviéndose libre.
func suspend_fall_respawn(suspended: bool) -> void:
	player.set_fall_respawn_suspended(suspended)


## Oculta HUD, arma y escudo (cinemáticas) o los devuelve.
func set_cinematic_view(hidden: bool) -> void:
	if game_flow != null:
		game_flow.call("set_cinematic_view", hidden)


## Caminar libre pero sin saltar ni esquivar (y sin reaparecer al caer).
func lock_jump(locked: bool) -> void:
	player.set_jump_locked(locked)
	player.set_fall_respawn_suspended(locked)


## Bloqueo total (cinemática): sin mover ni mirar.
func lock_all(locked: bool) -> void:
	player.set_cinematic_mode(locked)
	player.set_fall_respawn_suspended(locked)


func teleport_player(position: Vector3, yaw: float = NAN) -> void:
	player.global_position = position
	player.velocity = Vector3.ZERO
	if not is_nan(yaw):
		player.rotation.y = yaw


## Deja al jugador libre y la plataforma en su sitio (fin o cancelación).
func restore_player() -> void:
	player.set_movement_locked(false)
	player.set_jump_locked(false)
	player.set_fall_respawn_suspended(false)
	player.set_cinematic_mode(false)
	set_cinematic_view(false)
	if platform != null:
		platform.global_position = platform_rest_position
