class_name ShardWallet
extends Node
## Saldo de Esquirlas de Alma de la partida. #76 añadirá el gasto y el HUD.

signal shards_changed(current: int)

@export var starting_shards: int = 0

var _shards: int = 0


func _ready() -> void:
	add_to_group("economy")
	reset()


func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	_shards += amount
	shards_changed.emit(_shards)


func get_shards() -> int:
	return _shards


func reset() -> void:
	_shards = maxi(starting_shards, 0)
	shards_changed.emit(_shards)
