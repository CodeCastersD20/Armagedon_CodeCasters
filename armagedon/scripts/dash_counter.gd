extends Node
## Contador provisional de cargas de dash con cuenta regresiva a la próxima carga.
## El HUD real llega con #88.

var _player: Player

@onready var _label: Label = $Label


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player") as Player
	_player.stamina_changed.connect(_on_stamina_changed)
	_on_stamina_changed(_player.get_charges(), _player.stats.stamina)


func _on_stamina_changed(current: float, maximum: float) -> void:
	var text: String = "Dash: %d / %d" % [floori(current), int(maximum)]
	if current < maximum:
		var seconds_left: float = (floorf(current) + 1.0 - current) * _player.stats.dash_recharge_seconds
		text += "  (%.1f s)" % seconds_left
	_label.text = text
