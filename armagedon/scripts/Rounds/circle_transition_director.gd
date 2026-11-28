class_name CircleTransitionDirector
extends Node
## Orquesta el paso al siguiente círculo tras vencer al jefe (GDD §2.2):
## jefe muere → respiro para recoger drops → Sello del Jefe → transición elegida en
## data/rounds/circle_transition_config.tres → descanso en el nuevo círculo.

signal seal_broken

const DEFAULT_CONFIG: CircleTransitionConfig = preload(
	"res://data/rounds/circle_transition_config.tres"
)

@export var config: CircleTransitionConfig

var _round_manager: RoundManager
var _boss_spawner: Node
var _ctx: CircleTransitionContext
var _transition: CircleTransition
var _seal: CircleSeal
var _active: bool = false
var _waiting_seal: bool = false
var _run_id: int = 0


func _ready() -> void:
	add_to_group("circle_transition_director")
	if config == null:
		config = DEFAULT_CONFIG
	set_process(false)
	_connect_signals.call_deferred()


func _connect_signals() -> void:
	_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	_boss_spawner = get_tree().get_first_node_in_group("boss_spawner")
	if _round_manager == null:
		push_error("CircleTransitionDirector sin RoundManager")
		return
	_round_manager.escape_started.connect(_on_interrupted)
	_round_manager.state_changed.connect(_on_state_changed)
	if _boss_spawner != null and _boss_spawner.has_signal("boss_died"):
		_boss_spawner.connect("boss_died", _on_boss_died)


func is_active() -> bool:
	return _active


func get_selected() -> CircleTransitionData:
	return config.selected if config != null else null


## Menú debug: cambia la transición en esta partida (no guarda el .tres).
func set_selected(data: CircleTransitionData) -> void:
	if config != null and data != null:
		config.selected = data


## Menú debug: lanza la transición ya, sin jefe y sin respiro.
func debug_start_now() -> void:
	if not OS.is_debug_build():
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var spot: Vector3 = Vector3.ZERO
	if player != null:
		spot = player.global_position - player.global_basis.z * 4.0
	_start(spot, true)


func _on_boss_died(enemy: Node) -> void:
	var spot: Vector3 = (enemy as Node3D).global_position if enemy is Node3D else Vector3.ZERO
	if config == null or not config.enabled or config.selected == null:
		if _round_manager != null:
			_round_manager.end_round()
		return
	_start(spot, false)


func _start(boss_position: Vector3, from_debug: bool) -> void:
	if _active or _round_manager == null or config == null or config.selected == null:
		return
	if not _round_manager.begin_transition(from_debug):
		return
	_active = true
	_run_id += 1
	_run(boss_position, from_debug, _run_id)


func _run(boss_position: Vector3, skip_breather: bool, run_id: int) -> void:
	var data: CircleTransitionData = config.selected
	_ctx = CircleTransitionContext.new()
	if not _ctx.setup(get_tree(), boss_position):
		_finish(run_id)
		return
	var instance: Object = data.transition_script.new() if data.transition_script else null
	_transition = instance as CircleTransition
	if _transition == null:
		push_error("CircleTransitionData '%s' sin un CircleTransition válido" % data.display_name)
		_finish(run_id)
		return
	_transition.name = "CircleTransition"
	_transition.setup(_ctx, data)
	_ctx.scene_root.add_child(_transition)
	DebugLogger.write("TRANSITION", "inicio %s ronda=%d" % [data.display_name, _ctx.boss_round])
	if not skip_breather and data.breather_seconds > 0.0:
		await get_tree().create_timer(data.breather_seconds).timeout
		if run_id != _run_id:
			return
	await _transition.prepare()
	if run_id != _run_id:
		return
	if data.require_interaction:
		_seal = CircleSeal.new()
		_ctx.scene_root.add_child(_seal)
		_seal.global_position = _transition.get_seal_position()
		_waiting_seal = true
		set_process(true)
		DebugLogger.write("TRANSITION", "sello en %s" % str(_seal.global_position))
		await seal_broken
		if run_id != _run_id:
			return
	DebugLogger.write("TRANSITION", "viaje %s" % data.display_name)
	await _transition.play()
	if run_id != _run_id:
		return
	_finish(run_id)


func _process(_delta: float) -> void:
	if not _waiting_seal or _seal == null or _ctx == null:
		set_process(false)
		return
	var to_seal: Vector3 = _seal.global_position - _ctx.player.global_position
	to_seal.y = 0.0
	var near: bool = to_seal.length() <= config.selected.interact_distance
	_seal.set_prompt_visible(near)
	if near and Input.is_action_just_pressed("interact"):
		_waiting_seal = false
		set_process(false)
		var run_id: int = _run_id
		await _seal.break_open()
		if run_id == _run_id and is_inside_tree():
			seal_broken.emit()


func _finish(run_id: int) -> void:
	if run_id != _run_id:
		return
	_cleanup()
	DebugLogger.write("TRANSITION", "fin → descanso")
	if _round_manager != null and _round_manager.get_state() == RoundManager.State.TRANSITION:
		_round_manager.end_round()


func _cleanup() -> void:
	_active = false
	_waiting_seal = false
	set_process(false)
	if is_instance_valid(_seal):
		_seal.queue_free()
	_seal = null
	if is_instance_valid(_transition):
		_transition.queue_free()
	_transition = null


## Escape o vuelta al menú en plena transición: se corta y se deja todo como estaba.
func _on_interrupted(_round_number: int = 0) -> void:
	if not _active:
		return
	_run_id += 1
	if is_instance_valid(_transition):
		_transition.cancel()
	_cleanup()
	DebugLogger.write("TRANSITION", "cancelada")


func _on_state_changed(new_state: RoundManager.State, _old_state: RoundManager.State) -> void:
	if new_state == RoundManager.State.IDLE:
		_on_interrupted()
