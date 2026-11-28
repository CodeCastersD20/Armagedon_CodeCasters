class_name DebugLogger
extends RefCounted
## Logger de depuración a archivo (solo builds de desarrollo, gitignorado en `armagedon/logs/`).
## Permite inspeccionar coordenadas de spawn y posiciones en tiempo real sin usar `print()`.

const LOG_DIR: String = "res://logs"
const LOG_FILE: String = "res://logs/debug.log"

static var _initialized: bool = false
static var _abs_path: String = ""
static var _engine_logger: Logger
static var _writing: bool = false


class _EngineLogBridge:
	extends Logger

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		script_backtraces: Array[ScriptBacktrace],
	) -> void:
		var kind: String = "ERROR"
		match error_type:
			ERROR_TYPE_WARNING:
				kind = "WARNING"
			ERROR_TYPE_SCRIPT:
				kind = "SCRIPT_ERROR"
			ERROR_TYPE_SHADER:
				kind = "SHADER_ERROR"
		var detail: String = rationale if not rationale.is_empty() else code
		DebugLogger.write(kind, "%s (%s:%d en %s)" % [detail, file, line, function])
		for bt in script_backtraces:
			var formatted: String = bt.format(2)
			if not formatted.is_empty():
				DebugLogger.write(kind + "_TRACE", formatted.strip_edges())

	func _log_message(message: String, is_error: bool) -> void:
		var clean: String = message.strip_edges()
		if clean.is_empty():
			return
		DebugLogger.write("STDERR" if is_error else "STDOUT", clean)


static func start_session() -> void:
	if not OS.is_debug_build():
		return
	var dir_abs: String = ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(dir_abs)
	_abs_path = ProjectSettings.globalize_path(LOG_FILE)
	var file: FileAccess = FileAccess.open(_abs_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_line("=== Armagedon Debug Log | %s ===" % Time.get_datetime_string_from_system())
	file.close()
	_initialized = true
	if _engine_logger == null:
		_engine_logger = _EngineLogBridge.new()
		OS.add_logger(_engine_logger)


static func stop_session() -> void:
	if _engine_logger != null:
		OS.remove_logger(_engine_logger)
		_engine_logger = null


static func write(tag: String, message: String) -> void:
	if not OS.is_debug_build() or _writing:
		return
	_writing = true
	if not _initialized:
		start_session()
	if _abs_path != "":
		var file: FileAccess = FileAccess.open(_abs_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
			var secs: float = float(Time.get_ticks_msec()) / 1000.0
			file.store_line("[%.3fs] [%s] %s" % [secs, tag, message])
			file.close()
	_writing = false


static func log_spawn(source: String, enemy: Node, pos: Vector3, round_number: int) -> void:
	if not OS.is_debug_build() or enemy == null:
		return
	var dist_center: float = Vector2(pos.x, pos.z).length()
	var total: int = (
		enemy.get_tree().get_nodes_in_group("enemies").size() if enemy.is_inside_tree() else -1
	)
	write(
		"SPAWN",
		(
			"%s | %s | ronda=%d | pos=(%.2f, %.2f, %.2f) | dist_centro=%.2f | en_grupo=%d"
			% [source, enemy.name, round_number, pos.x, pos.y, pos.z, dist_center, total]
		)
	)


static func log_enemy_snapshot(tree: SceneTree) -> void:
	if not OS.is_debug_build() or tree == null:
		return
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	if enemies.is_empty():
		return
	var player := tree.get_first_node_in_group("player") as Node3D
	var p_pos: Vector3 = player.global_position if player != null else Vector3.ZERO
	# Hacia dónde mira y se mueve el jugador: sirve para ver si un enemigo sigue la mira.
	var p_look: Vector3 = -player.global_basis.z if player != null else Vector3.ZERO
	var p_body := player as CharacterBody3D
	var p_vel: Vector3 = p_body.velocity if p_body != null else Vector3.ZERO
	write(
		"SNAPSHOT",
		(
			"player=(%.2f, %.2f, %.2f) look=(%.2f,%.2f) vel=(%.2f,%.2f) | enemigos=%d"
			% [p_pos.x, p_pos.y, p_pos.z, p_look.x, p_look.z, p_vel.x, p_vel.z, enemies.size()]
		)
	)
	for node in enemies:
		if not is_instance_valid(node) or not (node is Node3D):
			continue
		var e3d := node as Node3D
		var pos: Vector3 = e3d.global_position
		var dist_p: float = pos.distance_to(p_pos) if player != null else -1.0
		var dead: bool = node.call("is_dead") if node.has_method("is_dead") else false
		write(
			"ENEMY",
			(
				"%s | pos=(%.2f, %.2f, %.2f) | dist_player=%.2f | vis=%s | dead=%s"
				% [node.name, pos.x, pos.y, pos.z, dist_p, str(e3d.visible), str(dead)]
			)
		)


static func log_enemy_move(
	enemy: CharacterBody3D,
	move_dir: Vector3,
	nav_next: Vector3,
	nav_finished: bool,
	dist_player: float,
	behavior_info: String = "",
) -> void:
	if not OS.is_debug_build() or enemy == null:
		return
	var pos: Vector3 = enemy.global_position
	var vel: Vector3 = enemy.velocity
	var on_wall: bool = enemy.is_on_wall()
	var wall_info: String = ""
	if on_wall:
		var wn: Vector3 = enemy.get_wall_normal()
		var col_name: String = ""
		if enemy.get_slide_collision_count() > 0:
			var col := enemy.get_slide_collision(0).get_collider()
			if col != null:
				col_name = col.name
		wall_info = " | WALL=(%.2f,%.2f,%.2f) col=%s" % [wn.x, wn.y, wn.z, col_name]
	write(
		"MOVE",
		(
			(
				"%s | ai=%s | pos=(%.2f,%.2f,%.2f) vel=(%.2f,%.2f,%.2f) dir=(%.2f,%.2f)"
				+ " nav=(%.2f,%.2f fin=%s) dist_p=%.2f floor=%s%s"
			)
			% [
				enemy.name,
				behavior_info if behavior_info != "" else "-",
				pos.x,
				pos.y,
				pos.z,
				vel.x,
				vel.y,
				vel.z,
				move_dir.x,
				move_dir.z,
				nav_next.x,
				nav_next.z,
				str(nav_finished),
				dist_player,
				str(enemy.is_on_floor()),
				wall_info,
			]
		)
	)
