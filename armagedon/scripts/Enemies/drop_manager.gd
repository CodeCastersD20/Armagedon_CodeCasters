class_name DropManager
extends Node
## Pickups de drops en tres MultiMeshInstance3D (un draw call por tipo). GDD §11:
## atracción magnética, recolección, tiempo de vida y limpieza al cambiar de ronda.

signal shards_collected(amount: int)

enum PickupType { FAITH, HEALTH, SHARD }

const _DEFAULT_CONFIG := preload("res://data/drop_config.tres")

static var _instance: DropManager

@export var config: DropConfig

var _player: Player
var _wallet: Node
var _batches: Array[DropPickupBatch] = []


static func spawn_from(tree: SceneTree, origin: Vector3, data: EnemyData) -> void:
	if tree == null or data == null or data.drops == null:
		return
	var manager: DropManager = _get_or_create(tree)
	if manager != null:
		manager._spawn(origin, data.drops)


static func _get_or_create(tree: SceneTree) -> DropManager:
	if is_instance_valid(_instance) and _instance.is_inside_tree():
		return _instance
	var found := tree.get_first_node_in_group("drop_manager") as DropManager
	if found != null:
		_instance = found
		return found
	if tree.current_scene == null:
		return null
	var created := DropManager.new()
	created.name = "DropManager"
	tree.current_scene.add_child(created)
	_instance = created
	return created


func _ready() -> void:
	add_to_group("drop_manager")
	if config == null:
		config = _DEFAULT_CONFIG as DropConfig
	_instance = self
	_resolve_references.call_deferred()
	_create_batches()
	set_process(false)


func _exit_tree() -> void:
	if _instance == self:
		_instance = null


func _resolve_references() -> void:
	if not is_inside_tree():
		return
	_player = get_tree().get_first_node_in_group("player") as Player
	var round_manager := get_tree().get_first_node_in_group("round_manager")
	if round_manager == null:
		return
	if not round_manager.is_connected("round_started", Callable(self, "_on_round_started")):
		round_manager.connect("round_started", Callable(self, "_on_round_started"))
	if not round_manager.is_connected("rest_started", Callable(self, "_on_rest_started")):
		round_manager.connect("rest_started", Callable(self, "_on_rest_started"))


func _create_batches() -> void:
	if config == null or not _batches.is_empty():
		return
	var capacity: int = maxi(config.max_pickups_per_type, 1)
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.radial_segments = 8
	sphere.rings = 4
	var shard := BoxMesh.new()
	shard.size = Vector3.ONE * 0.25
	_create_batch(PickupType.FAITH, sphere, Color(0.15, 0.45, 1.0), capacity, false)
	_create_batch(PickupType.HEALTH, sphere, Color(1.0, 0.12, 0.12), capacity, false)
	_create_batch(PickupType.SHARD, shard, Color(0.95, 0.82, 0.35), capacity, true)


func _create_batch(type: int, mesh: Mesh, color: Color, capacity: int, spin: bool) -> void:
	var material := ShaderMaterial.new()
	material.shader = PsxStyle.SHADER
	material.set_shader_parameter("albedo_color", color)
	var batch := DropPickupBatch.new()
	batch.setup(type, mesh, material, capacity, spin)
	batch.collected.connect(_on_pickup_collected)
	add_child(batch)
	_batches.append(batch)


func _spawn(origin: Vector3, drops: DropData) -> void:
	if _batches.is_empty():
		return
	set_process(true)
	if _roll(drops.shard_probability):
		var total: int = _random_amount(drops.shard_min, drops.shard_max)
		var pickups: int = maxi(_random_amount(drops.shard_pickups_min, drops.shard_pickups_max), 1)
		var base: int = total / pickups
		var remainder: int = total % pickups
		for index in pickups:
			var amount: int = base + (1 if index < remainder else 0)
			if amount > 0:
				_spawn_one(PickupType.SHARD, origin, amount)
	if _roll(drops.faith_probability):
		var faith_spheres: int = _random_amount(drops.faith_min, drops.faith_max)
		for _index in faith_spheres:
			_spawn_one(PickupType.FAITH, origin, 1)
	if _roll(drops.health_probability):
		var health_spheres: int = _random_amount(drops.health_min, drops.health_max)
		for _index in health_spheres:
			_spawn_one(PickupType.HEALTH, origin, 1)


func _spawn_one(type: int, origin: Vector3, amount: int) -> void:
	if type < 0 or type >= _batches.size():
		return
	var offset := Vector3(randf_range(-0.45, 0.45), 0.8, randf_range(-0.45, 0.45))
	_batches[type].spawn(origin + offset, float(amount))


func _process(delta: float) -> void:
	if config == null or _player == null or _batches.is_empty():
		set_process(false)
		return
	var player_pos: Vector3 = _player.global_position
	var can_collect := PackedByteArray(
		[
			int(not _player.is_faith_full()),
			int(not _player.is_health_full()),
			1,
		]
	)
	for index in _batches.size():
		_batches[index].step(delta, player_pos, can_collect[index] != 0, config)
	var any_active: bool = false
	for batch in _batches:
		if batch.has_active():
			any_active = true
			break
	if not any_active:
		set_process(false)


func _on_pickup_collected(type: int, amount: float) -> void:
	match type:
		PickupType.FAITH:
			if _player != null:
				_player.add_faith(maxf(config.faith_per_sphere, 0.0) * amount)
			_play_sfx(config.divine_restore_sfx)
		PickupType.HEALTH:
			if _player != null:
				_player.heal(maxf(config.health_per_sphere, 0.0) * amount)
			_play_sfx(config.divine_restore_sfx)
		PickupType.SHARD:
			var shards: int = maxi(int(amount), 0)
			shards_collected.emit(shards)
			if not is_instance_valid(_wallet):
				_wallet = get_tree().get_first_node_in_group("economy")
			if _wallet != null and _wallet.has_method("add_shards"):
				_wallet.call("add_shards", shards)
			_play_sfx(config.shard_pickup_sfx)


func _play_sfx(stream: AudioStream) -> void:
	if stream != null and AudioManager != null:
		AudioManager.play_sfx(stream)


func _on_round_started(_round_number: int, _is_boss_round: bool) -> void:
	clear_all()


func _on_rest_started(_round_number: int) -> void:
	clear_all()


func clear_all() -> void:
	for batch in _batches:
		batch.clear()


func _roll(probability: float) -> bool:
	return randf() <= clampf(probability, 0.0, 1.0)


func _random_amount(min_value: int, max_value: int) -> int:
	var low: int = maxi(mini(min_value, max_value), 0)
	var high: int = maxi(maxi(min_value, max_value), 0)
	if high <= low:
		return low
	return randi_range(low, high)
