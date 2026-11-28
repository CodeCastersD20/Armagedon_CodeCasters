extends Control
## Barra de vida del jefe activo, arriba centrada. Se actualiza por señales.

const DAMAGE_INDICATOR_SECONDS: float = 0.4

var _spawner: BossSpawner
var _round_manager: RoundManager
var _last_name: String = ""
var _damage_tween: Tween

@onready var _bar: ProgressBar = $Bar
@onready var _damage_bar: ProgressBar = $DamageBar
@onready var _name_label: Label = $Bar/NameLabel


func _ready() -> void:
	visible = false
	_connect_systems.call_deferred()


func _connect_systems() -> void:
	_spawner = get_tree().get_first_node_in_group("boss_spawner") as BossSpawner
	if _spawner != null:
		_spawner.boss_spawned.connect(_on_boss_spawned)
		_spawner.boss_health_changed.connect(_on_boss_health_changed)
		_spawner.boss_died.connect(_on_boss_died)
	_round_manager = get_tree().get_first_node_in_group("round_manager") as RoundManager
	if _round_manager != null:
		_round_manager.state_changed.connect(_on_state_changed)
		_round_manager.rest_started.connect(_on_rest_started)


func _on_boss_spawned(enemy: Enemy) -> void:
	if enemy == null or enemy.data == null:
		return
	var boss_name: String = (
		LocalizationManager.t("enemy." + enemy.data.display_name, enemy.data.display_name)
		if enemy.data.display_name != ""
		else LocalizationManager.t("boss.default_name", "JEFE")
	)
	if boss_name != _last_name:
		_last_name = boss_name
		_name_label.text = boss_name
	visible = true
	_on_boss_health_changed(enemy.get_health(), enemy.get_max_health())


func _on_boss_health_changed(current: float, maximum: float) -> void:
	var max_hp: float = maxf(maximum, 0.01)
	var value: float = clampf(current, 0.0, max_hp)
	_bar.max_value = max_hp
	_damage_bar.max_value = max_hp
	_bar.value = value
	if value >= _damage_bar.value - 0.001:
		_set_damage_value(value)
		return
	if is_instance_valid(_damage_tween) and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_tween = create_tween().set_ignore_time_scale(true)
	_damage_tween.tween_property(_damage_bar, "value", value, DAMAGE_INDICATOR_SECONDS)


func _set_damage_value(value: float) -> void:
	if is_instance_valid(_damage_tween) and _damage_tween.is_valid():
		_damage_tween.kill()
	_damage_bar.value = value


func _on_boss_died(_enemy: Node) -> void:
	_hide_bar()


func _on_state_changed(new_state: RoundManager.State, _old_state: RoundManager.State) -> void:
	if new_state != RoundManager.State.ROUND:
		_hide_bar()


func _on_rest_started(_round_number: int) -> void:
	_hide_bar()


func _hide_bar() -> void:
	visible = false
	if is_instance_valid(_damage_tween) and _damage_tween.is_valid():
		_damage_tween.kill()
