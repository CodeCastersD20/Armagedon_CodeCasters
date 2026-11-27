extends Node

var _wallet: ShardWallet

@onready var _label: Label = $Esquirlas


func _ready() -> void:
	_connect_wallet.call_deferred()


func _connect_wallet() -> void:
	_wallet = get_tree().get_first_node_in_group("economy") as ShardWallet
	if _wallet == null:
		push_error("ShardCounter: no hay wallet en la escena")
		return
	_wallet.shards_changed.connect(_on_shards_changed)
	_on_shards_changed(_wallet.get_shards())


func _on_shards_changed(current: int) -> void:
	var text: String = "Esquirlas: %d" % current
	if _label.text != text:
		_label.text = text
