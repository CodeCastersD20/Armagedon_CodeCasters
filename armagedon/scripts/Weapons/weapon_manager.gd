class_name WeaponManager
extends Node3D
## Lleva un arma de fuego y una melee; solo una equipada. Q o rueda del mouse alternan.

signal weapon_changed(weapon: Weapon)
signal ammo_changed(current: int, magazine: int)
signal reload_started(seconds: float)
signal reload_finished

@export var fire_data: WeaponData
@export var melee_data: WeaponData
## GDD §5: el arma inicial es espada + escudo.
@export var start_with_melee: bool = true

var _fire: Weapon
var _melee: Weapon
var _current: Weapon


func _ready() -> void:
	add_to_group("weapon_manager")
	_fire = _spawn(fire_data)
	_melee = _spawn(melee_data)
	var first: Weapon = _melee if start_with_melee else _fire
	_equip(first if first != null else (_fire if _melee == null else _melee))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_weapon"):
		switch_weapon()
	elif event.is_action_pressed("reload") and _current != null:
		_current.try_reload()
	elif event.is_action_pressed("attack") and _current != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_current.try_attack()


func _process(_delta: float) -> void:
	if _current == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if _current.data.automatic and Input.is_action_pressed("attack"):
		_current.try_attack()


func get_current_weapon() -> Weapon:
	return _current


func switch_weapon() -> void:
	var other: Weapon = _melee if _current == _fire else _fire
	if other != null:
		_equip(other)


## Reemplaza el arma del mismo tipo (tienda en el descanso).
func replace_weapon(data: WeaponData) -> void:
	var is_fire: bool = data.kind == WeaponData.Kind.FIRE
	var old: Weapon = _fire if is_fire else _melee
	var new_weapon: Weapon = _spawn(data)
	if is_fire:
		_fire = new_weapon
	else:
		_melee = new_weapon
	var was_equipped: bool = _current == null or _current == old
	if old != null:
		if old == _current:
			_current = null
		old.queue_free()
	if was_equipped:
		_equip(new_weapon)


func _spawn(data: WeaponData) -> Weapon:
	if data == null:
		return null
	var weapon: Weapon
	if data.weapon_scene != null:
		weapon = data.weapon_scene.instantiate() as Weapon
	else:
		weapon = Weapon.new()
	weapon.data = data
	weapon.name = data.display_name if data.display_name != "" else "Weapon"
	weapon.ammo_changed.connect(_on_weapon_ammo_changed.bind(weapon))
	weapon.reload_started.connect(_on_weapon_reload_started.bind(weapon))
	weapon.reload_finished.connect(_on_weapon_reload_finished.bind(weapon))
	_set_active(weapon, false)
	add_child(weapon)
	return weapon


func _equip(weapon: Weapon) -> void:
	if weapon == null:
		return
	if _current != null:
		_current.cancel_reload()
		_set_active(_current, false)
	_current = weapon
	_set_active(_current, true)
	weapon_changed.emit(_current)
	ammo_changed.emit(_current.get_ammo(), _current.data.magazine_size)


func _set_active(weapon: Weapon, active: bool) -> void:
	weapon.visible = active
	weapon.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func _on_weapon_ammo_changed(current: int, magazine: int, weapon: Weapon) -> void:
	if weapon == _current:
		ammo_changed.emit(current, magazine)


func _on_weapon_reload_started(seconds: float, weapon: Weapon) -> void:
	if weapon == _current:
		reload_started.emit(seconds)


func _on_weapon_reload_finished(weapon: Weapon) -> void:
	if weapon == _current:
		reload_finished.emit()
