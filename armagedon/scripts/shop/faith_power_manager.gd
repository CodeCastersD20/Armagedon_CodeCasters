class_name FaithPowerManager
extends Node
## Gestiona los Poderes de Fe desbloqueados en la tienda, sus slots 1-4, cooldowns y efectos (#80).

signal slots_updated(slots: Array[Dictionary])
signal cooldown_updated(
	slot_index: int, remaining: float, duration: float, active_remaining: float
)
signal power_activated(slot_index: int, power: FaithPowerData, level: int)

const SLOT_COUNT: int = 4
const SLOT_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]
const ID_BOLA_DE_FUEGO: StringName = &"bola_de_fuego"
const ID_CURACION_PASIVA: StringName = &"curacion_pasiva"
const ID_DANO_EXTRA_ARMA: StringName = &"dano_extra_arma"
const FIREBALL_SPEED: float = 28.0
const FIREBALL_LIFETIME: float = 3.0
const FIREBALL_RADIUS: float = 0.28
const FIREBALL_SPAWN_OFFSET: float = 0.85
const FIREBALL_INITIAL_POOL: int = 4
const FIREBALL_COLLISION_MASK: int = 7
const DEFAULT_HEAL_DURATION: float = 5.0
const DEFAULT_DAMAGE_BUFF_DURATION: float = 8.0

## Recursos compartidos de la bola de fuego (creados una sola vez, sin new() por disparo).
static var _fireball_mesh: SphereMesh
static var _fireball_material: StandardMaterial3D
static var _fireball_shape: SphereShape3D

var _slots: Array[FaithPowerData] = []
var _levels: Array[int] = []
var _cooldowns: Array[float] = []
var _active_timers: Array[float] = []
var _last_cd_tenths: Array[int] = []
var _last_active_tenths: Array[int] = []

var _heal_per_second: float = 0.0
var _heal_time_left: float = 0.0
var _heal_slot_index: int = -1

var _damage_buff_amount: float = 0.0
var _damage_buff_time_left: float = 0.0
var _damage_buff_slot_index: int = -1

var _fireball_pool: Array[Area3D] = []
var _active_fireballs: Array[Dictionary] = []

var _player: Player
var _shop_ui: ShopUI
var _upgrade_applier: UpgradeApplier


func _ready() -> void:
	add_to_group("faith_power_manager")
	_init_slots()
	_init_fireball_pool()
	set_process(false)
	set_physics_process(false)
	if not ShopManager.item_purchased.is_connected(_on_item_purchased):
		ShopManager.item_purchased.connect(_on_item_purchased)
	if not ShopManager.shop_state_reset.is_connected(reset_powers):
		ShopManager.shop_state_reset.connect(reset_powers)
	_bind_gameplay_nodes.call_deferred()


func _exit_tree() -> void:
	if ShopManager.item_purchased.is_connected(_on_item_purchased):
		ShopManager.item_purchased.disconnect(_on_item_purchased)
	if ShopManager.shop_state_reset.is_connected(reset_powers):
		ShopManager.shop_state_reset.disconnect(reset_powers)
	_clear_damage_buff()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var slot_index: int = SLOT_KEYS.find(key_event.keycode)
	if slot_index < 0:
		return
	if get_tree().paused or _is_shop_open():
		return
	_resolve_refs()
	if _player == null or not _player.is_physics_processing():
		return
	if _slots[slot_index] == null:
		return
	try_activate_slot(slot_index)
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var any_running: bool = false

	if _heal_time_left > 0.0:
		_heal_time_left = maxf(_heal_time_left - delta, 0.0)
		if _player != null and is_instance_valid(_player) and _heal_per_second > 0.0:
			_player.heal(_heal_per_second * delta)
		if _heal_slot_index >= 0 and _heal_slot_index < SLOT_COUNT:
			_active_timers[_heal_slot_index] = _heal_time_left
		if _heal_time_left <= 0.0:
			_heal_per_second = 0.0
			_heal_slot_index = -1
		else:
			any_running = true

	if _damage_buff_time_left > 0.0:
		_damage_buff_time_left = maxf(_damage_buff_time_left - delta, 0.0)
		if _damage_buff_slot_index >= 0 and _damage_buff_slot_index < SLOT_COUNT:
			_active_timers[_damage_buff_slot_index] = _damage_buff_time_left
		if _damage_buff_time_left <= 0.0:
			_clear_damage_buff()
		else:
			any_running = true

	for i: int in SLOT_COUNT:
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
			if _cooldowns[i] > 0.0:
				any_running = true
		_emit_slot_timer_if_changed(i)

	if not any_running:
		set_process(false)


func _physics_process(delta: float) -> void:
	if _active_fireballs.is_empty():
		set_physics_process(false)
		return
	for i: int in range(_active_fireballs.size() - 1, -1, -1):
		var entry: Dictionary = _active_fireballs[i]
		var area := entry["area"] as Area3D
		if area == null or not is_instance_valid(area):
			_active_fireballs.remove_at(i)
			continue
		var velocity: Vector3 = entry["velocity"]
		area.global_position += velocity * delta
		var time_left: float = float(entry["time_left"]) - delta
		entry["time_left"] = time_left
		if time_left <= 0.0:
			_recycle_fireball_at(i)
	if _active_fireballs.is_empty():
		set_physics_process(false)


## Intenta activar el poder asignado al slot (0..3). Devuelve true si se ejecutó.
func try_activate_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	var power: FaithPowerData = _slots[slot_index]
	var level: int = _levels[slot_index]
	if power == null or level <= 0 or _cooldowns[slot_index] > 0.0:
		return false
	_resolve_refs()
	if _player == null:
		return false
	var cost: float = maxf(power.costo_fe, 0.0)
	if not _player.consume_faith(cost):
		return false

	_cooldowns[slot_index] = maxf(power.cooldown, 0.05)
	_execute_power(slot_index, power, level)
	_last_cd_tenths[slot_index] = -1
	_last_active_tenths[slot_index] = -1
	_emit_slot_timer_if_changed(slot_index)
	power_activated.emit(slot_index, power, level)
	set_process(true)
	return true


## Reinicia poderes desbloqueados, cooldowns, buffs activos, proyectiles y la Fe del jugador.
func reset_powers() -> void:
	_clear_damage_buff()
	_heal_per_second = 0.0
	_heal_time_left = 0.0
	_heal_slot_index = -1
	for i: int in range(_active_fireballs.size() - 1, -1, -1):
		_recycle_fireball_at(i)
	for i: int in SLOT_COUNT:
		_slots[i] = null
		_levels[i] = 0
		_cooldowns[i] = 0.0
		_active_timers[i] = 0.0
		_last_cd_tenths[i] = 0
		_last_active_tenths[i] = 0
	set_process(false)
	set_physics_process(false)
	_resolve_refs()
	if _player != null:
		_player.reset_faith()
	slots_updated.emit(get_slots_snapshot())


## Devuelve el estado actual de los 4 slots para inicializar el HUD.
func get_slots_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for i: int in SLOT_COUNT:
		var power: FaithPowerData = _slots[i]
		snapshot.append(
			{
				"slot_index": i,
				"power": power,
				"level": _levels[i],
				"cooldown": _cooldowns[i],
				"cooldown_max": power.cooldown if power != null else 0.0,
				"active_remaining": _active_timers[i],
			}
		)
	return snapshot


func _init_slots() -> void:
	_slots.resize(SLOT_COUNT)
	_levels.resize(SLOT_COUNT)
	_cooldowns.resize(SLOT_COUNT)
	_active_timers.resize(SLOT_COUNT)
	_last_cd_tenths.resize(SLOT_COUNT)
	_last_active_tenths.resize(SLOT_COUNT)
	for i: int in SLOT_COUNT:
		_slots[i] = null
		_levels[i] = 0
		_cooldowns[i] = 0.0
		_active_timers[i] = 0.0
		_last_cd_tenths[i] = 0
		_last_active_tenths[i] = 0


func _bind_gameplay_nodes() -> void:
	_resolve_refs()
	_sync_existing_purchases()
	slots_updated.emit(get_slots_snapshot())


func _resolve_refs() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _shop_ui == null or not is_instance_valid(_shop_ui):
		_shop_ui = get_tree().get_first_node_in_group("shop_ui") as ShopUI
	if _upgrade_applier == null or not is_instance_valid(_upgrade_applier):
		_upgrade_applier = get_tree().get_first_node_in_group("upgrade_applier") as UpgradeApplier


func _is_shop_open() -> bool:
	if _shop_ui == null or not is_instance_valid(_shop_ui):
		_shop_ui = get_tree().get_first_node_in_group("shop_ui") as ShopUI
	return _shop_ui != null and _shop_ui.is_open()


func _sync_existing_purchases() -> void:
	if ShopManager.purchased_levels.is_empty():
		return
	for item: Resource in ShopManager.random_pool:
		var power := item as FaithPowerData
		if power == null:
			continue
		var level: int = ShopManager.get_item_level(power)
		if level > 0:
			_register_power(power, level)


func _on_item_purchased(item: Resource, new_level: int) -> void:
	var power := item as FaithPowerData
	if power == null:
		return
	_register_power(power, new_level)


func _register_power(power: FaithPowerData, new_level: int) -> void:
	var max_lvl: int = maxi(power.nivel_maximo, 1)
	var clamped_level: int = clampi(new_level, 1, max_lvl)
	var existing_slot: int = _find_slot_by_id(power.id)
	if existing_slot >= 0:
		_slots[existing_slot] = power
		_levels[existing_slot] = clamped_level
		slots_updated.emit(get_slots_snapshot())
		return
	var free_slot: int = _find_first_free_slot()
	if free_slot < 0:
		push_warning("FaithPowerManager: no hay slots libres para %s" % power.nombre)
		return
	_slots[free_slot] = power
	_levels[free_slot] = clamped_level
	_cooldowns[free_slot] = 0.0
	_active_timers[free_slot] = 0.0
	_last_cd_tenths[free_slot] = 0
	_last_active_tenths[free_slot] = 0
	slots_updated.emit(get_slots_snapshot())


func _find_slot_by_id(power_id: StringName) -> int:
	for i: int in SLOT_COUNT:
		if _slots[i] != null and _slots[i].id == power_id:
			return i
	return -1


func _find_first_free_slot() -> int:
	for i: int in SLOT_COUNT:
		if _slots[i] == null:
			return i
	return -1


func _execute_power(slot_index: int, power: FaithPowerData, level: int) -> void:
	var power_value: float = maxf(power.valor_por_nivel, 0.0) * float(level)
	match power.id:
		ID_BOLA_DE_FUEGO:
			_cast_fireball(power_value)
		ID_CURACION_PASIVA:
			var duration: float = power.duracion if power.duracion > 0.0 else DEFAULT_HEAL_DURATION
			_heal_per_second = power_value
			_heal_time_left = duration
			_heal_slot_index = slot_index
			_active_timers[slot_index] = duration
		ID_DANO_EXTRA_ARMA:
			var duration: float = (
				power.duracion if power.duracion > 0.0 else DEFAULT_DAMAGE_BUFF_DURATION
			)
			_damage_buff_amount = power_value
			_damage_buff_time_left = duration
			_damage_buff_slot_index = slot_index
			_active_timers[slot_index] = duration
			_apply_damage_buff(_damage_buff_amount)


func _apply_damage_buff(bonus: float) -> void:
	_resolve_refs()
	if _upgrade_applier != null:
		_upgrade_applier.set_temporary_damage_bonus(bonus)


func _clear_damage_buff() -> void:
	if _damage_buff_slot_index >= 0 and _damage_buff_slot_index < SLOT_COUNT:
		_active_timers[_damage_buff_slot_index] = 0.0
	var had_bonus: bool = _damage_buff_amount > 0.0
	_damage_buff_amount = 0.0
	_damage_buff_time_left = 0.0
	_damage_buff_slot_index = -1
	if had_bonus:
		_apply_damage_buff(0.0)


func _emit_slot_timer_if_changed(slot_index: int) -> void:
	var cd: float = _cooldowns[slot_index]
	var active: float = _active_timers[slot_index]
	var cd_tenths: int = int(ceil(cd * 10.0)) if cd > 0.0 else 0
	var active_tenths: int = int(ceil(active * 10.0)) if active > 0.0 else 0
	if (
		cd_tenths == _last_cd_tenths[slot_index]
		and active_tenths == _last_active_tenths[slot_index]
	):
		return
	_last_cd_tenths[slot_index] = cd_tenths
	_last_active_tenths[slot_index] = active_tenths
	var power: FaithPowerData = _slots[slot_index]
	var max_cd: float = power.cooldown if power != null else 0.0
	cooldown_updated.emit(slot_index, cd, max_cd, active)


func _init_fireball_pool() -> void:
	_ensure_fireball_resources()
	for _i: int in FIREBALL_INITIAL_POOL:
		_fireball_pool.append(_create_fireball_node())


static func _ensure_fireball_resources() -> void:
	if _fireball_mesh == null:
		_fireball_mesh = SphereMesh.new()
		_fireball_mesh.radius = FIREBALL_RADIUS
		_fireball_mesh.height = FIREBALL_RADIUS * 2.0
		_fireball_mesh.radial_segments = 10
		_fireball_mesh.rings = 6
	if _fireball_material == null:
		_fireball_material = StandardMaterial3D.new()
		_fireball_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fireball_material.albedo_color = Color(1.0, 0.35, 0.06, 1.0)
		_fireball_material.emission_enabled = true
		_fireball_material.emission = Color(1.0, 0.42, 0.08, 1.0)
		_fireball_material.emission_energy_multiplier = 2.0
	if _fireball_shape == null:
		_fireball_shape = SphereShape3D.new()
		_fireball_shape.radius = FIREBALL_RADIUS


func _create_fireball_node() -> Area3D:
	_ensure_fireball_resources()
	var area := Area3D.new()
	area.top_level = true
	area.collision_layer = 0
	area.collision_mask = FIREBALL_COLLISION_MASK
	area.monitoring = false
	area.monitorable = false
	area.visible = false

	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = _fireball_mesh
	mesh_inst.material_override = _fireball_material
	area.add_child(mesh_inst)

	var col := CollisionShape3D.new()
	col.shape = _fireball_shape
	area.add_child(col)

	area.body_entered.connect(_on_fireball_body_entered.bind(area))
	add_child(area)
	return area


func _take_fireball_from_pool() -> Area3D:
	while not _fireball_pool.is_empty():
		var raw: Variant = _fireball_pool.pop_back()
		if is_instance_valid(raw):
			var candidate := raw as Area3D
			if candidate != null and candidate.is_inside_tree():
				return candidate
	return _create_fireball_node()


func _cast_fireball(damage: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var direction: Vector3 = -camera.global_basis.z.normalized()
	var spawn_pos: Vector3 = camera.global_position + direction * FIREBALL_SPAWN_OFFSET
	var area: Area3D = _take_fireball_from_pool()
	area.global_position = spawn_pos
	area.visible = true
	area.monitoring = true
	_active_fireballs.append(
		{
			"area": area,
			"velocity": direction * FIREBALL_SPEED,
			"damage": maxf(damage, 0.0),
			"time_left": FIREBALL_LIFETIME,
		}
	)
	set_physics_process(true)


func _on_fireball_body_entered(body: Node3D, area: Area3D) -> void:
	if body == null or body == _player:
		return
	var active_index: int = _find_active_fireball_index(area)
	if active_index < 0:
		return
	var entry: Dictionary = _active_fireballs[active_index]
	var damage: float = float(entry["damage"])
	if body.has_method("take_damage"):
		body.call("take_damage", damage, false)
	_recycle_fireball_at(active_index)


func _find_active_fireball_index(area: Area3D) -> int:
	for i: int in _active_fireballs.size():
		if _active_fireballs[i]["area"] == area:
			return i
	return -1


func _recycle_fireball_at(index: int) -> void:
	if index < 0 or index >= _active_fireballs.size():
		return
	var entry: Dictionary = _active_fireballs[index]
	_active_fireballs.remove_at(index)
	var area := entry["area"] as Area3D
	if area != null and is_instance_valid(area):
		area.visible = false
		area.set_deferred("monitoring", false)
		if not _fireball_pool.has(area):
			_fireball_pool.append(area)
