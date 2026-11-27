extends Node
## Contador provisional de ronda, fase y cronómetro ascendente.
## El HUD real llega con #89.

var _round_manager: RoundManager
var _last_second: int = -1

@onready var _label: Label = $Round


func _ready() -> void:
	_connect_round_manager.call_deferred()


func _connect_round_manager() -> void:
	_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _round_manager == null:
		return
	_round_manager.state_changed.connect(_on_state_changed)
	_round_manager.round_started.connect(_on_round_started)
	_round_manager.round_time_changed.connect(_on_time_changed)
	_round_manager.rest_time_changed.connect(_on_time_changed)
	_update_text()


func _on_state_changed(_new_state: RoundManager.State, _old_state: RoundManager.State) -> void:
	_last_second = -1
	_update_text()


func _on_round_started(_round_number: int, _is_boss: bool) -> void:
	_last_second = -1
	_update_text()


func _on_time_changed(seconds: float) -> void:
	var is_rest: bool = _round_manager.get_state() == RoundManager.State.REST
	var whole_seconds: int = ceili(maxf(seconds, 0.0)) if is_rest else floori(maxf(seconds, 0.0))
	if whole_seconds == _last_second:
		return
	_last_second = whole_seconds
	_update_text()


func _update_text() -> void:
	if _round_manager == null:
		return
	var is_rest: bool = _round_manager.get_state() == RoundManager.State.REST
	var total: int = (
		maxi(ceili(_round_manager.get_rest_time_left()), 0)
		if is_rest
		else maxi(floori(_round_manager.get_round_elapsed_time()), 0)
	)
	var mins: int = floori(float(total) / 60.0)
	var secs: int = total % 60
	var round_num: int = _round_manager.get_current_round()
	var state_name: String = _round_manager.get_state_name()
	_label.text = "Ronda: %d | %s | %02d:%02d" % [round_num, state_name, mins, secs]
