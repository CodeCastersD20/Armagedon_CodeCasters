extends Node
## Contador provisional de vida. El HUD real llega con #88.

var _player: Player

@onready var _label: Label = $Vida


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var text: String = LocalizationManager.tf(
		"health.label", [ceili(_player.get_health()), int(_player.stats.max_health)]
	)
	# Solo se reasigna si cambió: evita re-maquetar el Label en cada frame.
	if _label.text != text:
		_label.text = text
