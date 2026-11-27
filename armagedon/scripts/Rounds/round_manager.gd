class_name RoundManager
extends Node
## Máquina de estados del bucle de partida: ronda -> descanso -> siguiente ronda -> escape.
## Punto único de verdad de la ronda actual y su cronómetro ascendente (GDD §3, §16).

signal state_changed(new_state: State, old_state: State)
signal round_started(round_number: int, is_boss_round: bool)
signal round_ended(round_number: int, elapsed_time: float, bonus_score: int, bonus_shards: int)
signal round_time_changed(elapsed_seconds: float)
signal rest_time_changed(remaining_seconds: float)
signal rest_started(round_number: int)
signal rest_ended(round_number: int)
signal escape_started(round_number: int)

enum State { IDLE, ROUND, REST, ESCAPE }

@export var config: RoundConfig
@export var auto_start: bool = false

var current_state: State = State.IDLE
var current_round: int = 0
var _round_elapsed: float = 0.0
var _rest_time_left: float = 0.0
var _player: Player


func _ready() -> void:
	add_to_group("round_manager")
	if config == null:
		config = RoundConfig.new()
	_connect_player_escaped.call_deferred()
	if auto_start:
		start_game.call_deferred()


func _process(delta: float) -> void:
	if current_state == State.REST:
		_rest_time_left = maxf(_rest_time_left - delta, 0.0)
		rest_time_changed.emit(_rest_time_left)
		if _rest_time_left <= 0.0:
			start_next_round()
		return
	if current_state != State.ROUND:
		return
	_round_elapsed += delta
	round_time_changed.emit(_round_elapsed)


func _connect_player_escaped() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.player_escaped.is_connected(trigger_escape):
		_player.player_escaped.connect(trigger_escape)


func start_game() -> void:
	current_round = 1
	_round_elapsed = 0.0
	_rest_time_left = 0.0
	_set_state(State.ROUND)
	round_started.emit(current_round, is_boss_round())
	round_time_changed.emit(_round_elapsed)


func end_round(elapsed_override: float = -1.0) -> void:
	if current_state != State.ROUND:
		return
	var elapsed: float = _round_elapsed if elapsed_override < 0.0 else maxf(elapsed_override, 0.0)
	var rewards: Dictionary = calculate_round_rewards(elapsed)
	round_ended.emit(current_round, elapsed, rewards["score"], rewards["shards"])
	_rest_time_left = maxf(config.rest_duration, 0.0)
	_set_state(State.REST)
	rest_started.emit(current_round)
	rest_time_changed.emit(_rest_time_left)


func start_next_round() -> void:
	if current_state != State.REST:
		return
	rest_ended.emit(current_round)
	current_round += 1
	_round_elapsed = 0.0
	_rest_time_left = 0.0
	_set_state(State.ROUND)
	round_started.emit(current_round, is_boss_round())
	round_time_changed.emit(_round_elapsed)


func trigger_escape() -> void:
	if current_state == State.ESCAPE or current_state == State.IDLE:
		return
	_rest_time_left = 0.0
	_set_state(State.ESCAPE)
	escape_started.emit(current_round)


func get_state() -> State:
	return current_state


func get_state_name() -> String:
	match current_state:
		State.ROUND:
			return "RONDA"
		State.REST:
			return "DESCANSO"
		State.ESCAPE:
			return "ESCAPE"
		_:
			return "INICIO"


func get_current_round() -> int:
	return current_round


func get_round_elapsed_time() -> float:
	return _round_elapsed


func get_rest_time_left() -> float:
	return _rest_time_left


## Factor de recompensa (0..1) inversamente proporcional al tiempo tardado, con piso mínimo.
func get_time_reward_factor(elapsed_seconds: float = -1.0) -> float:
	var t: float = _round_elapsed if elapsed_seconds < 0.0 else maxf(elapsed_seconds, 0.0)
	var ref_time: float = maxf(config.reward_reference_time, 0.01)
	var min_factor: float = clampf(config.min_time_reward_factor, 0.0, 1.0)
	var raw_factor: float = ref_time / (ref_time + t)
	return maxf(min_factor, raw_factor)


## Calcula el Score y Esquirlas fijas moduladas por el cronómetro de la ronda.
func calculate_round_rewards(elapsed_seconds: float = -1.0) -> Dictionary:
	var factor: float = get_time_reward_factor(elapsed_seconds)
	var score: int = maxi(roundi(float(config.base_round_score) * factor), 0)
	var shards: int = maxi(roundi(float(config.base_round_shards) * factor), 0)
	return {"score": score, "shards": shards, "factor": factor}


func is_boss_round(round_number: int = -1) -> bool:
	var target: int = current_round if round_number < 0 else round_number
	if target <= 0:
		return false
	var interval: int = maxi(config.boss_round_interval, 1)
	return target % interval == 0


func debug_next_round() -> void:
	if current_state == State.ROUND:
		end_round(_round_elapsed)
	elif current_state == State.REST:
		start_next_round()
	elif current_state == State.IDLE:
		start_game()


func _set_state(new_state: State) -> void:
	if new_state == current_state:
		return
	var old_state: State = current_state
	current_state = new_state
	state_changed.emit(new_state, old_state)


## Vuelve el RoundManager a IDLE al regresar al menú Play.
func reset_to_idle() -> void:
	current_round = 0
	_round_elapsed = 0.0
	_rest_time_left = 0.0
	_set_state(State.IDLE)
	round_time_changed.emit(0.0)
