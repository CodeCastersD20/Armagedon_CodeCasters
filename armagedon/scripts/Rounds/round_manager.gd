class_name RoundManager
extends Node
## Máquina de estados del bucle de partida: ronda -> descanso -> siguiente ronda -> escape.
## Punto único de verdad de la ronda actual (GDD §3, issue #SIX SEVEN).

signal state_changed(new_state: State, old_state: State)
signal round_started(round_number: int, is_boss_round: bool)
signal round_ended(round_number: int, cleared_early: bool, time_remaining: float)
signal round_time_changed(seconds_left: float)
signal rest_started(round_number: int)
signal rest_ended(round_number: int)
signal escape_started(round_number: int)

enum State { IDLE, ROUND, REST, ESCAPE }

@export var config: RoundConfig
@export var auto_start: bool = false

var current_state: State = State.IDLE
var current_round: int = 0
var _round_time_left: float = 0.0
var _player: Player


func _ready() -> void:
	add_to_group("round_manager")
	if config == null:
		config = RoundConfig.new()
	_connect_player_escaped.call_deferred()
	if auto_start:
		start_game.call_deferred()


func _process(delta: float) -> void:
	if current_state != State.ROUND:
		return
	_round_time_left = maxf(_round_time_left - delta, 0.0)
	round_time_changed.emit(_round_time_left)
	if _round_time_left <= 0.0:
		end_round(false, 0.0)


func _connect_player_escaped() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player != null and not _player.player_escaped.is_connected(trigger_escape):
		_player.player_escaped.connect(trigger_escape)


func start_game() -> void:
	current_round = 1
	_round_time_left = maxf(config.round_duration, 0.0)
	_set_state(State.ROUND)
	round_started.emit(current_round, is_boss_round())
	round_time_changed.emit(_round_time_left)


func end_round(cleared_early: bool = false, time_remaining: float = -1.0) -> void:
	if current_state != State.ROUND:
		return
	var bonus_time: float = _round_time_left if time_remaining < 0.0 else time_remaining
	round_ended.emit(current_round, cleared_early, maxf(bonus_time, 0.0))
	_set_state(State.REST)
	rest_started.emit(current_round)


func start_next_round() -> void:
	if current_state != State.REST:
		return
	rest_ended.emit(current_round)
	current_round += 1
	_round_time_left = maxf(config.round_duration, 0.0)
	_set_state(State.ROUND)
	round_started.emit(current_round, is_boss_round())
	round_time_changed.emit(_round_time_left)


func trigger_escape() -> void:
	if current_state == State.ESCAPE or current_state == State.IDLE:
		return
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


func get_round_time_left() -> float:
	return _round_time_left


func is_boss_round(round_number: int = -1) -> bool:
	var target: int = current_round if round_number < 0 else round_number
	if target <= 0:
		return false
	var interval: int = maxi(config.boss_round_interval, 1)
	return target % interval == 0


func debug_next_round() -> void:
	if current_state == State.ROUND:
		end_round(true, _round_time_left)
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
	_round_time_left = 0.0
	_set_state(State.IDLE)
	round_time_changed.emit(0.0)
