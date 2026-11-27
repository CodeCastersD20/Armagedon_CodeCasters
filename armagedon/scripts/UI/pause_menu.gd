class_name PauseMenu
extends CanvasLayer
## Menú de pausa demo con Reanudar y Configuración de volúmenes (General, Música, Efectos).

const PLAY_MENU_SCENE_PATH: String = "res://scenes/UI/PlayMenu.tscn"
const BUS_MASTER: String = "Master"

@onready var _root: Control = $Root
@onready var _main_panel: VBoxContainer = $Root/Center/Panel/Margin/MainPanel
@onready var _settings_panel: VBoxContainer = $Root/Center/Panel/Margin/SettingsPanel
@onready var _resume_button: Button = $Root/Center/Panel/Margin/MainPanel/ResumeButton
@onready var _settings_button: Button = $Root/Center/Panel/Margin/MainPanel/SettingsButton
@onready var _menu_button: Button = $Root/Center/Panel/Margin/MainPanel/MenuButton
@onready var _back_button: Button = $Root/Center/Panel/Margin/SettingsPanel/BackButton

@onready var _master_slider: HSlider = $Root/Center/Panel/Margin/SettingsPanel/MasterRow/Slider
@onready var _master_value: Label = $Root/Center/Panel/Margin/SettingsPanel/MasterRow/Value
@onready var _music_slider: HSlider = $Root/Center/Panel/Margin/SettingsPanel/MusicRow/Slider
@onready var _music_value: Label = $Root/Center/Panel/Margin/SettingsPanel/MusicRow/Value
@onready var _sfx_slider: HSlider = $Root/Center/Panel/Margin/SettingsPanel/SfxRow/Slider
@onready var _sfx_value: Label = $Root/Center/Panel/Margin/SettingsPanel/SfxRow/Value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_main_panel.visible = true
	_settings_panel.visible = false

	_resume_button.pressed.connect(resume)
	_settings_button.pressed.connect(_open_settings)
	_menu_button.pressed.connect(_return_to_menu)
	_back_button.pressed.connect(_close_settings)

	_bind_volume_slider(_master_slider, _master_value, BUS_MASTER)
	_bind_volume_slider(_music_slider, _music_value, AudioManager.BUS_MUSIC)
	_bind_volume_slider(_sfx_slider, _sfx_value, AudioManager.BUS_SFX)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not _root.visible:
		pause()
	elif _settings_panel.visible:
		_close_settings()
	else:
		resume()


## Activa la pausa, muestra el menú y libera el cursor.
func pause() -> void:
	_sync_sliders()
	_main_panel.visible = true
	_settings_panel.visible = false
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume_button.grab_focus()


## Cierra el menú de pausa, reanuda el juego y vuelve a capturar el cursor.
func resume() -> void:
	_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_settings() -> void:
	_sync_sliders()
	_main_panel.visible = false
	_settings_panel.visible = true
	_master_slider.grab_focus()


func _close_settings() -> void:
	_settings_panel.visible = false
	_main_panel.visible = true
	_settings_button.grab_focus()


func _return_to_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(PLAY_MENU_SCENE_PATH)


func _bind_volume_slider(slider: HSlider, value_label: Label, bus_name: String) -> void:
	slider.value_changed.connect(
		func(value: float) -> void:
			AudioManager.set_bus_volume(bus_name, value)
			_update_percent_label(value_label, value)
	)


func _sync_sliders() -> void:
	var pairs: Array[Array] = [
		[_master_slider, _master_value, BUS_MASTER],
		[_music_slider, _music_value, AudioManager.BUS_MUSIC],
		[_sfx_slider, _sfx_value, AudioManager.BUS_SFX],
	]
	for pair: Array in pairs:
		var slider: HSlider = pair[0]
		var label: Label = pair[1]
		var bus_name: String = pair[2]
		var vol: float = AudioManager.get_bus_volume(bus_name)
		slider.set_value_no_signal(vol)
		_update_percent_label(label, vol)


func _update_percent_label(label: Label, linear: float) -> void:
	label.text = "%d%%" % roundi(clampf(linear, 0.0, 1.0) * 100.0)
