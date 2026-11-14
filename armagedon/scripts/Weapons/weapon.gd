class_name Weapon
extends Node3D
## Base de todas las armas: cadencia, cargador y recarga.
## Cada arma concreta sobrescribe _perform_attack() (disparo #44, espada #41).

signal attacked
signal ammo_changed(current: int, magazine: int)
signal reload_started(seconds: float)
signal reload_finished

@export var data: WeaponData

var _ammo: int = 0
var _cooldown: float = 0.0
var _reload_left: float = 0.0


func _ready() -> void:
	if data == null:
		push_error("Weapon sin WeaponData: %s" % name)
		return
	_ammo = data.magazine_size
	if data.mesh != null:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = data.mesh
		add_child(mesh_instance)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_reload_left = 0.0
			_ammo = data.magazine_size
			reload_finished.emit()
			ammo_changed.emit(_ammo, data.magazine_size)


func is_melee() -> bool:
	return data.kind == WeaponData.Kind.MELEE


func uses_magazine() -> bool:
	return data.magazine_size > 0


func is_reloading() -> bool:
	return _reload_left > 0.0


func get_ammo() -> int:
	return _ammo


## Ataca si la cadencia y el cargador lo permiten. Con el cargador vacío empieza a recargar.
func try_attack() -> bool:
	if _cooldown > 0.0 or is_reloading():
		return false
	if uses_magazine() and _ammo <= 0:
		try_reload()
		return false
	_cooldown = data.attack_interval
	if uses_magazine():
		_ammo -= 1
		ammo_changed.emit(_ammo, data.magazine_size)
	_perform_attack()
	attacked.emit()
	return true


func try_reload() -> bool:
	if not uses_magazine() or is_reloading() or _ammo >= data.magazine_size:
		return false
	_reload_left = data.reload_seconds
	reload_started.emit(data.reload_seconds)
	return true


## Al guardar el arma se cancela la recarga.
func cancel_reload() -> void:
	_reload_left = 0.0


## Lo sobrescribe cada arma concreta.
func _perform_attack() -> void:
	pass
