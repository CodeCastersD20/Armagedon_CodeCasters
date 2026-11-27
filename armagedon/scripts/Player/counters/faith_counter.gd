extends Node

var _player: Player

@onready var _label: Label = $Fe


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		push_error("FaithCounter: no hay jugador en la escena")
		return
	_player.faith_changed.connect(_on_faith_changed)
	_on_faith_changed(_player.get_faith(), _player.stats.max_faith)


func _on_faith_changed(current: float, maximum: float) -> void:
	var text: String = "Fe: %d / %d" % [floori(current), int(maximum)]
	if _label.text != text:
		_label.text = text
