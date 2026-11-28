extends Node
## Coordina el idioma activo usando el TranslationServer nativo de Godot (.po).
## Autoload "LocalizationManager" (sin class_name para no colisionar con el singleton).

signal language_changed(locale: String)

const LOCALE_ES: String = "es"
const LOCALE_EN: String = "en"
const DEFAULT_LOCALE: String = LOCALE_ES
const SUPPORTED_LOCALES: PackedStringArray = [LOCALE_ES, LOCALE_EN]

var _current_locale: String = DEFAULT_LOCALE


func _ready() -> void:
	TranslationServer.set_locale(_current_locale)


## Cambia el idioma activo en TranslationServer ("es" o "en") y notifica a la UI dinámica.
func set_language(locale: String) -> void:
	var target: String = locale if SUPPORTED_LOCALES.has(locale) else DEFAULT_LOCALE
	if target == _current_locale and TranslationServer.get_locale() == target:
		return
	_current_locale = target
	TranslationServer.set_locale(_current_locale)
	language_changed.emit(_current_locale)


## Devuelve el código de idioma activo ("es" o "en").
func get_language() -> String:
	return _current_locale


## Traduce `key` vía TranslationServer (`tr()`) con `fallback` si la clave no existe.
func t(key: String, fallback: String = "") -> String:
	var translated: String = tr(key)
	if translated == key and fallback != "":
		return fallback
	return translated


## Traduce `key` y formatea con `% args`.
func tf(key: String, args: Array) -> String:
	return tr(key) % args
