class_name UpgradeApplier
extends Node
## Aplica al jugador y a las armas las mejoras compradas en la tienda (GDD §8, #79).

const ID_VIDA_CURACION: StringName = &"vida_curacion"
const ID_FE_RECARGA: StringName = &"fe_recarga"
const ID_MELEE_CRIT_CHANCE: StringName = &"melee_crit_chance"
const ID_MELEE_CRIT_DAMAGE: StringName = &"melee_crit_damage"
const ID_MELEE_FLAT_DAMAGE: StringName = &"melee_flat_damage"
const ID_MELEE_PCT_DAMAGE: StringName = &"melee_pct_damage"
const ID_FUEGO_CRIT_CHANCE: StringName = &"fuego_crit_chance"
const ID_FUEGO_CRIT_DAMAGE: StringName = &"fuego_crit_damage"
const ID_FUEGO_FLAT_DAMAGE: StringName = &"fuego_flat_damage"
const ID_FUEGO_PCT_DAMAGE: StringName = &"fuego_pct_damage"
const ID_FUEGO_CADENCIA: StringName = &"fuego_cadencia"
const ID_FUEGO_CARGADOR: StringName = &"fuego_cargador"
const ID_PERSONAJE_VIDA_MAX: StringName = &"personaje_vida_max"
const ID_PERSONAJE_DASH: StringName = &"personaje_dash"
const ID_PERSONAJE_VELOCIDAD: StringName = &"personaje_velocidad"
const ID_PERSONAJE_DOBLE_SALTO: StringName = &"personaje_doble_salto"
const ID_PERSONAJE_DASH_AIRE: StringName = &"personaje_dash_aire"

var melee_flat_damage: float = 0.0
var melee_pct_damage: float = 0.0
var melee_crit_chance: float = 0.0
var melee_crit_damage: float = 0.0

var fire_flat_damage: float = 0.0
var fire_pct_damage: float = 0.0
var fire_crit_chance: float = 0.0
var fire_crit_damage: float = 0.0
var fire_rate_reduction: float = 0.0
var fire_mag_bonus: int = 0

var bonus_max_health: float = 0.0
var bonus_dash_charges: float = 0.0
var speed_pct_bonus: float = 0.0
var bonus_air_jumps: int = 0
var unlock_air_dash: bool = false
var temporary_damage_bonus: float = 0.0

var _applied_levels: Dictionary = {}
var _player: Player
var _weapon_manager: WeaponManager


func _ready() -> void:
	add_to_group("upgrade_applier")
	if not ShopManager.item_purchased.is_connected(_on_item_purchased):
		ShopManager.item_purchased.connect(_on_item_purchased)
	if not ShopManager.shop_state_reset.is_connected(reset_upgrades):
		ShopManager.shop_state_reset.connect(reset_upgrades)
	_bind_gameplay_nodes.call_deferred()


func _exit_tree() -> void:
	if ShopManager.item_purchased.is_connected(_on_item_purchased):
		ShopManager.item_purchased.disconnect(_on_item_purchased)
	if ShopManager.shop_state_reset.is_connected(reset_upgrades):
		ShopManager.shop_state_reset.disconnect(reset_upgrades)
	if (
		is_instance_valid(_weapon_manager)
		and _weapon_manager.weapon_changed.is_connected(_on_weapon_changed)
	):
		_weapon_manager.weapon_changed.disconnect(_on_weapon_changed)


## Restaura todos los modificadores acumulados a sus valores base.
func reset_upgrades() -> void:
	melee_flat_damage = 0.0
	melee_pct_damage = 0.0
	melee_crit_chance = 0.0
	melee_crit_damage = 0.0
	fire_flat_damage = 0.0
	fire_pct_damage = 0.0
	fire_crit_chance = 0.0
	fire_crit_damage = 0.0
	fire_rate_reduction = 0.0
	fire_mag_bonus = 0
	bonus_max_health = 0.0
	bonus_dash_charges = 0.0
	speed_pct_bonus = 0.0
	bonus_air_jumps = 0
	unlock_air_dash = false
	temporary_damage_bonus = 0.0
	_applied_levels.clear()
	_resolve_refs()
	if _player != null:
		_player.reset_stat_modifiers()
	_sync_weapons(0)


## Aplica o retira un bono temporal de daño plano (Poderes de Fe #80) sin mutar los .tres.
func set_temporary_damage_bonus(bonus: float) -> void:
	var clamped: float = maxf(bonus, 0.0)
	if is_equal_approx(temporary_damage_bonus, clamped):
		return
	temporary_damage_bonus = clamped
	_sync_weapons(0)


func _bind_gameplay_nodes() -> void:
	_resolve_refs()
	if (
		_weapon_manager != null
		and not _weapon_manager.weapon_changed.is_connected(_on_weapon_changed)
	):
		_weapon_manager.weapon_changed.connect(_on_weapon_changed)
	_sync_existing_purchases()


func _resolve_refs() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _weapon_manager == null or not is_instance_valid(_weapon_manager):
		_weapon_manager = get_tree().get_first_node_in_group("weapon_manager") as WeaponManager


func _sync_existing_purchases() -> void:
	if ShopManager.purchased_levels.is_empty():
		return
	for item: Resource in ShopManager.random_pool:
		var upgrade := item as UpgradeData
		if upgrade == null:
			continue
		var level: int = ShopManager.get_item_level(upgrade)
		if level > 0:
			_apply_upgrade(upgrade, level)


func _on_item_purchased(item: Resource, new_level: int) -> void:
	var upgrade := item as UpgradeData
	if upgrade == null:
		return
	_resolve_refs()
	_apply_upgrade(upgrade, new_level)


func _apply_upgrade(upgrade: UpgradeData, new_level: int) -> void:
	if upgrade.id == ID_VIDA_CURACION:
		if _player != null:
			_player.heal(maxf(upgrade.valor_por_nivel, 0.0))
		return
	if upgrade.id == ID_FE_RECARGA:
		if _player != null:
			_player.add_faith(maxf(upgrade.valor_por_nivel, 0.0))
		return

	var target_level: int = maxi(new_level, 0)
	if upgrade.nivel_maximo > 0:
		target_level = mini(target_level, upgrade.nivel_maximo)
	var prev_level: int = int(_applied_levels.get(upgrade.id, 0))
	var delta_levels: int = target_level - prev_level
	if delta_levels <= 0:
		return
	_applied_levels[upgrade.id] = target_level

	var amount: float = upgrade.valor_por_nivel * float(delta_levels)
	_apply_stat_delta(upgrade.id, amount)


func _apply_stat_delta(upgrade_id: StringName, amount: float) -> void:
	match upgrade_id:
		ID_MELEE_CRIT_CHANCE:
			melee_crit_chance += amount
			_sync_weapons(0)
		ID_MELEE_CRIT_DAMAGE:
			melee_crit_damage += amount
			_sync_weapons(0)
		ID_MELEE_FLAT_DAMAGE:
			melee_flat_damage += amount
			_sync_weapons(0)
		ID_MELEE_PCT_DAMAGE:
			melee_pct_damage += amount
			_sync_weapons(0)
		ID_FUEGO_CRIT_CHANCE:
			fire_crit_chance += amount
			_sync_weapons(0)
		ID_FUEGO_CRIT_DAMAGE:
			fire_crit_damage += amount
			_sync_weapons(0)
		ID_FUEGO_FLAT_DAMAGE:
			fire_flat_damage += amount
			_sync_weapons(0)
		ID_FUEGO_PCT_DAMAGE:
			fire_pct_damage += amount
			_sync_weapons(0)
		ID_FUEGO_CADENCIA:
			fire_rate_reduction += amount
			_sync_weapons(0)
		ID_FUEGO_CARGADOR:
			var added_bullets: int = int(round(amount))
			fire_mag_bonus += added_bullets
			_sync_weapons(added_bullets)
		ID_PERSONAJE_VIDA_MAX:
			bonus_max_health += amount
			_sync_player(amount, 0.0)
		ID_PERSONAJE_DASH:
			bonus_dash_charges += amount
			_sync_player(0.0, amount)
		ID_PERSONAJE_VELOCIDAD:
			speed_pct_bonus += amount
			_sync_player(0.0, 0.0)
		ID_PERSONAJE_DOBLE_SALTO:
			bonus_air_jumps += int(round(amount))
			_sync_player(0.0, 0.0)
		ID_PERSONAJE_DASH_AIRE:
			unlock_air_dash = true
			_sync_player(0.0, 0.0)


func _sync_player(health_delta: float, dash_delta: float) -> void:
	_resolve_refs()
	if _player == null:
		return
	_player.apply_upgrade_modifiers(
		bonus_max_health,
		bonus_dash_charges,
		speed_pct_bonus,
		bonus_air_jumps,
		unlock_air_dash,
		health_delta,
		dash_delta
	)


func _sync_weapons(added_mag_bullets: int) -> void:
	_resolve_refs()
	if _weapon_manager == null:
		return
	var melee_weapon: Weapon = _weapon_manager.get_melee_weapon()
	if melee_weapon != null:
		melee_weapon.apply_upgrade_modifiers(
			melee_flat_damage + temporary_damage_bonus,
			melee_pct_damage,
			melee_crit_chance,
			melee_crit_damage
		)
	var fire_weapon: Weapon = _weapon_manager.get_fire_weapon()
	if fire_weapon != null:
		fire_weapon.apply_upgrade_modifiers(
			fire_flat_damage + temporary_damage_bonus,
			fire_pct_damage,
			fire_crit_chance,
			fire_crit_damage,
			fire_rate_reduction,
			fire_mag_bonus,
			added_mag_bullets
		)


func _on_weapon_changed(_weapon: Weapon) -> void:
	_sync_weapons(0)
