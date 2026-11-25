extends Node

## Señal principal para el HUD y la tienda: emite el saldo actual y el cambio (+ o -)
signal balance_changed(new_balance: int, delta: int)
signal currency_spent(amount: int)

const DEFAULT_CONFIG_PATH := "res://data/upgrades/currency_config.tres"

var config: CurrencyData
var balance: int = 0

func _ready() -> void:
	if ResourceLoader.exists(DEFAULT_CONFIG_PATH):
		config = load(DEFAULT_CONFIG_PATH) as CurrencyData
	else:
		config = CurrencyData.new()
	reset_balance()

func get_currency_name() -> String:
	return config.nombre if config else "Esquirlas de Alma"

func add(amount: int) -> void:
	if amount <= 0:
		return
	balance += amount
	balance_changed.emit(balance, amount)

func can_afford(cost: int) -> bool:
	return cost >= 0 and balance >= cost

func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	balance -= cost
	currency_spent.emit(cost)
	balance_changed.emit(balance, -cost)
	return true

## Llamar al iniciar una nueva partida o al morir (sin progreso entre partidas)
func reset_balance() -> void:
	var initial := config.saldo_inicial if config else 0
	var delta := initial - balance
	balance = initial
	balance_changed.emit(balance, delta)
