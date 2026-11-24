extends Control
## Demo de la issue 82: AudioManager en vivo (buses, volumen y ducking).
## Ejecutar: godot --path armagedon res://scenes/Test/audio_manager_demo.tscn
## Genera los tonos en código (no hay assets de audio todavía); no entra en el build.

const RATE: int = 22050
const DEFAULT_MUSIC_VOLUME: float = 0.6
const DUCK_AMOUNT: float = 0.3
const DUCK_SECONDS: float = 3.0
## Texto por tecla/botón: [tecla, descripción].
const ACTIONS: Array = [
	["ESPACIO", "Duck 30% durante 3 s (GDD §14)"],
	["V", "Voz de Lucifer: reproduce y atenúa sola"],
	["S", "SFX de prueba (pool, no se cortan)"],
]

var _status: Label
var _slider: HSlider
var _voice_stream: AudioStreamWAV
var _sfx_stream: AudioStreamWAV
var _last_status: String = ""


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	_voice_stream = _make_tone(330.0, 3.0, 0.30, false)
	_sfx_stream = _make_tone(880.0, 0.15, 0.40, false)
	_build_ui()
	AudioManager.set_bus_volume("Music", DEFAULT_MUSIC_VOLUME)
	AudioManager.play_music(_make_tone(440.0, 1.0, 0.22, true))


func _process(_delta: float) -> void:
	if _status == null:
		return
	var index: int = AudioServer.get_bus_index("Music")
	var db: float = AudioServer.get_bus_volume_db(index)
	var duck: float = float(AudioManager.get("_duck_factor"))
	var text: String = (
		"Music bus: %6.2f dB   |   duck x%.2f   |   slider %.2f"
		% [
			db,
			duck,
			AudioManager.get_bus_volume("Music"),
		]
	)
	if text != _last_status:
		_last_status = text
		_status.text = text


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_SPACE:
			_duck()
		KEY_V:
			_talk()
		KEY_S:
			_sfx()


func _duck() -> void:
	AudioManager.duck_music(DUCK_AMOUNT, DUCK_SECONDS)


func _talk() -> void:
	AudioManager.play_voice(_voice_stream)


func _sfx() -> void:
	AudioManager.play_sfx(_sfx_stream)


func _on_volume_changed(value: float) -> void:
	AudioManager.set_bus_volume("Music", value)


func _build_ui() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 48.0
	box.offset_top = 48.0
	box.offset_right = -48.0
	box.offset_bottom = -48.0
	box.add_theme_constant_override("separation", 12)

	box.add_child(_make_label("AudioManager - demo issue 82", 24))
	box.add_child(_make_label("Buses: Music / SFX / Voice (colgados de Master)", 16))
	_status = _make_label("", 18)
	box.add_child(_status)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 16.0)
	box.add_child(spacer)

	box.add_child(_make_label("Volumen del usuario (slider de #91):", 16))
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.value = DEFAULT_MUSIC_VOLUME
	_slider.value_changed.connect(_on_volume_changed)
	box.add_child(_slider)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0.0, 16.0)
	box.add_child(spacer2)

	for action: Array in ACTIONS:
		var row := HBoxContainer.new()
		var key_label := Label.new()
		key_label.text = String(action[0])
		key_label.custom_minimum_size = Vector2(110.0, 0.0)
		key_label.add_theme_font_size_override("font_size", 16)
		row.add_child(key_label)
		var button := Button.new()
		button.text = String(action[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		match String(action[0]):
			"ESPACIO":
				button.pressed.connect(_duck)
			"V":
				button.pressed.connect(_talk)
			"S":
				button.pressed.connect(_sfx)
		row.add_child(button)
		box.add_child(row)

	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0.0, 16.0)
	box.add_child(spacer3)
	(
		box
		. add_child(
			_make_label(
				"Mueve el slider mientras suena el duck: el volumen base cambia y el duck sigue encima.",
				14
			)
		)
	)


func _make_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


## Tono senoidal generado en memoria: 16 bits, mono, 22.05 kHz (GDD §14).
func _make_tone(hz: float, seconds: float, amplitude: float, loop: bool) -> AudioStreamWAV:
	var frames: int = int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var sample := int(sin(TAU * hz * float(i) / float(RATE)) * amplitude * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frames
	stream.data = data
	return stream
