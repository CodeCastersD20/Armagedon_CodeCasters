extends Node
## Menú de depuración aislado (solo builds de desarrollo).
## Se abre/cierra con F1 y se maneja con el mouse sin ensuciar scripts de gameplay.

const TIME_SCALES: Array[float] = [0.5, 1.0, 2.0, 3.0]
const TEST_DAMAGE: float = 20.0
const FULL_HEAL: float = 9999.0
const DEBUG_SHARDS: int = 1000
const SPAWN_DISTANCE: float = 6.0
const SPAWN_SPACING: float = 1.6
const SQUELETOR_SCENE: PackedScene = preload("res://scenes/Enemies/Squeletor.tscn")

var _layer: CanvasLayer
var _panel: PanelContainer
var _badge: Label
var _status_label: Label
var _god_toggle: CheckButton
var _next_round_btn: Button
var _add_shards_btn: Button
var _replay_entry_btn: Button
var _replay_escape_btn: Button
var _time_buttons: Dictionary = {}

var _is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _previous_paused: bool = false
var _player: Player


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_ui()


func _exit_tree() -> void:
	if _is_open:
		get_tree().paused = _previous_paused
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F1:
			_toggle_menu()
			get_viewport().set_input_as_handled()


func _toggle_menu() -> void:
	_is_open = not _is_open
	if _is_open:
		_previous_mouse_mode = Input.mouse_mode
		_previous_paused = get_tree().paused
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_resolve_player()
		_refresh_ui()
	else:
		get_tree().paused = _previous_paused
		_resolve_player()
		if _player != null and _player.is_physics_processing():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = _previous_mouse_mode
	_panel.visible = _is_open
	_update_badge()


func _resolve_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_badge = Label.new()
	_badge.position = Vector2(12.0, 12.0)
	_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_badge.add_theme_color_override("font_outline_color", Color.BLACK)
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.visible = false
	_layer.add_child(_badge)

	var compact_theme := Theme.new()
	compact_theme.default_font_size = 11

	_panel = PanelContainer.new()
	_panel.position = Vector2(8.0, 8.0)
	_panel.custom_minimum_size = Vector2(250.0, 0.0)
	_panel.theme = compact_theme
	_panel.visible = false
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "DEBUG MENU (F1)"
	vbox.add_child(title)

	_status_label = Label.new()
	vbox.add_child(_status_label)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 3)
	vbox.add_child(time_row)
	for scale_val in TIME_SCALES:
		var btn := Button.new()
		btn.text = "x%s" % str(scale_val)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_time_scale_pressed.bind(scale_val))
		time_row.add_child(btn)
		_time_buttons[scale_val] = btn

	_god_toggle = CheckButton.new()
	_god_toggle.text = "Modo Dios"
	_god_toggle.toggled.connect(_on_god_mode_toggled)
	vbox.add_child(_god_toggle)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 3)
	vbox.add_child(hp_row)
	var dmg_btn := _add_action_button(hp_row, "-20 HP", _on_damage_pressed)
	dmg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heal_btn := _add_action_button(hp_row, "Curar 100%", _on_heal_pressed)
	heal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spawn_row := HBoxContainer.new()
	spawn_row.add_theme_constant_override("separation", 3)
	vbox.add_child(spawn_row)
	var spawn_one := _add_action_button(spawn_row, "Spawn +1", _on_spawn_enemies_pressed.bind(1))
	spawn_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spawn_five := _add_action_button(spawn_row, "x5", _on_spawn_enemies_pressed.bind(5))
	spawn_five.custom_minimum_size = Vector2(36.0, 0.0)
	var kill_btn := _add_action_button(spawn_row, "Matar todos", _on_kill_all_pressed)
	kill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var flow_row := HBoxContainer.new()
	flow_row.add_theme_constant_override("separation", 3)
	vbox.add_child(flow_row)
	_replay_entry_btn = _add_action_button(flow_row, "Anim. Entrada", _on_replay_entry_pressed)
	_replay_entry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay_escape_btn = _add_action_button(flow_row, "Anim. Escape", _on_replay_escape_pressed)
	_replay_escape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var game_row := HBoxContainer.new()
	game_row.add_theme_constant_override("separation", 3)
	vbox.add_child(game_row)
	_next_round_btn = _add_action_button(game_row, "Ronda +1", _on_next_round_pressed)
	_next_round_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_shards_btn = _add_action_button(game_row, "+1000 Esq.", _on_add_shards_pressed)
	_add_shards_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_add_action_button(vbox, "Cerrar (F1)", _toggle_menu)


func _add_action_button(parent: Control, label_text: String, handler: Callable) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.pressed.connect(handler)
	parent.add_child(btn)
	return btn


func _refresh_ui() -> void:
	_resolve_player()
	var god_on: bool = _player != null and _player.is_god_mode()
	_god_toggle.set_pressed_no_signal(god_on)
	_god_toggle.disabled = _player == null

	for scale_val in TIME_SCALES:
		var btn: Button = _time_buttons[scale_val]
		var active: bool = is_equal_approx(Engine.time_scale, scale_val)
		btn.disabled = active

	var round_mgr: Node = get_tree().get_first_node_in_group("round_manager")
	_next_round_btn.disabled = round_mgr == null
	if round_mgr != null:
		_next_round_btn.text = "Pasar de ronda"

	var economy: Node = get_tree().get_first_node_in_group("economy")
	_add_shards_btn.disabled = economy == null
	if economy != null:
		_add_shards_btn.text = "+%d Esq." % DEBUG_SHARDS

	var game_flow: Node = get_tree().get_first_node_in_group("game_flow")
	_replay_entry_btn.disabled = game_flow == null
	_replay_escape_btn.disabled = game_flow == null

	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	_status_label.text = (
		"Tiempo: x%s | Dios: %s | Enemigos: %d"
		% [str(Engine.time_scale), "ON" if god_on else "OFF", enemy_count]
	)
	_update_badge()


func _update_badge() -> void:
	if _is_open:
		_badge.visible = false
		return
	var parts: Array[String] = []
	if not is_equal_approx(Engine.time_scale, 1.0):
		parts.append("TIME x%s" % str(Engine.time_scale))
	if _player != null and is_instance_valid(_player) and _player.is_god_mode():
		parts.append("GOD")
	_badge.visible = not parts.is_empty()
	if _badge.visible:
		_badge.text = "[DEBUG] %s (F1)" % " | ".join(parts)


func _on_time_scale_pressed(scale_val: float) -> void:
	Engine.time_scale = scale_val
	_refresh_ui()


func _on_god_mode_toggled(enabled: bool) -> void:
	_resolve_player()
	if _player != null:
		_player.set_god_mode(enabled)
	_refresh_ui()


func _on_damage_pressed() -> void:
	_resolve_player()
	if _player == null:
		return
	var was_god: bool = _player.is_god_mode()
	if was_god:
		_player.set_god_mode(false)
	_player.take_damage(TEST_DAMAGE)
	if was_god:
		_player.set_god_mode(true)


func _on_heal_pressed() -> void:
	_resolve_player()
	if _player != null:
		_player.heal(FULL_HEAL)


func _on_replay_entry_pressed() -> void:
	var game_flow := get_tree().get_first_node_in_group("game_flow") as GameFlow
	if game_flow == null:
		return
	if _is_open:
		_toggle_menu()
	game_flow.debug_replay_entry()


func _on_replay_escape_pressed() -> void:
	var game_flow := get_tree().get_first_node_in_group("game_flow") as GameFlow
	if game_flow == null:
		return
	if _is_open:
		_toggle_menu()
	game_flow.debug_replay_escape()


func _on_spawn_enemies_pressed(count: int) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	_resolve_player()
	var origin: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD
	var right: Vector3 = Vector3.RIGHT
	if _player != null:
		origin = _player.global_position
		forward = -_player.global_basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length_squared() > 0.001 else Vector3.FORWARD
		right = _player.global_basis.x
		right.y = 0.0
		right = right.normalized() if right.length_squared() > 0.001 else Vector3.RIGHT
	var occupied: Array[Vector3] = []
	if _player != null:
		occupied.append(_player.global_position)
	for existing in get_tree().get_nodes_in_group("enemies"):
		if existing is Node3D:
			occupied.append((existing as Node3D).global_position)

	var half: float = float(count - 1) * 0.5
	for i in count:
		var enemy := SQUELETOR_SCENE.instantiate() as Enemy
		if enemy == null:
			push_error("DebugControls: no se pudo instanciar Squeletor.tscn")
			return
		var lateral: float = (float(i) - half) * SPAWN_SPACING
		var desired: Vector3 = origin + forward * SPAWN_DISTANCE + right * lateral
		var spawn_pos: Vector3 = _find_free_spawn_position(desired, occupied)
		occupied.append(spawn_pos)
		scene_root.add_child(enemy)
		enemy.global_position = spawn_pos
	_refresh_ui()


func _find_free_spawn_position(desired: Vector3, occupied: Array[Vector3]) -> Vector3:
	var min_sq: float = SPAWN_SPACING * SPAWN_SPACING
	if _is_spawn_clear(desired, occupied, min_sq):
		return desired
	for ring in range(1, 8):
		var radius: float = SPAWN_SPACING * float(ring)
		for slot in range(8):
			var angle: float = TAU * float(slot) / 8.0
			var candidate: Vector3 = (
				desired + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			)
			if _is_spawn_clear(candidate, occupied, min_sq):
				return candidate
	return desired


func _is_spawn_clear(pos: Vector3, occupied: Array[Vector3], min_sq: float) -> bool:
	for other in occupied:
		var diff: Vector3 = pos - other
		diff.y = 0.0
		if diff.length_squared() < min_sq:
			return false
	return true


func _on_kill_all_pressed() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead():
			enemy.take_damage(enemy.get_health() + 1.0)
	_refresh_ui()


func _on_next_round_pressed() -> void:
	var round_mgr: Node = get_tree().get_first_node_in_group("round_manager")
	if round_mgr != null and round_mgr.has_method("debug_next_round"):
		round_mgr.call("debug_next_round")


func _on_add_shards_pressed() -> void:
	var economy: Node = get_tree().get_first_node_in_group("economy")
	if economy != null and economy.has_method("add_shards"):
		economy.call("add_shards", DEBUG_SHARDS)
