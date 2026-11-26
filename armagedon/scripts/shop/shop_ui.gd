class_name ShopUI
extends CanvasLayer
## Interfaz de compra del Mercante Anónimo durante el descanso entre rondas (GDD §8, #78).

signal shop_opened
signal shop_closed
signal purchase_completed(item: Resource, new_level: int)

const RANDOM_OFFER_COUNT: int = 4
const DEBUG_SHARDS_AMOUNT: int = 250
const PANEL_WIDTH: float = 596.0
const ALWAYS_CARD_HEIGHT: float = 50.0
const RANDOM_CARD_HEIGHT: float = 62.0

const COLOR_BACKDROP := Color(0.03, 0.01, 0.02, 0.74)
const COLOR_PANEL_BG := Color(0.08, 0.03, 0.04, 0.96)
const COLOR_PANEL_BORDER := Color(0.68, 0.12, 0.16, 1.0)
const COLOR_SEPARATOR := Color(0.55, 0.10, 0.14, 0.85)
const COLOR_TITLE := Color(0.95, 0.78, 0.42, 1.0)
const COLOR_SECTION := Color(0.88, 0.30, 0.32, 1.0)
const COLOR_BALANCE := Color(0.55, 0.85, 1.0, 1.0)
const COLOR_TEXT_PRIMARY := Color(0.95, 0.90, 0.86, 1.0)
const COLOR_TEXT_EFFECT := Color(0.78, 0.70, 0.68, 1.0)
const COLOR_TEXT_MUTED := Color(0.50, 0.44, 0.45, 1.0)
const COLOR_LEVEL := Color(0.92, 0.74, 0.38, 1.0)
const COLOR_PRICE_OK := Color(0.55, 0.85, 1.0, 1.0)
const COLOR_PRICE_LOW := Color(0.78, 0.28, 0.28, 1.0)
const COLOR_PURCHASED := Color(0.45, 0.85, 0.50, 1.0)
const COLOR_MAXED := Color(0.72, 0.58, 0.34, 1.0)
const COLOR_BTN_BG := Color(0.14, 0.05, 0.06, 0.96)
const COLOR_BTN_BORDER := Color(0.42, 0.12, 0.15, 1.0)
const COLOR_BTN_HOVER_BG := Color(0.24, 0.07, 0.09, 0.98)
const COLOR_BTN_HOVER_BORDER := Color(0.86, 0.22, 0.24, 1.0)
const COLOR_BTN_PRESSED_BG := Color(0.32, 0.09, 0.11, 1.0)
const COLOR_BTN_FOCUS_BG := Color(0.22, 0.07, 0.09, 0.98)
const COLOR_BTN_DISABLED_BG := Color(0.09, 0.05, 0.06, 0.78)
const COLOR_BTN_DISABLED_BORDER := Color(0.24, 0.12, 0.14, 0.75)

# TODO(GDD §12): asignar SFX_Upgrade_Buy
@export var sfx_upgrade_buy: AudioStream
# TODO(#81): desactivar al integrar NPC
@export var debug_shortcuts_enabled: bool = true

var _is_open: bool = false
var _purchased_random_ids: Dictionary = {}
var _always_entries: Array[Dictionary] = []
var _random_entries: Array[Dictionary] = []
var _balance_label: Label
var _always_container: HBoxContainer
var _random_grid: GridContainer
var _close_button: Button
var _round_manager: RoundManager
var _style_btn_normal: StyleBoxFlat
var _style_btn_hover: StyleBoxFlat
var _style_btn_pressed: StyleBoxFlat
var _style_btn_focus: StyleBoxFlat
var _style_btn_disabled: StyleBoxFlat


func _ready() -> void:
	add_to_group("shop_ui")
	layer = 10
	visible = false
	_init_styles()
	_build_ui()
	if not CurrencyManager.balance_changed.is_connected(_on_balance_changed):
		CurrencyManager.balance_changed.connect(_on_balance_changed)
	_update_balance_label()
	_connect_round_manager.call_deferred()


func _exit_tree() -> void:
	if CurrencyManager.balance_changed.is_connected(_on_balance_changed):
		CurrencyManager.balance_changed.disconnect(_on_balance_changed)
	if is_instance_valid(_round_manager) and _round_manager.rest_ended.is_connected(on_rest_ended):
		_round_manager.rest_ended.disconnect(on_rest_ended)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		if _is_open and key_event.keycode == KEY_ESCAPE:
			close_shop()
			get_viewport().set_input_as_handled()
			return
		if debug_shortcuts_enabled and OS.is_debug_build():
			if key_event.keycode == KEY_B:
				if _is_open:
					close_shop()
				else:
					open_shop(true)
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_F8 or key_event.keycode == KEY_G:
				CurrencyManager.add(DEBUG_SHARDS_AMOUNT)
				get_viewport().set_input_as_handled()
				return
	if _is_open and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()


func open_shop(roll_new: bool = true) -> void:
	if _is_open:
		return
	var no_offers: bool = (
		ShopManager.current_always_offers.is_empty()
		and ShopManager.current_random_offers.is_empty()
	)
	if roll_new or no_offers:
		ShopManager.roll_offers(RANDOM_OFFER_COUNT)
		_purchased_random_ids.clear()
	_is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_populate_offers()
	_update_balance_label()
	_focus_initial_button.call_deferred()
	shop_opened.emit()


func close_shop() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	shop_closed.emit()


func on_rest_ended(_round_number: int = 0) -> void:
	_purchased_random_ids.clear()
	if _is_open:
		close_shop()


func is_open() -> bool:
	return _is_open


func _connect_round_manager() -> void:
	_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _round_manager == null:
		return
	if not _round_manager.rest_ended.is_connected(on_rest_ended):
		_round_manager.rest_ended.connect(on_rest_ended)


func _init_styles() -> void:
	_style_btn_normal = _make_box(COLOR_BTN_BG, COLOR_BTN_BORDER, 1, 3)
	_style_btn_hover = _make_box(COLOR_BTN_HOVER_BG, COLOR_BTN_HOVER_BORDER, 1, 3)
	_style_btn_pressed = _make_box(COLOR_BTN_PRESSED_BG, COLOR_TITLE, 1, 3)
	_style_btn_focus = _make_box(COLOR_BTN_FOCUS_BG, COLOR_TITLE, 2, 3)
	_style_btn_disabled = _make_box(COLOR_BTN_DISABLED_BG, COLOR_BTN_DISABLED_BORDER, 1, 3)


func _make_box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 4.0
	return box


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = COLOR_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	backdrop.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "ShopPanel"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", _make_box(COLOR_PANEL_BG, COLOR_PANEL_BORDER, 2, 4))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 5)
	margin.add_child(root_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "MERCANTE ANÓNIMO"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	header.add_child(title)

	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance_label.add_theme_font_size_override("font_size", 12)
	_balance_label.add_theme_color_override("font_color", COLOR_BALANCE)
	header.add_child(_balance_label)

	root_vbox.add_child(_create_separator())
	root_vbox.add_child(_create_section_label("SIEMPRE DISPONIBLE"))

	_always_container = HBoxContainer.new()
	_always_container.name = "AlwaysContainer"
	_always_container.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_always_container)

	root_vbox.add_child(_create_section_label("OFERTA DEL DESCANSO"))

	_random_grid = GridContainer.new()
	_random_grid.name = "RandomGrid"
	_random_grid.columns = 2
	_random_grid.add_theme_constant_override("h_separation", 8)
	_random_grid.add_theme_constant_override("v_separation", 6)
	root_vbox.add_child(_random_grid)

	root_vbox.add_child(_create_separator())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	root_vbox.add_child(footer)

	var hint := Label.new()
	hint.text = "Flechas/Tab: Navegar · Enter/Clic: Comprar · Esc: Cerrar"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	footer.add_child(hint)

	if debug_shortcuts_enabled and OS.is_debug_build():
		var debug_shards_btn := Button.new()
		debug_shards_btn.name = "DebugShardsButton"
		debug_shards_btn.text = "+%d Esq. [G]" % DEBUG_SHARDS_AMOUNT
		debug_shards_btn.focus_mode = Control.FOCUS_NONE
		debug_shards_btn.custom_minimum_size = Vector2(96.0, 22.0)
		debug_shards_btn.add_theme_font_size_override("font_size", 10)
		debug_shards_btn.add_theme_color_override("font_color", COLOR_BALANCE)
		_apply_button_styles(debug_shards_btn)
		debug_shards_btn.pressed.connect(_on_debug_add_shards)
		footer.add_child(debug_shards_btn)

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "Cerrar [Esc]"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.custom_minimum_size = Vector2(92.0, 22.0)
	_close_button.add_theme_font_size_override("font_size", 10)
	_close_button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	_apply_button_styles(_close_button)
	_close_button.pressed.connect(close_shop)
	footer.add_child(_close_button)


func _create_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxFlat.new()
	line.bg_color = COLOR_SEPARATOR
	line.content_margin_top = 1.0
	line.content_margin_bottom = 0.0
	sep.add_theme_stylebox_override("separator", line)
	return sep


func _create_section_label(heading: String) -> Label:
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOR_SECTION)
	return label


func _apply_button_styles(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _style_btn_normal)
	btn.add_theme_stylebox_override("hover", _style_btn_hover)
	btn.add_theme_stylebox_override("pressed", _style_btn_pressed)
	btn.add_theme_stylebox_override("focus", _style_btn_focus)
	btn.add_theme_stylebox_override("disabled", _style_btn_disabled)


func _populate_offers() -> void:
	_clear_offer_container(_always_container)
	_clear_offer_container(_random_grid)
	_always_entries.clear()
	_random_entries.clear()

	for item: Resource in ShopManager.current_always_offers:
		var entry: Dictionary = _create_offer_card(item, true, ALWAYS_CARD_HEIGHT)
		_always_container.add_child(entry["button"] as Button)
		_always_entries.append(entry)

	for item: Resource in ShopManager.current_random_offers:
		var entry: Dictionary = _create_offer_card(item, false, RANDOM_CARD_HEIGHT)
		_random_grid.add_child(entry["button"] as Button)
		_random_entries.append(entry)

	_refresh_all_cards()
	_wire_focus_navigation()


func _clear_offer_container(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _create_offer_card(item: Resource, is_always: bool, card_height: float) -> Dictionary:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0.0, card_height)
	btn.text = ""
	_apply_button_styles(btn)
	btn.pressed.connect(_on_offer_pressed.bind(item, is_always))

	var inner := MarginContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("margin_left", 7)
	inner.add_theme_constant_override("margin_right", 7)
	inner.add_theme_constant_override("margin_top", 4)
	inner.add_theme_constant_override("margin_bottom", 4)
	btn.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	inner.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 5)
	vbox.add_child(top_row)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 10)
	top_row.add_child(name_label)

	var level_label := Label.new()
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.add_theme_font_size_override("font_size", 9)
	level_label.add_theme_color_override("font_color", COLOR_LEVEL)
	top_row.add_child(level_label)

	var price_label := Label.new()
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price_label.add_theme_font_size_override("font_size", 10)
	top_row.add_child(price_label)

	var effect_label := Label.new()
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	effect_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(effect_label)

	var entry: Dictionary = {}
	entry["item"] = item
	entry["is_always"] = is_always
	entry["button"] = btn
	entry["name_label"] = name_label
	entry["level_label"] = level_label
	entry["price_label"] = price_label
	entry["effect_label"] = effect_label
	return entry


func _refresh_all_cards() -> void:
	for entry: Dictionary in _always_entries:
		_refresh_card(entry)
	for entry: Dictionary in _random_entries:
		_refresh_card(entry)


func _refresh_card(entry: Dictionary) -> void:
	var item := entry["item"] as Resource
	var is_always: bool = bool(entry["is_always"])
	var btn := entry["button"] as Button
	var name_label := entry["name_label"] as Label
	var level_label := entry["level_label"] as Label
	var price_label := entry["price_label"] as Label
	var effect_label := entry["effect_label"] as Label

	var item_id: StringName = ShopManager.get_item_id(item)
	var price: int = _get_item_price(item)
	var already_bought: bool = not is_always and _purchased_random_ids.has(item_id)
	var maxed: bool = ShopManager.is_max_level(item)
	var affordable: bool = CurrencyManager.can_afford(price)

	name_label.text = _get_item_name(item)
	effect_label.text = _get_item_effect(item)

	var level_text: String = _format_level_text(item, is_always)
	level_label.text = level_text
	level_label.visible = not level_text.is_empty()

	if already_bought:
		price_label.text = "[COMPRADO]"
		price_label.add_theme_color_override("font_color", COLOR_PURCHASED)
		btn.disabled = true
	elif maxed:
		price_label.text = "[MÁX]"
		price_label.add_theme_color_override("font_color", COLOR_MAXED)
		btn.disabled = true
	else:
		price_label.text = "%d Esq." % price
		var price_color: Color = COLOR_PRICE_OK if affordable else COLOR_PRICE_LOW
		price_label.add_theme_color_override("font_color", price_color)
		btn.disabled = not affordable

	var title_color: Color = COLOR_TEXT_MUTED if btn.disabled else COLOR_TEXT_PRIMARY
	var effect_color: Color = COLOR_TEXT_MUTED if btn.disabled else COLOR_TEXT_EFFECT
	name_label.add_theme_color_override("font_color", title_color)
	effect_label.add_theme_color_override("font_color", effect_color)


func _on_offer_pressed(item: Resource, is_always: bool) -> void:
	if not _is_open or item == null:
		return
	var item_id: StringName = ShopManager.get_item_id(item)
	if not is_always and _purchased_random_ids.has(item_id):
		return
	if ShopManager.is_max_level(item):
		return
	var price: int = _get_item_price(item)
	if not CurrencyManager.spend(price):
		return
	var new_level: int = ShopManager.register_purchase(item)
	if not is_always and item_id != &"":
		_purchased_random_ids[item_id] = true
	if sfx_upgrade_buy != null:
		AudioManager.play_sfx(sfx_upgrade_buy)
	purchase_completed.emit(item, new_level)
	_update_balance_label()
	_refresh_all_cards()
	_ensure_valid_focus()


func _on_balance_changed(_new_balance: int, _delta: int) -> void:
	_update_balance_label()
	if _is_open:
		_refresh_all_cards()


func _on_debug_add_shards() -> void:
	CurrencyManager.add(DEBUG_SHARDS_AMOUNT)


func _update_balance_label() -> void:
	if _balance_label == null:
		return
	_balance_label.text = "%s: %d" % [CurrencyManager.get_currency_name(), CurrencyManager.balance]


func _wire_focus_navigation() -> void:
	var rows: Array[Array] = []
	var all_buttons: Array[Button] = []

	var always_row: Array[Button] = []
	for entry: Dictionary in _always_entries:
		var btn := entry["button"] as Button
		always_row.append(btn)
		all_buttons.append(btn)
	if not always_row.is_empty():
		rows.append(always_row)

	var current_row: Array[Button] = []
	for entry: Dictionary in _random_entries:
		var btn := entry["button"] as Button
		current_row.append(btn)
		all_buttons.append(btn)
		if current_row.size() == 2:
			rows.append(current_row)
			current_row = []
	if not current_row.is_empty():
		rows.append(current_row)

	if _close_button != null:
		rows.append([_close_button])
		all_buttons.append(_close_button)

	var row_count: int = rows.size()
	for r: int in row_count:
		var row: Array = rows[r]
		var prev_row: Array = rows[(r - 1 + row_count) % row_count]
		var next_row: Array = rows[(r + 1) % row_count]
		var col_count: int = row.size()
		for c: int in col_count:
			var btn := row[c] as Button
			var left_btn := row[(c - 1 + col_count) % col_count] as Button
			var right_btn := row[(c + 1) % col_count] as Button
			var top_btn := prev_row[mini(c, prev_row.size() - 1)] as Button
			var bottom_btn := next_row[mini(c, next_row.size() - 1)] as Button
			btn.focus_neighbor_left = left_btn.get_path()
			btn.focus_neighbor_right = right_btn.get_path()
			btn.focus_neighbor_top = top_btn.get_path()
			btn.focus_neighbor_bottom = bottom_btn.get_path()

	var total: int = all_buttons.size()
	for i: int in total:
		var btn: Button = all_buttons[i]
		btn.focus_next = all_buttons[(i + 1) % total].get_path()
		btn.focus_previous = all_buttons[(i - 1 + total) % total].get_path()


func _focus_initial_button() -> void:
	if not _is_open:
		return
	var target: Button = _find_first_enabled_button()
	if target != null:
		target.grab_focus()


func _ensure_valid_focus() -> void:
	if not _is_open:
		return
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused != null and not focused.disabled:
		return
	var target: Button = _find_first_enabled_button()
	if target != null:
		target.grab_focus()


func _find_first_enabled_button() -> Button:
	for entry: Dictionary in _always_entries:
		var btn := entry["button"] as Button
		if not btn.disabled:
			return btn
	for entry: Dictionary in _random_entries:
		var btn := entry["button"] as Button
		if not btn.disabled:
			return btn
	return _close_button


func _get_item_name(item: Resource) -> String:
	if item is UpgradeData:
		return (item as UpgradeData).nombre
	if item is FaithPowerData:
		return (item as FaithPowerData).nombre
	if item is ShopWeaponData:
		return (item as ShopWeaponData).nombre
	return ""


func _get_item_price(item: Resource) -> int:
	if item is UpgradeData:
		return maxi((item as UpgradeData).precio, 0)
	if item is FaithPowerData:
		return maxi((item as FaithPowerData).precio_tienda, 0)
	if item is ShopWeaponData:
		return maxi((item as ShopWeaponData).precio_tienda, 0)
	return 0


func _get_item_effect(item: Resource) -> String:
	if item is UpgradeData:
		return (item as UpgradeData).efecto
	if item is FaithPowerData:
		return (item as FaithPowerData).efecto
	if item is ShopWeaponData:
		return (item as ShopWeaponData).efecto
	return ""


func _format_level_text(item: Resource, is_always: bool) -> String:
	if is_always:
		return ""
	var max_lvl: int = 0
	if item is UpgradeData:
		max_lvl = (item as UpgradeData).nivel_maximo
	elif item is FaithPowerData:
		max_lvl = (item as FaithPowerData).nivel_maximo
	elif item is ShopWeaponData:
		var weapon := item as ShopWeaponData
		return "[Melee]" if weapon.slot == ShopWeaponData.WeaponSlot.MELEE else "[Fuego]"
	if max_lvl > 0:
		return "Nv. %d/%d" % [ShopManager.get_item_level(item), max_lvl]
	return ""
