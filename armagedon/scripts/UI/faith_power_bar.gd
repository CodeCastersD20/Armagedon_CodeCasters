class_name FaithPowerBar
extends Control
## Indicador compacto de los slots 1-4 de Poderes de Fe en el HUD (#80).

const SLOT_COUNT: int = 4

const COLOR_BG_EMPTY := Color(0.06, 0.04, 0.05, 0.62)
const COLOR_BG_READY := Color(0.08, 0.06, 0.12, 0.86)
const COLOR_BG_ACTIVE := Color(0.18, 0.12, 0.04, 0.92)
const COLOR_BORDER_EMPTY := Color(0.28, 0.22, 0.24, 0.70)
const COLOR_BORDER_READY := Color(0.32, 0.64, 0.96, 0.95)
const COLOR_BORDER_COOLDOWN := Color(0.55, 0.34, 0.18, 0.90)
const COLOR_BORDER_ACTIVE := Color(0.96, 0.76, 0.28, 1.0)
const COLOR_TEXT_KEY := Color(0.95, 0.82, 0.45, 1.0)
const COLOR_TEXT_NAME := Color(0.94, 0.92, 0.90, 1.0)
const COLOR_TEXT_MUTED := Color(0.54, 0.50, 0.52, 1.0)
const COLOR_TEXT_COST_OK := Color(0.45, 0.82, 1.0, 1.0)
const COLOR_TEXT_COST_LOW := Color(0.85, 0.32, 0.32, 1.0)
const COLOR_TEXT_COOLDOWN := Color(0.95, 0.62, 0.26, 1.0)
const COLOR_TEXT_ACTIVE := Color(0.48, 0.95, 0.55, 1.0)

var _manager: FaithPowerManager
var _player: Player
var _current_faith: float = 0.0
var _slot_states: Array[Dictionary] = []
var _slot_widgets: Array[Dictionary] = []

var _style_empty: StyleBoxFlat
var _style_ready: StyleBoxFlat
var _style_cooldown: StyleBoxFlat
var _style_active: StyleBoxFlat

@onready var _slots_container: HBoxContainer = $SlotsContainer


func _ready() -> void:
	_init_styles()
	_build_slot_cards()
	_connect_sources.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_manager):
		if _manager.slots_updated.is_connected(_on_slots_updated):
			_manager.slots_updated.disconnect(_on_slots_updated)
		if _manager.cooldown_updated.is_connected(_on_cooldown_updated):
			_manager.cooldown_updated.disconnect(_on_cooldown_updated)
	if is_instance_valid(_player) and _player.faith_changed.is_connected(_on_faith_changed):
		_player.faith_changed.disconnect(_on_faith_changed)


func _init_styles() -> void:
	_style_empty = _make_panel_style(COLOR_BG_EMPTY, COLOR_BORDER_EMPTY)
	_style_ready = _make_panel_style(COLOR_BG_READY, COLOR_BORDER_READY)
	_style_cooldown = _make_panel_style(COLOR_BG_EMPTY, COLOR_BORDER_COOLDOWN)
	_style_active = _make_panel_style(COLOR_BG_ACTIVE, COLOR_BORDER_ACTIVE)


func _make_panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box


func _build_slot_cards() -> void:
	_slot_states.clear()
	_slot_widgets.clear()
	for i: int in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(78.0, 36.0)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _style_empty)
		_slots_container.add_child(panel)

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 0)
		panel.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_row.add_theme_constant_override("separation", 2)
		vbox.add_child(top_row)

		var key_label := Label.new()
		key_label.text = "[%d]" % (i + 1)
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.add_theme_font_size_override("font_size", 8)
		key_label.add_theme_color_override("font_color", COLOR_TEXT_KEY)
		top_row.add_child(key_label)

		var level_label := Label.new()
		level_label.text = ""
		level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.add_theme_font_size_override("font_size", 8)
		level_label.add_theme_color_override("font_color", COLOR_TEXT_KEY)
		top_row.add_child(level_label)

		var name_label := Label.new()
		name_label.text = "---"
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(name_label)

		var status_label := Label.new()
		status_label.text = "Vacío"
		status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		status_label.add_theme_font_size_override("font_size", 8)
		status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		vbox.add_child(status_label)

		_slot_states.append(
			{
				"slot_index": i,
				"power": null,
				"level": 0,
				"cooldown": 0.0,
				"cooldown_max": 0.0,
				"active_remaining": 0.0,
			}
		)
		_slot_widgets.append(
			{
				"panel": panel,
				"level_label": level_label,
				"name_label": name_label,
				"status_label": status_label,
			}
		)


func _connect_sources() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null:
		if not _player.faith_changed.is_connected(_on_faith_changed):
			_player.faith_changed.connect(_on_faith_changed)
		_current_faith = _player.get_faith()

	_manager = get_tree().get_first_node_in_group("faith_power_manager") as FaithPowerManager
	if _manager != null:
		if not _manager.slots_updated.is_connected(_on_slots_updated):
			_manager.slots_updated.connect(_on_slots_updated)
		if not _manager.cooldown_updated.is_connected(_on_cooldown_updated):
			_manager.cooldown_updated.connect(_on_cooldown_updated)
		_on_slots_updated(_manager.get_slots_snapshot())
	else:
		_refresh_all_slots()


func _on_slots_updated(slots: Array[Dictionary]) -> void:
	for i: int in mini(slots.size(), SLOT_COUNT):
		_slot_states[i] = slots[i].duplicate()
	_refresh_all_slots()


func _on_cooldown_updated(
	slot_index: int, remaining: float, duration: float, active_remaining: float
) -> void:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	var state: Dictionary = _slot_states[slot_index]
	state["cooldown"] = remaining
	state["cooldown_max"] = duration
	state["active_remaining"] = active_remaining
	_refresh_slot(slot_index)


func _on_faith_changed(current: float, _maximum: float) -> void:
	if is_equal_approx(_current_faith, current):
		return
	_current_faith = current
	_refresh_all_slots()


func _refresh_all_slots() -> void:
	for i: int in SLOT_COUNT:
		_refresh_slot(i)


func _refresh_slot(index: int) -> void:
	var state: Dictionary = _slot_states[index]
	var widgets: Dictionary = _slot_widgets[index]
	var panel := widgets["panel"] as PanelContainer
	var level_label := widgets["level_label"] as Label
	var name_label := widgets["name_label"] as Label
	var status_label := widgets["status_label"] as Label

	var power := state.get("power") as FaithPowerData
	var level: int = int(state.get("level", 0))
	var cooldown: float = float(state.get("cooldown", 0.0))
	var active_left: float = float(state.get("active_remaining", 0.0))

	if power == null or level <= 0:
		_set_label_text(level_label, "")
		_set_label_text(name_label, "---")
		_set_label_text(status_label, "Vacío")
		name_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
		panel.add_theme_stylebox_override("panel", _style_empty)
		return

	_set_label_text(level_label, "Nv.%d" % level)
	_set_label_text(name_label, power.nombre)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_NAME)

	if active_left > 0.0:
		_set_label_text(status_label, "ACTIVO %.1fs" % active_left)
		status_label.add_theme_color_override("font_color", COLOR_TEXT_ACTIVE)
		panel.add_theme_stylebox_override("panel", _style_active)
	elif cooldown > 0.0:
		_set_label_text(status_label, "CD %.1fs" % cooldown)
		status_label.add_theme_color_override("font_color", COLOR_TEXT_COOLDOWN)
		panel.add_theme_stylebox_override("panel", _style_cooldown)
	else:
		var cost: int = int(round(power.costo_fe))
		_set_label_text(status_label, "%d Fe" % cost)
		var affordable: bool = _current_faith >= power.costo_fe
		status_label.add_theme_color_override(
			"font_color", COLOR_TEXT_COST_OK if affordable else COLOR_TEXT_COST_LOW
		)
		panel.add_theme_stylebox_override("panel", _style_ready)


func _set_label_text(label: Label, value: String) -> void:
	if label.text != value:
		label.text = value
