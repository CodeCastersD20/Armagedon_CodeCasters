extends Node

signal offer_generated(always_items: Array[Resource], random_items: Array[Resource])
signal item_purchased(item: Resource, new_level: int)
signal shop_state_reset

const UPGRADES_DIR := "res://data/upgrades/"
const FAITH_POWERS_DIR := "res://data/faith_powers/"
const WEAPONS_DIR := "res://data/weapons/"

var always_pool: Array[UpgradeData] = []
var random_pool: Array[Resource] = []

## Registro de niveles comprados en la partida actual: { id: nivel_actual }
var purchased_levels: Dictionary = {}

## Oferta actual generada para el descanso
var current_always_offers: Array[Resource] = []
var current_random_offers: Array[Resource] = []

func _ready() -> void:
	_load_all_shop_data()

	# PRUEBA TEMPORAL #77 (borrar antes de commit)
	var oferta := roll_offers(4)
	print("--- SIEMPRE ---")
	for a in oferta["always"]:
		print("  * ", a.nombre)
	print("--- 4 SORTEADAS ---")
	for r in oferta["random"]:
		print("  * ", r.nombre)

func _load_all_shop_data() -> void:
	always_pool.clear()
	random_pool.clear()

	# 1. Cargar Upgrades (filtrando currency_config.tres)
	for res in _load_resources_from_dir(UPGRADES_DIR):
		if res is UpgradeData:
			if res.categoria == UpgradeData.Category.SIEMPRE:
				always_pool.append(res)
			else:
				random_pool.append(res)

	# 2. Cargar Poderes de Fe
	for res in _load_resources_from_dir(FAITH_POWERS_DIR):
		if res is FaithPowerData:
			random_pool.append(res)

	# 3. Cargar Armas de tienda
	for res in _load_resources_from_dir(WEAPONS_DIR):
		if res is ShopWeaponData:
			random_pool.append(res)

func _load_resources_from_dir(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("ShopManager: no se pudo abrir %s" % dir_path)
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res := load(dir_path + file_name)
			if res != null:
				result.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

## Genera la oferta de la tienda: siempre Vida y Fe + 4 opciones aleatorias válidas
func roll_offers(random_count: int = 4) -> Dictionary:
	current_always_offers.clear()
	current_random_offers.clear()

	# Siempre Vida y Fe
	for item in always_pool:
		current_always_offers.append(item)

	# Filtrar pool aleatorio excluyendo los que ya llegaron a nivel máximo
	var eligible: Array[Resource] = []
	for item in random_pool:
		if not is_max_level(item):
			eligible.append(item)

	# Barajar y tomar hasta 4 sin repetir
	eligible.shuffle()
	var count := mini(random_count, eligible.size())
	for i in range(count):
		current_random_offers.append(eligible[i])

	offer_generated.emit(current_always_offers, current_random_offers)
	return {
		"always": current_always_offers,
		"random": current_random_offers
	}

func get_item_id(item: Resource) -> StringName:
	if item is UpgradeData or item is FaithPowerData or item is ShopWeaponData:
		return item.id
	return &""

func get_item_level(item: Resource) -> int:
	var id := get_item_id(item)
	return int(purchased_levels.get(id, 0))

func is_max_level(item: Resource) -> bool:
	var current := get_item_level(item)
	if item is UpgradeData:
		return item.nivel_maximo > 0 and current >= item.nivel_maximo
	if item is FaithPowerData:
		return item.nivel_maximo > 0 and current >= item.nivel_maximo
	# Las armas se pueden volver a ofrecer para reemplazar la equipada
	return false

func register_purchase(item: Resource) -> int:
	var id := get_item_id(item)
	if id == &"":
		return 0
	var new_level := get_item_level(item) + 1
	purchased_levels[id] = new_level
	item_purchased.emit(item, new_level)
	return new_level

## Llamar al iniciar una nueva partida
func reset_shop_state() -> void:
	purchased_levels.clear()
	current_always_offers.clear()
	current_random_offers.clear()
	shop_state_reset.emit()
