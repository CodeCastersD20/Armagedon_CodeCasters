class_name DropManager
extends Node
## Pickups de drops en tres MultiMeshInstance3D (un draw call por tipo). GDD §11:
## atracción magnética, recolección, tiempo de vida y limpieza al cambiar de ronda.

signal shards_collected(amount: int)

enum PickupType { FAITH, HEALTH, SHARD }

const _DEFAULT_CONFIG := preload("res://data/drop_config.tres")
const _PICKUP_SHADER: Shader = preload("res://assets/shaders/pickup.gdshader")
const _SPRITE_SHADER: Shader = preload("res://assets/shaders/pickup_sprite.gdshader")
const _SPRITE_ATLAS: Texture2D = preload("res://assets/textures/pickups/pickup_sprites.png")
## Orden = PickupType (FAITH, HEALTH, SHARD).
const _MODEL_SCENES: Array[PackedScene] = [
	preload("res://assets/models/pickups/PickupFaith.glb"),
	preload("res://assets/models/pickups/PickupHealth.glb"),
	preload("res://assets/models/pickups/PickupShard.glb"),
]
## Fila de cada tipo en el atlas de sprites (0 Esquirla, 1 Fe, 2 Vida).
const _SPRITE_ROWS: Array[int] = [1, 2, 0]
const _CLASSIC_COLORS: Array[Color] = [
	Color(0.15, 0.45, 1.0), Color(1.0, 0.12, 0.12), Color(0.95, 0.82, 0.35)
]
const _MODEL_SCALE: float = 1.35
const _SPRITE_SIZE: float = 0.55

static var _instance: DropManager

@export var config: DropConfig

var _player: Player
var _wallet: Node
var _batches: Array[DropPickupBatch] = []
var _visual: DropConfig.PickupVisual = DropConfig.PickupVisual.MODEL_3D


## Suelta los drops del tipo de enemigo y, si es campeón, sus Esquirlas extra.
static func spawn_from(
	tree: SceneTree, origin: Vector3, data: EnemyData, champion: ChampionData = null
) -> void:
	if tree == null or data == null:
		return
	if data.drops == null and champion == null:
		return
	var manager: DropManager = _get_or_create(tree)
	if manager == null:
		return
	if data.drops != null:
		manager._spawn(origin, data.drops)
	if champion != null:
		manager._spawn_champion_bonus(origin, champion)


## Cambia el aspecto de todos los pickups (menú debug).
static func set_visual(tree: SceneTree, visual: DropConfig.PickupVisual) -> void:
	var manager: DropManager = _get_or_create(tree) if tree != null else null
	if manager != null:
		manager._apply_visual(visual)


static func get_visual(tree: SceneTree) -> DropConfig.PickupVisual:
	var manager: DropManager = _get_or_create(tree) if tree != null else null
	if manager == null:
		var default_config: DropConfig = _DEFAULT_CONFIG as DropConfig
		return default_config.visual as DropConfig.PickupVisual
	return manager._visual


## Crea el manager al cargar y dibuja un pickup diminuto de cada tipo frente a la cámara
## un par de frames, para que el primer drop no dé un tirón al compilar el shader.
static func prewarm(tree: SceneTree) -> void:
	if tree == null:
		return
	var camera: Camera3D = tree.root.get_viewport().get_camera_3d()
	var manager: DropManager = _get_or_create(tree)
	if manager == null or camera == null:
		return
	var spot: Vector3 = camera.global_position - camera.global_basis.z * 2.0
	for batch in manager._batches:
		batch.show_prewarm(spot)
	await tree.process_frame
	await tree.process_frame
	if is_instance_valid(manager):
		for batch in manager._batches:
			if not batch.has_active():
				batch.clear()


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


func _create_batches() -> void:
	if config == null or not _batches.is_empty():
		return
	var capacity: int = maxi(config.max_pickups_per_type, 1)
	var sphere := SphereMesh.new()
	for type in PickupType.values():
		var batch := DropPickupBatch.new()
		var material := ShaderMaterial.new()
		material.shader = PsxStyle.SHADER
		batch.setup(type, sphere, material, capacity, false)
		batch.collected.connect(_on_pickup_collected)
		add_child(batch)
		_batches.append(batch)
	_apply_visual(config.visual)


## Asigna malla y material del aspecto elegido a cada lote. Solo se llama al cargar o desde
## el menú debug: crea los recursos una vez por cambio, nunca por pickup.
func _apply_visual(visual: DropConfig.PickupVisual) -> void:
	_visual = visual
	for type in _batches.size():
		match visual:
			DropConfig.PickupVisual.MODEL_3D:
				_apply_model_look(type)
			DropConfig.PickupVisual.SPRITE_2D:
				_apply_sprite_look(type)
			_:
				_apply_classic_look(type)


func _apply_classic_look(type: int) -> void:
	var mesh: Mesh
	if type == PickupType.SHARD:
		var box := BoxMesh.new()
		box.size = Vector3.ONE * 0.25
		mesh = box
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = PsxStyle.SHADER
	material.set_shader_parameter("albedo_color", _CLASSIC_COLORS[type])
	_batches[type].set_look(mesh, material, type == PickupType.SHARD, 1.0)


func _apply_model_look(type: int) -> void:
	var model: Node = _MODEL_SCENES[type].instantiate()
	var mesh_instance := (
		model.find_children("*", "MeshInstance3D", true, false).front() as MeshInstance3D
	)
	if mesh_instance == null or mesh_instance.mesh == null:
		push_error("DropManager: el modelo de pickup %d no tiene malla." % type)
		model.free()
		_apply_classic_look(type)
		return
	var mesh: Mesh = mesh_instance.mesh
	var source := mesh.surface_get_material(0) as BaseMaterial3D
	model.free()
	var material := ShaderMaterial.new()
	material.shader = _PICKUP_SHADER
	if source != null and source.albedo_texture != null:
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
	_batches[type].set_look(mesh, material, true, _MODEL_SCALE)


func _apply_sprite_look(type: int) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * _SPRITE_SIZE
	var material := ShaderMaterial.new()
	material.shader = _SPRITE_SHADER
	material.set_shader_parameter("atlas", _SPRITE_ATLAS)
	material.set_shader_parameter("row", _SPRITE_ROWS[type])
	_batches[type].set_look(quad, material, false, 1.0)


func _spawn(origin: Vector3, drops: DropData) -> void:
	if _batches.is_empty():
		return
	set_process(true)
	if _roll(drops.shard_probability):
		var total: int = _random_amount(drops.shard_min, drops.shard_max)
		var pickups: int = maxi(_random_amount(drops.shard_pickups_min, drops.shard_pickups_max), 1)
		var base: int = floori(float(total) / float(pickups))
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


func _spawn_champion_bonus(origin: Vector3, champion: ChampionData) -> void:
	if _batches.is_empty():
		return
	set_process(true)
	var total: int = _random_amount(champion.bonus_shard_min, champion.bonus_shard_max)
	var pickups: int = clampi(champion.bonus_shard_pickups, 1, maxi(total, 1))
	var base: int = floori(float(total) / float(pickups))
	var remainder: int = total % pickups
	for index in pickups:
		var amount: int = base + (1 if index < remainder else 0)
		if amount > 0:
			_spawn_one(PickupType.SHARD, origin, amount)


func _spawn_one(type: int, origin: Vector3, amount: int) -> void:
	if type < 0 or type >= _batches.size():
		return
	var offset := Vector3(randf_range(-0.45, 0.45), 0.8, randf_range(-0.45, 0.45))
	_batches[type].spawn(origin + offset, float(amount))


func _process(delta: float) -> void:
	if config == null or _batches.is_empty():
		set_process(false)
		return
	# El jugador se vuelve a buscar si aún no estaba o se liberó; sin él no se apaga el proceso
	# (antes se apagaba y los pickups ya no se recogían nunca).
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
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


## GDD §11.1: los drops se limpian al iniciar la siguiente ronda (durante el descanso se pueden
## seguir recogiendo los de las últimas bajas).
func _on_round_started(_round_number: int, _is_boss_round: bool) -> void:
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
