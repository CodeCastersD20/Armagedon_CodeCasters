extends Node
## Audio del juego (GDD §14): buses Music/SFX/Voice, reproducción y ducking.
## Autoload "AudioManager" (Godot 4.7 no deja declarar `class_name AudioManager`
## junto a un autoload del mismo nombre: "Class hides an autoload singleton").
## El volumen del jugador se expone en linear 0..1 con
## set_bus_volume()/get_bus_volume(); guardarlo en user:// lo hace #91 (ConfigFile).

signal music_started(stream: AudioStream)
signal music_finished
signal voice_started(stream: AudioStream)
signal voice_finished

const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"
const BUS_VOICE: String = "Voice"
## Reproductores simultáneos de efectos: un SFX nunca corta a otro.
const SFX_POOL_SIZE: int = 8
## GDD §14: la voz de Lucifer baja la música 30% durante 3 s.
const DEFAULT_DUCK_AMOUNT: float = 0.3
const DEFAULT_DUCK_SECONDS: float = 3.0
const DUCK_FADE_SECONDS: float = 0.25
## Por debajo de este nivel se trata como silencio (linear_to_db(0.0) es -inf).
const SILENCE_DB: float = -80.0

var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
## Volumen elegido por el usuario en cada bus (linear 0..1), sin el ducking encima.
var _bus_linear: Dictionary = {}
## Multiplicador de ducking sobre Music: 1.0 = sin atenuar.
var _duck_factor: float = 1.0
var _duck_tween: Tween
var _fade_tween: Tween


func _ready() -> void:
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_VOICE)
	_music = _new_player(BUS_MUSIC)
	_voice = _new_player(BUS_VOICE)
	_music.finished.connect(_on_music_finished)
	_voice.finished.connect(_on_voice_finished)
	for _i in SFX_POOL_SIZE:
		_sfx_pool.append(_new_player(BUS_SFX))
	_bus_linear = {BUS_MUSIC: 1.0, BUS_SFX: 1.0, BUS_VOICE: 1.0}


## Pone una pista; con `fade > 0` entra de forma gradual desde el silencio.
func play_music(stream: AudioStream, fade := 0.0) -> void:
	if stream == null:
		push_error("AudioManager.play_music: stream nulo")
		return
	_kill_fade()
	_music.stream = stream
	_music.volume_db = 0.0 if fade <= 0.0 else SILENCE_DB
	_music.play()
	music_started.emit(stream)
	if fade > 0.0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_music, "volume_db", 0.0, fade)


## Detiene la pista; con `fade > 0` sale gradualmente hasta el silencio.
func stop_music(fade := 0.0) -> void:
	_kill_fade()
	if not _music.playing:
		return
	if fade <= 0.0:
		_music.stop()
		return
	_music.volume_db = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_music, "volume_db", SILENCE_DB, fade)
	_fade_tween.tween_callback(_music.stop)


## Reproduce un efecto desde el pool: el siguiente SFX no corta al anterior.
## `volume_db` es un ajuste extra (0.0 = volumen del bus) y `pitch` la variación.
func play_sfx(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	if stream == null:
		push_error("AudioManager.play_sfx: stream nulo")
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch, 0.01)
	player.play()


## Reproduce una línea en el bus Voice. Con `duck` atenúa la música mientras suena
## (GDD §14: "Baja la música 30% durante 3 s al hablar").
func play_voice(stream: AudioStream, duck := true) -> void:
	if stream == null:
		push_error("AudioManager.play_voice: stream nulo")
		return
	_voice.stream = stream
	_voice.play()
	voice_started.emit(stream)
	if duck:
		duck_music()


## Atenua la música un `amount` (0..1) durante `seconds` segundos y luego la restaura.
## No se acumulan ducks: otro que llegue mientras dura el anterior solo reinicia el reloj.
func duck_music(amount := DEFAULT_DUCK_AMOUNT, seconds := DEFAULT_DUCK_SECONDS) -> void:
	if seconds <= 0.0:
		return
	var target: float = 1.0 - clampf(amount, 0.0, 1.0)
	_kill_duck()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_factor, _duck_factor, target, DUCK_FADE_SECONDS)
	_duck_tween.tween_interval(seconds)
	_duck_tween.tween_method(_set_duck_factor, target, 1.0, DUCK_FADE_SECONDS)


## Cambia el volumen de un bus (0..1 lineal). #91 solo llamará a esto.
func set_bus_volume(bus_name: String, linear: float) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		push_warning("AudioManager.set_bus_volume: bus inexistente '%s'" % bus_name)
		return
	_bus_linear[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(bus_name)


## Volumen elegido por el usuario en un bus (0..1 lineal), sin el ducking de la voz.
func get_bus_volume(bus_name: String) -> float:
	return float(_bus_linear.get(bus_name, 1.0))


## Silencia o restaura un bus por completo manteniendo el volumen elegido.
func set_bus_mute(bus_name: String, muted: bool) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		push_warning("AudioManager.set_bus_mute: bus inexistente '%s'" % bus_name)
		return
	AudioServer.set_bus_mute(index, muted)


func _apply_bus_volume(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear: float = float(_bus_linear.get(bus_name, 1.0))
	if bus_name == BUS_MUSIC:
		linear *= _duck_factor
	AudioServer.set_bus_volume_db(index, SILENCE_DB if linear <= 0.0 else linear_to_db(linear))


func _set_duck_factor(value: float) -> void:
	_duck_factor = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC)


func _on_music_finished() -> void:
	music_finished.emit()


func _on_voice_finished() -> void:
	voice_finished.emit()


func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _kill_duck() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


## Crea el bus si aún no existe; los buses se hacen en runtime para no versionar
## un default_bus_layout.tres que chocaría con el importador del CI.
func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _new_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus_name
	add_child(player)
	return player
