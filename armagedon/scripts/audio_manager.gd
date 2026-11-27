extends Node
## Audio del juego (GDD §14): buses Music/SFX/Voice, reproducción y ducking.
## Autoload "AudioManager" (Godot 4.7 no deja declarar `class_name AudioManager`
## junto a un autoload del mismo nombre: "Class hides an autoload singleton").
## El volumen del jugador se expone en linear 0..1 con
## set_bus_volume()/get_bus_volume(); guardarlo en user:// lo hace #91 (ConfigFile).

signal bus_volume_changed(bus_name: String, linear: float)

enum MusicMode { NONE, MENU, CIRCLE_1, BOSS }

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
const CIRCLE_1_MAX_ROUND: int = 10

const MUSIC_MENU: AudioStream = preload("res://assets/audio/music/Seventh_Circle_Hymn.ogg")
const MUSIC_BOSS_LIMBO: AudioStream = preload("res://assets/audio/music/Last_Gate_of_the_Maze.ogg")
const CIRCLE_1_TRACKS: Array[AudioStream] = [
	MUSIC_MENU,
	preload("res://assets/audio/music/The_Gatekeeper_s_Toll.ogg"),
	preload("res://assets/audio/music/Piston_and_Bone.ogg"),
]

var _music: AudioStreamPlayer
var _voice: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cursor: int = 0
## Volumen elegido por el usuario en cada bus (linear 0..1), sin el ducking encima.
var _bus_linear: Dictionary = {}
## Multiplicador de ducking sobre Music: 1.0 = sin atenuar.
var _duck_factor: float = 1.0
var _duck_tween: Tween
## Multiplicador de fade-out sobre Music (p. ej. entrada dramática del jefe).
var _music_fade_factor: float = 1.0
var _fade_tween: Tween
var _music_mode: MusicMode = MusicMode.NONE
var _last_circle_1_track: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)
	_ensure_bus(BUS_VOICE)
	_music = _new_player(BUS_MUSIC)
	_music.finished.connect(_on_music_finished)
	_voice = _new_player(BUS_VOICE)
	for _i in SFX_POOL_SIZE:
		_sfx_pool.append(_new_player(BUS_SFX))
	_bus_linear = {BUS_MUSIC: 1.0, BUS_SFX: 1.0, BUS_VOICE: 1.0}


## Pone una pista de música (bus Music).
func play_music(stream: AudioStream) -> void:
	if stream == null:
		push_error("AudioManager.play_music: stream nulo")
		return
	_kill_music_fade()
	_set_music_fade_factor(1.0)
	_music.stream = stream
	_music.play()
	var bus_idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	var bus_db: float = AudioServer.get_bus_volume_db(bus_idx) if bus_idx != -1 else -999.0
	var master_db: float = AudioServer.get_bus_volume_db(0)
	var master_mute: bool = AudioServer.is_bus_mute(0)
	(
		DebugLogger
		. write(
			"AUDIO",
			(
				(
					"play_music=%s | playing=%s | bus=%s(idx=%d,db=%.1f,mute=%s)"
					+ " | master(db=%.1f,mute=%s) | drv=%s dev=%s | mode=%d"
				)
				% [
					stream.resource_path,
					str(_music.playing),
					_music.bus,
					bus_idx,
					bus_db,
					str(AudioServer.is_bus_mute(bus_idx) if bus_idx != -1 else true),
					master_db,
					str(master_mute),
					AudioServer.get_driver_name(),
					AudioServer.output_device,
					_music_mode,
				]
			)
		)
	)


## Detiene la pista que esté sonando.
func stop_music() -> void:
	DebugLogger.write("AUDIO", "stop_music()")
	_kill_music_fade()
	_music.stop()
	_set_music_fade_factor(1.0)


## Inicia la música del menú principal sin reiniciarla si ya está sonando.
func play_menu_music() -> void:
	_music_mode = MusicMode.MENU
	if _music.playing and _music.stream == MUSIC_MENU:
		_kill_music_fade()
		_set_music_fade_factor(1.0)
		return
	play_music(MUSIC_MENU)


## Actualiza la música al iniciar una ronda (solo primer círculo: rondas 1..10).
func on_round_started(round_number: int, is_boss_round: bool) -> void:
	if round_number > CIRCLE_1_MAX_ROUND:
		if _music_mode == MusicMode.CIRCLE_1 or _music_mode == MusicMode.BOSS:
			_music_mode = MusicMode.NONE
			fade_out_music(1.5)
		return
	if is_boss_round:
		return
	_music_mode = MusicMode.CIRCLE_1
	if _music.playing and _music.stream in CIRCLE_1_TRACKS:
		return
	_play_next_circle_1_track()


## Inicia la música del jefe del primer círculo.
func play_boss_limbo_music() -> void:
	_music_mode = MusicMode.BOSS
	play_music(MUSIC_BOSS_LIMBO)


## Baja poco a poco el volumen de la música actual hasta detenerla.
func fade_out_music(duration: float = 1.8) -> void:
	DebugLogger.write(
		"AUDIO", "fade_out_music(duration=%.2f, playing=%s)" % [duration, str(_music.playing)]
	)
	_kill_music_fade()
	if not _music.playing:
		_set_music_fade_factor(1.0)
		return
	if duration <= 0.0:
		stop_music()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_method(_set_music_fade_factor, _music_fade_factor, 0.0, duration)
	_fade_tween.tween_callback(stop_music)


## Reproduce un efecto desde el pool: el siguiente SFX no corta al anterior.
func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		push_error("AudioManager.play_sfx: stream nulo")
		return
	var player: AudioStreamPlayer = _sfx_pool[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Reproduce una línea en el bus Voice y atenúa la música mientras suena
## (GDD §14: "Baja la música 30% durante 3 s al hablar").
func play_voice(stream: AudioStream) -> void:
	if stream == null:
		push_error("AudioManager.play_voice: stream nulo")
		return
	_voice.stream = stream
	_voice.play()
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
	bus_volume_changed.emit(bus_name, float(_bus_linear[bus_name]))


## Volumen elegido por el usuario en un bus (0..1 lineal), sin el ducking de la voz.
func get_bus_volume(bus_name: String) -> float:
	return float(_bus_linear.get(bus_name, 1.0))


func _apply_bus_volume(bus_name: String) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	var linear: float = float(_bus_linear.get(bus_name, 1.0))
	if bus_name == BUS_MUSIC:
		linear *= _duck_factor * _music_fade_factor
	AudioServer.set_bus_volume_db(index, SILENCE_DB if linear <= 0.0 else linear_to_db(linear))


func _set_duck_factor(value: float) -> void:
	_duck_factor = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC)


func _kill_duck() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = null


func _set_music_fade_factor(value: float) -> void:
	_music_fade_factor = clampf(value, 0.0, 1.0)
	_apply_bus_volume(BUS_MUSIC)


func _kill_music_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


func _on_music_finished() -> void:
	match _music_mode:
		MusicMode.MENU:
			play_music(MUSIC_MENU)
		MusicMode.CIRCLE_1:
			_play_next_circle_1_track()
		MusicMode.BOSS:
			play_music(MUSIC_BOSS_LIMBO)


func _play_next_circle_1_track() -> void:
	var count: int = CIRCLE_1_TRACKS.size()
	if count == 0:
		return
	if count == 1:
		_last_circle_1_track = CIRCLE_1_TRACKS[0]
		play_music(_last_circle_1_track)
		return
	var candidates: Array[AudioStream] = []
	for track: AudioStream in CIRCLE_1_TRACKS:
		if track != _last_circle_1_track:
			candidates.append(track)
	var chosen: AudioStream = candidates[randi_range(0, candidates.size() - 1)]
	_last_circle_1_track = chosen
	play_music(chosen)


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
