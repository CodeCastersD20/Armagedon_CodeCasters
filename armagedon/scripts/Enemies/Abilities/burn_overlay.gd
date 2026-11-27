class_name BurnOverlay
extends CanvasLayer
## Efecto de pantalla (bordes en llamas) mientras el jugador está quemado. Un solo nodo compartido,
## creado al primer uso; no procesa nada cuando no hay quemadura.

const SHADER: Shader = preload("res://assets/shaders/burn_overlay.gdshader")
const FADE_IN_SPEED: float = 5.0
const FADE_OUT_SPEED: float = 2.5

static var _instance: BurnOverlay

var _material: ShaderMaterial
var _intensity: float = 0.0
var _hold: float = 0.0


## Mantiene el efecto activo `hold_seconds` más; llamar mientras dure la quemadura.
static func ping(tree: SceneTree, hold_seconds: float = 0.3) -> void:
	if tree == null or tree.current_scene == null:
		return
	if not is_instance_valid(_instance) or not _instance.is_inside_tree():
		_instance = BurnOverlay.new()
		_instance._build()
		tree.current_scene.add_child(_instance)
	_instance._hold = maxf(_instance._hold, hold_seconds)
	_instance.visible = true
	_instance.set_process(true)


func _build() -> void:
	layer = 60
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	rect.material = _material
	add_child(rect)
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	_hold -= delta
	var target: float = 1.0 if _hold > 0.0 else 0.0
	var speed: float = FADE_IN_SPEED if target > _intensity else FADE_OUT_SPEED
	_intensity = move_toward(_intensity, target, speed * delta)
	_material.set_shader_parameter("intensity", _intensity)
	if _intensity <= 0.0 and _hold <= 0.0:
		visible = false
		set_process(false)
