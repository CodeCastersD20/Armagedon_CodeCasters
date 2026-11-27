class_name WeaponManager
extends Node3D
## Lleva un arma de fuego y una melee; solo una equipada. Q o rueda del mouse alternan.

signal weapon_changed(weapon: Weapon)
signal ammo_changed(current: int, magazine: int)
signal reload_started(seconds: float)
signal reload_finished

const SWITCH_DROP_SECONDS: float = 0.07
const SWITCH_DRAW_SECONDS: float = 0.16
const SWITCH_OFFSET: Vector3 = Vector3(0.06, -0.34, 0.08)
const SWITCH_ROTATION_DEG: Vector3 = Vector3(-26.0, 8.0, -12.0)

@export var fire_data: WeaponData
@export var melee_data: WeaponData
## Tercera arma provisional (solo para verla; se cambia con Q/rueda).
@export var extra_data: WeaponData
## Cuarta arma provisional (solo para verla).
@export var extra2_data: WeaponData
## GDD §5: el arma inicial es espada + escudo.
@export var start_with_melee: bool = true

var _fire: Weapon
var _melee: Weapon
var _extra: Weapon
var _extra2: Weapon
var _current: Weapon
var _player: Player
var _switch_tween: Tween
var _switch_id: int = 0


func _ready() -> void:
	add_to_group("weapon_manager")
	_fire = _spawn(fire_data)
	_melee = _spawn(melee_data)
	_extra = _spawn(extra_data)
	_extra2 = _spawn(extra2_data)
	var first: Weapon = _melee if start_with_melee else _fire
	_equip(first if first != null else (_fire if _melee == null else _melee))
	_prewarm_inactive.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("switch_weapon"):
		switch_weapon()
	elif event.is_action_pressed("reload") and _current != null:
		_current.try_reload()
	elif event.is_action_pressed("attack") and _can_attack():
		_current.try_attack()
	elif event.is_action_pressed("ability") and _can_attack():
		_current.try_ability()


func _process(_delta: float) -> void:
	if _current == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if _current.data.automatic and Input.is_action_pressed("attack") and _can_attack():
		_current.try_attack()


## No se ataca con el cursor suelto ni con la espada mientras se cubre con el escudo.
func _can_attack() -> bool:
	if _current == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return false
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	return not (_player != null and (_player.is_blocking() or _player.is_stunned()))


func get_current_weapon() -> Weapon:
	return _current


func switch_weapon() -> void:
	var order: Array[Weapon] = []
	for weapon: Weapon in [_fire, _melee, _extra, _extra2]:
		if weapon != null:
			order.append(weapon)
	if order.size() < 2:
		return
	var idx: int = order.find(_current)
	_play_switch_to(order[(idx + 1) % order.size()])


func _play_switch_to(target: Weapon) -> void:
	_switch_id += 1
	var req_id: int = _switch_id
	if _switch_tween != null and _switch_tween.is_valid():
		_switch_tween.kill()
	if _current == null:
		_equip(target)
		_animate_draw()
		return
	_current.cancel_reload()
	_switch_tween = create_tween()
	_switch_tween.set_parallel(true)
	(
		_switch_tween
		. tween_property(self, "position", SWITCH_OFFSET, SWITCH_DROP_SECONDS)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)
	(
		_switch_tween
		. tween_property(self, "rotation_degrees", SWITCH_ROTATION_DEG, SWITCH_DROP_SECONDS)
		. set_ease(Tween.EASE_IN)
		. set_trans(Tween.TRANS_QUAD)
	)
	_switch_tween.chain().tween_callback(
		func() -> void:
			if req_id != _switch_id or not is_inside_tree():
				return
			_equip(target)
			_animate_draw()
	)


func _animate_draw() -> void:
	if _switch_tween != null and _switch_tween.is_valid():
		_switch_tween.kill()
	position = SWITCH_OFFSET
	rotation_degrees = SWITCH_ROTATION_DEG
	_switch_tween = create_tween()
	_switch_tween.set_parallel(true)
	(
		_switch_tween
		. tween_property(self, "position", Vector3.ZERO, SWITCH_DRAW_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)
	(
		_switch_tween
		. tween_property(self, "rotation_degrees", Vector3.ZERO, SWITCH_DRAW_SECONDS)
		. set_ease(Tween.EASE_OUT)
		. set_trans(Tween.TRANS_BACK)
	)


## Reemplaza el arma del mismo tipo (tienda en el descanso).
func replace_weapon(data: WeaponData) -> void:
	if data == null:
		push_error("replace_weapon recibió WeaponData nulo")
		return
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
	var weapon: Weapon = null
	if data.weapon_scene != null:
		var instance: Node = data.weapon_scene.instantiate()
		weapon = instance as Weapon
		if weapon == null:
			# La raíz de la escena no es un Weapon: se descarta y se usa el arma base.
			push_error("weapon_scene de %s no hereda de Weapon" % data.display_name)
			instance.free()
	if weapon == null:
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


## Al iniciar muestra el arma guardada y dibuja cada efecto (trazador, impacto, estela, números)
## unos fotogramas, para que sus mallas, materiales y fuentes se compilen ahora y no en el primer
## uso en pleno combate.
func _prewarm_inactive() -> void:
	DamageNumber.prewarm(get_tree())
	for weapon: Weapon in [_fire, _melee]:
		if weapon != null:
			weapon.prewarm()
	var other: Weapon = _melee if _current == _fire else _fire
	if other == null or other == _current:
		return
	other.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(other) and other != _current:
		other.visible = false


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
