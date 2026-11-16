extends Node
## Ajustes de pantalla del jugador: límite de FPS y V-Sync (GDD §17.4).
## Autoload "DisplayConfig". Se guardan en user://settings.cfg; el menú de opciones (#91)
## solo debe llamar a set_fps_limit() y set_vsync().

signal changed

## Límites permitidos. 0 = ilimitado.
const FPS_OPTIONS: Array[int] = [30, 60, 144, 180, 0]
# TODO(GDD): el valor por defecto final es [PENDIENTE] (propuesta del GDD: 60). Por ahora 180,
# el máximo de la pantalla del equipo de desarrollo.
const DEFAULT_FPS_LIMIT: int = 180
const DEFAULT_VSYNC: bool = true
const SAVE_PATH: String = "user://settings.cfg"
const SECTION: String = "display"

var fps_limit: int = DEFAULT_FPS_LIMIT
var vsync_enabled: bool = DEFAULT_VSYNC


func _ready() -> void:
	_load()
	_apply()


func set_fps_limit(limit: int) -> void:
	if not FPS_OPTIONS.has(limit):
		push_warning("Límite de FPS no permitido: %d" % limit)
		return
	fps_limit = limit
	_apply()
	_save()


func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply()
	_save()


func _apply() -> void:
	Engine.max_fps = fps_limit
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	changed.emit()


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	var saved_limit: int = int(config.get_value(SECTION, "fps_limit", DEFAULT_FPS_LIMIT))
	fps_limit = saved_limit if FPS_OPTIONS.has(saved_limit) else DEFAULT_FPS_LIMIT
	vsync_enabled = bool(config.get_value(SECTION, "vsync", DEFAULT_VSYNC))


func _save() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)  # conserva otras secciones si existen
	config.set_value(SECTION, "fps_limit", fps_limit)
	config.set_value(SECTION, "vsync", vsync_enabled)
	config.save(SAVE_PATH)
