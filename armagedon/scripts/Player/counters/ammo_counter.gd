extends Node
## Contador provisional de arma y munición. El HUD real llega con #88.

var _manager: WeaponManager

@onready var _label: Label = $Ammo


func _ready() -> void:
	_manager = get_tree().get_first_node_in_group("weapon_manager") as WeaponManager


func _process(_delta: float) -> void:
	if _manager == null:
		_manager = get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
		return
	var weapon: Weapon = _manager.get_current_weapon()
	if weapon == null:
		return
	if not weapon.uses_magazine():
		var melee_text: String = "Arma: %s (melee)" % weapon.data.display_name
		if _label.text != melee_text:
			_label.text = melee_text
		return
	var text: String = (
		"%s: %d / %d" % [weapon.data.display_name, weapon.get_ammo(), weapon.data.magazine_size]
	)
	if weapon.is_reloading():
		text += "  (recargando %.1f s)" % weapon.get_reload_seconds_left()
	if _label.text != text:
		_label.text = text
