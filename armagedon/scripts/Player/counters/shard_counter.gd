extends Node
## Contador de Esquirlas de Alma en el HUD conectado directamente a CurrencyManager.

@onready var _label: Label = $Esquirlas


func _ready() -> void:
	if not CurrencyManager.balance_changed.is_connected(_on_balance_changed):
		CurrencyManager.balance_changed.connect(_on_balance_changed)
	_on_balance_changed(CurrencyManager.balance, 0)


func _exit_tree() -> void:
	if CurrencyManager.balance_changed.is_connected(_on_balance_changed):
		CurrencyManager.balance_changed.disconnect(_on_balance_changed)


func _on_balance_changed(new_balance: int, _delta: int) -> void:
	var text: String = "Esquirlas: %d" % new_balance
	if _label.text != text:
		_label.text = text
