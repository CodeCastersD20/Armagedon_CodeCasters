extends Node
## Contador provisional de vida con cuenta regresiva a la próxima regeneración.
## El HUD real llega con #88.

var _player: Player

@onready var _label: Label = $Vida


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var text: String = (
		"Vida: %d / %d" % [ceili(_player.get_health()), int(_player.stats.max_health)]
	)
	var seconds_left: float = _player.get_regen_seconds_left()
	if seconds_left > 0.0:
		text += "  (+%d en %.1f s)" % [int(_player.stats.regen_amount), seconds_left]
	# Solo se reasigna si cambió: evita re-maquetar el Label en cada frame.
	if _label.text != text:
		_label.text = text
