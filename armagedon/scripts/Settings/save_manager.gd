extends Node
## Gestor de los 3 archivos de guardado independientes (user://save_slot_1..3.cfg).
## Autoload "SaveManager". Guarda progreso básico (mejor Score/ronda) y volúmenes de audio por slot.

signal slot_changed(slot: int)

const SLOT_COUNT: int = 3
const SAVE_FILE_TEMPLATE: String = "save_slot_%d.cfg"
const SAVE_PATH_TEMPLATE: String = "user://save_slot_%d.cfg"

const SECTION_PROGRESS: String = "progress"
const SECTION_AUDIO: String = "audio"
const SECTION_SETTINGS: String = "settings"

const DEFAULT_VOLUME: float = 1.0
const DEFAULT_LANGUAGE: String = "es"

var active_slot: int = 1
var best_score: int = 0
var best_round: int = 0
var _applying_volumes: bool = false
var _applying_settings: bool = false


func _ready() -> void:
	AudioManager.bus_volume_changed.connect(_on_bus_volume_changed)
	LocalizationManager.language_changed.connect(_on_language_changed)
	if slot_exists(active_slot):
		_load_slot(active_slot)


## Selecciona un slot (1..3), carga su archivo (o lo crea) y aplica sus volúmenes.
func select_slot(slot: int) -> void:
	if slot < 1 or slot > SLOT_COUNT:
		push_warning("SaveManager.select_slot: slot inválido %d" % slot)
		return
	active_slot = slot
	if slot_exists(slot):
		_load_slot(slot)
	else:
		best_score = 0
		best_round = 0
		_apply_volumes_to_audio_manager(
			DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME
		)
		_apply_language_to_manager(DEFAULT_LANGUAGE)
		save_active_slot()
	slot_changed.emit(active_slot)


## Comprueba si el archivo de guardado del slot existe.
func slot_exists(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	return FileAccess.file_exists(SAVE_PATH_TEMPLATE % slot)


## Devuelve un resumen del slot sin cambiar el slot activo.
func get_slot_summary(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {"exists": false, "corrupted": false, "best_score": 0, "best_round": 0}
	var config := ConfigFile.new()
	if config.load(SAVE_PATH_TEMPLATE % slot) != OK:
		return {"exists": true, "corrupted": true, "best_score": 0, "best_round": 0}
	return {
		"exists": true,
		"corrupted": false,
		"best_score": _read_non_neg_int(config, SECTION_PROGRESS, "best_score", 0),
		"best_round": _read_non_neg_int(config, SECTION_PROGRESS, "best_round", 0),
	}


## Borra el archivo de guardado del slot indicado.
func delete_slot(slot: int) -> void:
	if not slot_exists(slot):
		return
	var dir := DirAccess.open("user://")
	if dir != null:
		var err: Error = dir.remove(SAVE_FILE_TEMPLATE % slot)
		if err != OK:
			push_warning("SaveManager: no se pudo borrar slot %d (err=%d)" % [slot, err])
	if slot == active_slot:
		best_score = 0
		best_round = 0


## Actualiza mejor Score/ronda del slot activo y guarda.
func record_run_result(score: int, round_reached: int) -> void:
	var changed: bool = false
	if score > best_score:
		best_score = score
		changed = true
	if round_reached > best_round:
		best_round = round_reached
		changed = true
	if changed:
		save_active_slot()


## Guarda el estado y volúmenes actuales en el archivo del slot activo.
func save_active_slot() -> void:
	var config := ConfigFile.new()
	var load_err: Error = config.load(SAVE_PATH_TEMPLATE % active_slot)
	if load_err != OK and load_err != ERR_FILE_NOT_FOUND:
		push_warning(
			"SaveManager: archivo corrupto en slot %d, sobrescribiendo (err=%d)"
			% [active_slot, load_err]
		)
	config.set_value(SECTION_PROGRESS, "best_score", maxi(best_score, 0))
	config.set_value(SECTION_PROGRESS, "best_round", maxi(best_round, 0))
	config.set_value(SECTION_AUDIO, "master", AudioManager.get_bus_volume("Master"))
	config.set_value(SECTION_AUDIO, "music", AudioManager.get_bus_volume(AudioManager.BUS_MUSIC))
	config.set_value(SECTION_AUDIO, "sfx", AudioManager.get_bus_volume(AudioManager.BUS_SFX))
	config.set_value(SECTION_AUDIO, "voice", AudioManager.get_bus_volume(AudioManager.BUS_VOICE))
	config.set_value(SECTION_SETTINGS, "language", LocalizationManager.get_language())
	var save_err: Error = config.save(SAVE_PATH_TEMPLATE % active_slot)
	if save_err != OK:
		push_warning("SaveManager: no se pudo guardar slot %d (err=%d)" % [active_slot, save_err])


func _load_slot(slot: int) -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH_TEMPLATE % slot) != OK:
		push_warning("SaveManager: no se pudo leer slot %d; usando valores por defecto" % slot)
		best_score = 0
		best_round = 0
		_apply_volumes_to_audio_manager(
			DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME, DEFAULT_VOLUME
		)
		_apply_language_to_manager(DEFAULT_LANGUAGE)
		return
	best_score = _read_non_neg_int(config, SECTION_PROGRESS, "best_score", 0)
	best_round = _read_non_neg_int(config, SECTION_PROGRESS, "best_round", 0)
	var master_v: float = _read_volume(config, SECTION_AUDIO, "master", DEFAULT_VOLUME)
	var music_v: float = _read_volume(config, SECTION_AUDIO, "music", DEFAULT_VOLUME)
	var sfx_v: float = _read_volume(config, SECTION_AUDIO, "sfx", DEFAULT_VOLUME)
	var voice_v: float = _read_volume(config, SECTION_AUDIO, "voice", DEFAULT_VOLUME)
	_apply_volumes_to_audio_manager(master_v, music_v, sfx_v, voice_v)
	var raw_lang: Variant = config.get_value(SECTION_SETTINGS, "language", DEFAULT_LANGUAGE)
	var lang: String = raw_lang if typeof(raw_lang) == TYPE_STRING else DEFAULT_LANGUAGE
	_apply_language_to_manager(lang)


func _read_non_neg_int(
	config: ConfigFile, section: String, key: String, fallback: int
) -> int:
	var raw: Variant = config.get_value(section, key, fallback)
	if typeof(raw) == TYPE_INT:
		return maxi(int(raw), 0)
	if typeof(raw) == TYPE_FLOAT and not is_nan(float(raw)) and not is_inf(float(raw)):
		return maxi(int(raw), 0)
	return fallback


func _read_volume(
	config: ConfigFile, section: String, key: String, fallback: float
) -> float:
	var raw: Variant = config.get_value(section, key, fallback)
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		var val: float = float(raw)
		if not is_nan(val) and not is_inf(val):
			return clampf(val, 0.0, 1.0)
	return fallback


func _apply_volumes_to_audio_manager(
	master_v: float, music_v: float, sfx_v: float, voice_v: float
) -> void:
	_applying_volumes = true
	AudioManager.set_bus_volume("Master", master_v)
	AudioManager.set_bus_volume(AudioManager.BUS_MUSIC, music_v)
	AudioManager.set_bus_volume(AudioManager.BUS_SFX, sfx_v)
	AudioManager.set_bus_volume(AudioManager.BUS_VOICE, voice_v)
	_applying_volumes = false


func _apply_language_to_manager(lang: String) -> void:
	_applying_settings = true
	LocalizationManager.set_language(lang)
	_applying_settings = false


func _on_bus_volume_changed(_bus_name: String, _linear: float) -> void:
	if _applying_volumes:
		return
	save_active_slot()


func _on_language_changed(_locale: String) -> void:
	if _applying_settings:
		return
	save_active_slot()
