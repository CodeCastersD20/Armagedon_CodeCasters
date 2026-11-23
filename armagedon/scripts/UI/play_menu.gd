class_name PlayMenu
extends Control
## Pantalla de inicio (60 FPS) con botón Play y caída por el abismo de piedra/lava + brasas.

const MAIN_SCENE_PATH: String = "res://scenes/main.tscn"
const MIN_ANIM_SECONDS: float = 1.30
const EMBER_COUNT: int = 24

var _loading: bool = false
var _elapsed: float = 0.0
var _progress: Array = []
var _packed_scene: PackedScene
var _embers: Array[ColorRect] = []
var _ember_speeds: Array[float] = []

@onready var _menu_box: CenterContainer = $Center
@onready var _play_button: Button = $Center/VBox/PlayButton
@onready var _overlay: Control = $LoadingOverlay
@onready var _hell_bg: ColorRect = $LoadingOverlay/HellBackground


func _ready() -> void:
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(false)
	_build_embers_once()
	_play_button.pressed.connect(_start_load)
	_play_button.grab_focus()


func _start_load() -> void:
	if _loading:
		return
	_loading = true
	_elapsed = 0.0
	_packed_scene = null
	_menu_box.visible = false
	_overlay.visible = true

	var err: Error = ResourceLoader.load_threaded_request(MAIN_SCENE_PATH)
	if err != OK:
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
		return
	set_process(true)


func _process(delta: float) -> void:
	if not _loading:
		return
	_elapsed += delta
	_animate_hell_fall(delta)

	if _packed_scene == null:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(
			MAIN_SCENE_PATH, _progress
		)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_packed_scene = ResourceLoader.load_threaded_get(MAIN_SCENE_PATH) as PackedScene
		elif (
			status == ResourceLoader.THREAD_LOAD_FAILED
			or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE
		):
			_loading = false
			set_process(false)
			push_error("PlayMenu: fallo al cargar %s" % MAIN_SCENE_PATH)
			return

	if _packed_scene != null and _elapsed >= MIN_ANIM_SECONDS:
		_loading = false
		set_process(false)
		get_tree().change_scene_to_packed(_packed_scene)


func _build_embers_once() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	for i: int in EMBER_COUNT:
		var ember := ColorRect.new()
		var is_gold: bool = (i % 3) == 0
		ember.color = Color(1.0, 0.78, 0.25, 0.95) if is_gold else Color(1.0, 0.28, 0.06, 0.90)
		var s: float = randf_range(3.0, 7.0)
		ember.size = Vector2(s, s)
		ember.position = Vector2(randf_range(0.0, vp_size.x), randf_range(0.0, vp_size.y))
		ember.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(ember)
		_embers.append(ember)
		_ember_speeds.append(randf_range(160.0, 320.0))


func _animate_hell_fall(delta: float) -> void:
	var mat := _hell_bg.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("scroll_time", _elapsed)

	var vp_size: Vector2 = get_viewport_rect().size
	for i: int in _embers.size():
		var ember: ColorRect = _embers[i]
		ember.position.y -= _ember_speeds[i] * delta
		ember.position.x += sin(_elapsed * 5.0 + float(i)) * 28.0 * delta
		if ember.position.y + ember.size.y < 0.0:
			ember.position.y = vp_size.y + randf_range(0.0, 30.0)
			ember.position.x = randf_range(0.0, vp_size.x)
