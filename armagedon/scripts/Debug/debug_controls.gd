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
const HORDE_CONFIG: HordeConfig = preload("res://data/horde_config.tres")
const BOSS_ENTRIES: Array[Dictionary] = [
	{"label": "Jefe Esqueleto", "scene": preload("res://scenes/Enemies/JefeSqueletor.tscn")},
	{"label": "Jefe Demonio", "scene": preload("res://scenes/Enemies/JefeDemonio.tscn")},
	{"label": "Jefe Wrapped", "scene": preload("res://scenes/Enemies/JefeWrapped.tscn")},
]
## Armas para los dos huecos (cualquier tipo en cualquier hueco; solo una equipada).
const SLOT_WEAPONS: Array[Dictionary] = [
	{"label": "Espada+Escudo", "data": preload("res://data/weapons/sword.tres")},
	{"label": "Pistola", "data": preload("res://data/weapons/pistol.tres")},
	{"label": "Escopeta", "data": preload("res://data/weapons/shotgun.tres")},
	{"label": "Rifle FX-05", "data": preload("res://data/weapons/rifle_fx05.tres")},
]
const PICKUP_VISUALS: Array[Dictionary] = [
	{"label": "Drops Clásicos", "visual": DropConfig.PickupVisual.CLASSIC},
	{"label": "Drops 3D", "visual": DropConfig.PickupVisual.MODEL_3D},
	{"label": "Drops 2D", "visual": DropConfig.PickupVisual.SPRITE_2D},
]
const SUMMON_COLUMNS: int = 2
const PANEL_WIDTH: float = 560.0
const PANEL_SCREEN_MARGIN: float = 16.0
const SNAPSHOT_INTERVAL: float = 2.0

var _layer: CanvasLayer
var _panel: PanelContainer
var _scroll: ScrollContainer
var _badge: Label
var _status_label: Label
var _god_toggle: CheckButton
var _next_round_btn: Button
var _add_shards_btn: Button
var _replay_entry_btn: Button
var _replay_escape_btn: Button
var _time_buttons: Dictionary = {}
var _champion_toggle: CheckButton
var _pickup_buttons: Array[Button] = []
var _transition_buttons: Array[Button] = []
var _transition_status: Label
## Por hueco: un botón por cada arma de SLOT_WEAPONS.
var _weapon_buttons: Array[Array] = []

var _is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _previous_paused: bool = false
var _player: Player
var _snapshot_timer: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	DebugLogger.start_session()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_refresh_ui()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_snapshot_timer += delta
	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer = 0.0
		DebugLogger.log_enemy_snapshot(get_tree())


func _exit_tree() -> void:
	DebugLogger.stop_session()
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
	if _is_open:
		_fit_panel.call_deferred()
	_update_badge()


## Limita la altura del panel a la pantalla; si el contenido no cabe, aparece la barra de scroll.
func _fit_panel() -> void:
	if _scroll == null or _scroll.get_child_count() == 0:
		return
	var content: Control = _scroll.get_child(0) as Control
	var max_height: float = get_viewport().get_visible_rect().size.y - PANEL_SCREEN_MARGIN * 2.0
	_scroll.custom_minimum_size = Vector2(
		PANEL_WIDTH, minf(content.get_combined_minimum_size().y, max_height)
	)


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
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.theme = compact_theme
	_panel.visible = false
	_layer.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(margin)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	margin.add_child(columns)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(vbox)

	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 3)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_box)

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
	for batch in [5, 10]:
		var spawn_batch := _add_action_button(
			spawn_row, "x%d" % batch, _on_spawn_random_pressed.bind(batch)
		)
		spawn_batch.custom_minimum_size = Vector2(36.0, 0.0)
		spawn_batch.tooltip_text = "Tanda aleatoria de enemigos normales y variantes (sin jefes)"
	var kill_btn := _add_action_button(spawn_row, "Matar todos", _on_kill_all_pressed)
	kill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_build_summon_section(right_box)

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

	_build_weapon_section(vbox)
	_build_transition_section(vbox)
	_build_pickup_section(vbox)

	_add_action_button(vbox, "Cerrar (F1)", _toggle_menu)


## Sección "Invocar": un botón por enemigo (normales, variantes y jefes) + interruptor de Campeón.
## Los tipos y variantes salen de `HORDE_CONFIG`, así no se duplica la lista.
func _build_summon_section(vbox: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Invocar enemigo"
	vbox.add_child(header)

	_champion_toggle = CheckButton.new()
	_champion_toggle.text = "Como Campeón"
	_champion_toggle.disabled = HORDE_CONFIG.champion == null
	vbox.add_child(_champion_toggle)

	var grid := GridContainer.new()
	grid.columns = SUMMON_COLUMNS
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(grid)
	for entry in HORDE_CONFIG.entries:
		if entry == null or entry.scene == null:
			continue
		var base_name: String = _scene_label(entry.scene)
		_add_summon_button(grid, base_name, entry.scene, null)
		for variant in entry.variants:
			if variant != null and variant.data != null:
				_add_summon_button(grid, variant.data.display_name, entry.scene, variant.data)
	for boss in BOSS_ENTRIES:
		_add_summon_button(grid, boss["label"], boss["scene"], null)


func _scene_label(scene: PackedScene) -> String:
	var state: SceneState = scene.get_state()
	return String(state.get_node_name(0)) if state.get_node_count() > 0 else "Enemigo"


func _add_summon_button(
	parent: Control, label_text: String, scene: PackedScene, data: EnemyData
) -> void:
	var btn := _add_action_button(parent, label_text, _on_summon_pressed.bind(scene, data))
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_text = true
	btn.tooltip_text = label_text


func _on_summon_pressed(scene: PackedScene, data: EnemyData) -> void:
	_spawn_enemies(scene, data, 1)


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

	var weapon_manager := _find_weapon_manager()
	for slot in range(_weapon_buttons.size()):
		var slot_data: WeaponData = (
			weapon_manager.get_slot_data(slot) if weapon_manager != null else null
		)
		var row: Array = _weapon_buttons[slot]
		for i in range(row.size()):
			(row[i] as Button).disabled = (
				weapon_manager == null or SLOT_WEAPONS[i]["data"] == slot_data
			)

	_refresh_transition_section()

	var pickup_visual: DropConfig.PickupVisual = DropManager.get_visual(get_tree())
	for i in range(_pickup_buttons.size()):
		_pickup_buttons[i].disabled = PICKUP_VISUALS[i]["visual"] == pickup_visual

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
	_spawn_enemies(SQUELETOR_SCENE, null, count)


## Tanda aleatoria: cada enemigo se sortea entre todos los tipos y variantes de `HORDE_CONFIG`
## (los jefes no están ahí).
func _on_spawn_random_pressed(count: int) -> void:
	var pool: Array[Array] = []
	for entry in HORDE_CONFIG.entries:
		if entry == null or entry.scene == null:
			continue
		pool.append([entry.scene, null])
		for variant in entry.variants:
			if variant != null and variant.data != null:
				pool.append([entry.scene, variant.data])
	if pool.is_empty():
		return
	var picks: Array[Array] = []
	for _i in count:
		picks.append(pool.pick_random())
	_spawn_enemy_list(picks)


## Instancia `count` enemigos delante del jugador. `data` (opcional) sustituye el EnemyData de la
## escena (variantes); el interruptor "Como Campeón" les asigna `champion_data`.
func _spawn_enemies(scene: PackedScene, data: EnemyData, count: int) -> void:
	var picks: Array[Array] = []
	for _i in count:
		picks.append([scene, data])
	_spawn_enemy_list(picks)


## Instancia cada `[escena, EnemyData o null]` de `picks` en fila delante del jugador.
func _spawn_enemy_list(picks: Array[Array]) -> void:
	var count: int = picks.size()
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

	var round_mgr := get_tree().get_first_node_in_group("round_manager") as RoundManager
	var round_number: int = round_mgr.get_current_round() if round_mgr != null else 0
	var half: float = float(count - 1) * 0.5
	for i in count:
		var scene: PackedScene = picks[i][0]
		var data: EnemyData = picks[i][1]
		var enemy := scene.instantiate() as Enemy
		if enemy == null:
			push_error("DebugControls: la escena no es un Enemy")
			return
		if data != null:
			enemy.data = data
		if round_number > 0:
			enemy.start_round = round_number
		if _champion_toggle != null and _champion_toggle.button_pressed:
			enemy.champion_data = HORDE_CONFIG.champion
		var lateral: float = (float(i) - half) * SPAWN_SPACING
		var desired: Vector3 = origin + forward * SPAWN_DISTANCE + right * lateral
		var spawn_pos: Vector3 = _find_free_spawn_position(desired, occupied)
		occupied.append(spawn_pos)
		scene_root.add_child(enemy)
		enemy.set_spawn_position(spawn_pos)
		DebugLogger.log_spawn("DebugControls", enemy, spawn_pos, round_number)
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


func _build_pickup_section(vbox: VBoxContainer) -> void:
	var pickup_row := HBoxContainer.new()
	pickup_row.add_theme_constant_override("separation", 3)
	vbox.add_child(pickup_row)
	for i in range(PICKUP_VISUALS.size()):
		var btn := _add_action_button(
			pickup_row, PICKUP_VISUALS[i]["label"], _on_pickup_visual_pressed.bind(i)
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pickup_buttons.append(btn)


func _on_pickup_visual_pressed(index: int) -> void:
	DropManager.set_visual(get_tree(), PICKUP_VISUALS[index]["visual"])
	_refresh_ui()


## Reemplaza el arma de fuego por otra (la anterior se elimina), como en la tienda del descanso.
## Cambia el arma de cada hueco por cualquier otra (la anterior se elimina), como en la tienda.
func _build_weapon_section(vbox: VBoxContainer) -> void:
	var header := Label.new()
	header.text = "Armas (2 huecos, cualquier tipo)"
	vbox.add_child(header)
	for slot in range(WeaponManager.SLOT_COUNT):
		var weapon_row := HBoxContainer.new()
		weapon_row.add_theme_constant_override("separation", 3)
		vbox.add_child(weapon_row)
		var slot_label := Label.new()
		slot_label.text = "%d:" % (slot + 1)
		weapon_row.add_child(slot_label)
		var row: Array[Button] = []
		for i in range(SLOT_WEAPONS.size()):
			var btn := _add_action_button(
				weapon_row, SLOT_WEAPONS[i]["label"], _on_slot_weapon_pressed.bind(slot, i)
			)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.clip_text = true
			btn.tooltip_text = "Hueco %d: %s" % [slot + 1, SLOT_WEAPONS[i]["label"]]
			row.append(btn)
		_weapon_buttons.append(row)


func _find_weapon_manager() -> WeaponManager:
	return get_tree().get_first_node_in_group("weapon_manager") as WeaponManager


func _on_slot_weapon_pressed(slot: int, index: int) -> void:
	var weapon_manager := _find_weapon_manager()
	if weapon_manager != null:
		weapon_manager.replace_weapon(SLOT_WEAPONS[index]["data"], slot)
	_refresh_ui()


## Transición de círculo (GDD §2.2): elegir opción, probarla ya o matar al jefe vivo.
func _build_transition_section(vbox: VBoxContainer) -> void:
	_transition_status = Label.new()
	_transition_status.text = "Transición de círculo"
	vbox.add_child(_transition_status)
	var director := _find_transition_director()
	var options_row := HFlowContainer.new()
	options_row.add_theme_constant_override("h_separation", 3)
	options_row.add_theme_constant_override("v_separation", 3)
	vbox.add_child(options_row)
	var config: CircleTransitionConfig = (
		director.config if director != null else CircleTransitionDirector.DEFAULT_CONFIG
	)
	for data in config.options:
		if data == null:
			continue
		var btn := _add_action_button(
			options_row, data.display_name, _on_transition_option_pressed.bind(data)
		)
		btn.set_meta("transition_data", data)
		_transition_buttons.append(btn)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 3)
	vbox.add_child(action_row)
	var test_btn := _add_action_button(
		action_row, "Probar transición ahora", _on_transition_test_pressed
	)
	test_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kill_boss_btn := _add_action_button(action_row, "Matar jefe", _on_kill_boss_pressed)
	kill_boss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _refresh_transition_section() -> void:
	var director := _find_transition_director()
	var selected: CircleTransitionData = director.get_selected() if director != null else null
	for btn in _transition_buttons:
		btn.disabled = director == null or btn.get_meta("transition_data") == selected
	if _transition_status != null:
		var state: String = "en curso" if director != null and director.is_active() else "lista"
		_transition_status.text = "Transición de círculo (%s)" % state


func _find_transition_director() -> CircleTransitionDirector:
	return (
		get_tree().get_first_node_in_group("circle_transition_director") as CircleTransitionDirector
	)


func _on_transition_option_pressed(data: CircleTransitionData) -> void:
	var director := _find_transition_director()
	if director != null:
		director.set_selected(data)
	_refresh_ui()


func _on_transition_test_pressed() -> void:
	var director := _find_transition_director()
	if director != null:
		_toggle_menu()
		director.debug_start_now()


func _on_kill_boss_pressed() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.get_parent() is BossSpawner and not enemy.is_dead():
			enemy.take_damage(999999.0, false, true)
	_refresh_ui()
