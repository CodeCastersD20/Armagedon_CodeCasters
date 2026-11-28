class_name SlashWave
extends MeshInstance3D
## Media luna de fuego de "La Espada en Llamas". Es un sprite 2D pixel art que siempre mira a la
## cámara (no un modelo 3D): se lee igual aunque el jugador se mueva o gire.
## Avanza en línea recta, atraviesa enemigos (cada uno recibe daño una sola vez) hasta agotar
## los que puede atravesar según la carga, y se deshace al chocar con el mundo o al llegar a su
## alcance (infinito a carga completa). Se reutiliza desde un pool estático.

## Capa 3 "Enemy" (los enemigos no chocan entre sí).
const ENEMY_MASK: int = 4
const WORLD_MASK: int = 2
const MAX_TARGETS: int = 16
const SHADER: Shader = preload("res://assets/shaders/fire_slash.gdshader")
const ATLAS: Texture2D = preload("res://assets/textures/fire/fire_slash.png")
## Proporción alto/ancho del sprite (frames de 64x32).
const SPRITE_ASPECT: float = 0.5
## Crece del 55 % al 100 % de su tamaño en los primeros metros (no tapa la cámara al salir).
const GROW_METERS: float = 4.0
const START_SCALE: float = 0.55
## Metros finales en los que se desvanece (solo si su alcance no es infinito).
const FADE_METERS: float = 3.0
## Al deshacerse (pared o sin atravesados) se apaga en estos segundos.
const DISSOLVE_SECONDS: float = 0.12

static var _pool: Array = []
static var _quad: QuadMesh

var _dir: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _range: float = 0.0
var _infinite: bool = false
var _damage: float = 0.0
var _pierce_left: int = 0
var _width: float = 1.0
var _height: float = 1.0
var _speed: float = 1.0
var _ignore_armor: bool = false
var _dissolve_left: float = -1.0
var _crit_chance: float = 0.0
var _crit_multiplier: float = 1.0
var _exclude: Array[RID] = []
var _hit: Array = []
var _on_hit: Callable
var _box: BoxShape3D
var _query: PhysicsShapeQueryParameters3D
var _ray: PhysicsRayQueryParameters3D
var _material: ShaderMaterial


## Saca una onda del pool (o crea una) y la lanza desde `origin` hacia `dir`.
## `charge` va de 0 (toque) a 1 (carga completa).
static func launch(
	scene: Node,
	origin: Vector3,
	dir: Vector3,
	roll_degrees: float,
	config: SlashWaveData,
	charge: float,
	crit_chance: float,
	crit_multiplier: float,
	exclude: Array[RID],
	on_hit: Callable
) -> SlashWave:
	var wave: SlashWave = _take(scene)
	wave._crit_chance = crit_chance
	wave._crit_multiplier = crit_multiplier
	wave._exclude = exclude
	wave._on_hit = on_hit
	wave._start(origin, dir, roll_degrees, config, clampf(charge, 0.0, 1.0))
	return wave


## Dibuja una onda apagada un par de frames frente a la cámara para compilar su shader al cargar.
static func prewarm(scene: Node, position_hint: Vector3) -> void:
	if scene == null:
		return
	var wave: SlashWave = _take(scene)
	wave.global_position = position_hint
	wave._material.set_shader_parameter("fade", 0.0)
	wave.visible = true
	wave.set_physics_process(false)
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	if is_instance_valid(wave):
		wave._release()


static func _take(scene: Node) -> SlashWave:
	var wave: SlashWave = null
	while not _pool.is_empty() and wave == null:
		var raw: Variant = _pool.pop_back()
		if is_instance_valid(raw):
			wave = raw as SlashWave
	if wave == null:
		wave = SlashWave.new()
	if wave.get_parent() != scene:
		if wave.get_parent() != null:
			wave.get_parent().remove_child(wave)
		scene.add_child(wave)
	return wave


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	mesh = _quad
	# AABB amplia: el shader mueve los vértices (billboard) y el culling no debe recortarlo.
	custom_aabb = AABB(Vector3.ONE * -3.0, Vector3.ONE * 6.0)
	# Material propio por instancia (se crea una vez): cada onda tiene su tamaño y desvanecido.
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("atlas", ATLAS)
	material_override = _material
	_box = BoxShape3D.new()
	_query = PhysicsShapeQueryParameters3D.new()
	_query.shape = _box
	_query.collision_mask = ENEMY_MASK
	_ray = PhysicsRayQueryParameters3D.new()
	_ray.collision_mask = WORLD_MASK


func _start(
	origin: Vector3, dir: Vector3, roll_degrees: float, config: SlashWaveData, charge: float
) -> void:
	_dir = dir.normalized()
	_travelled = 0.0
	_hit.clear()
	_dissolve_left = -1.0
	_infinite = charge >= 0.999
	_range = (
		maxf(config.infinite_range_cap, 1.0)
		if _infinite
		else lerpf(config.min_range, config.max_range, charge)
	)
	_damage = lerpf(config.min_damage, config.max_damage, charge)
	_pierce_left = maxi(roundi(lerpf(config.min_pierce, config.max_pierce, charge)), 1)
	_width = maxf(lerpf(config.min_width, config.max_width, charge), 0.1)
	_height = maxf(config.height, 0.1)
	_speed = maxf(config.speed, 0.1)
	_ignore_armor = config.ignores_armor
	var up: Vector3 = Vector3.UP if absf(_dir.y) < 0.99 else Vector3.BACK
	global_transform = Transform3D(Basis.looking_at(_dir, up), origin)
	_material.set_shader_parameter("roll", deg_to_rad(roll_degrees))
	_material.set_shader_parameter("fade", 1.0)
	_update_size()
	visible = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _dissolve_left >= 0.0:
		_dissolve_left -= delta
		_material.set_shader_parameter("fade", maxf(_dissolve_left / DISSOLVE_SECONDS, 0.0))
		if _dissolve_left <= 0.0:
			_release()
		return
	var step: float = _speed * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + _dir * step
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	_ray.from = from
	_ray.to = to
	var wall: Dictionary = space.intersect_ray(_ray)
	if not wall.is_empty():
		to = wall["position"]
	global_position = to
	_travelled += step
	_update_size()
	_damage_enemies(space, from, to)
	if not _infinite:
		var left: float = _range - _travelled
		_material.set_shader_parameter("fade", clampf(left / FADE_METERS, 0.0, 1.0))
	if not wall.is_empty() or _pierce_left <= 0:
		_dissolve_left = DISSOLVE_SECONDS
	elif _travelled >= _range:
		_release()


func _update_size() -> void:
	var grow: float = lerpf(START_SCALE, 1.0, clampf(_travelled / GROW_METERS, 0.0, 1.0))
	var width: float = _width * grow
	_material.set_shader_parameter("size", Vector2(width, width * SPRITE_ASPECT))


func _damage_enemies(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> void:
	if _pierce_left <= 0:
		return
	var length: float = from.distance_to(to) + 0.5
	_box.size = Vector3(_width, _height, length)
	_query.transform = Transform3D(global_basis.orthonormalized(), (from + to) * 0.5)
	_query.exclude = _exclude
	for result in space.intersect_shape(_query, MAX_TARGETS):
		var collider := result["collider"] as Node3D
		if collider == null or _hit.has(collider) or not collider.has_method("take_damage"):
			continue
		_hit.append(collider)
		var crit: bool = randf() < _crit_chance
		var amount: float = _damage * (_crit_multiplier if crit else 1.0)
		collider.call("take_damage", amount, crit, _ignore_armor)
		if _on_hit.is_valid():
			_on_hit.call(collider, collider.global_position + Vector3.UP * 0.9, -_dir)
		_pierce_left -= 1
		if _pierce_left <= 0:
			return


func _release() -> void:
	visible = false
	set_physics_process(false)
	_on_hit = Callable()
	_dissolve_left = -1.0
	if not _pool.has(self):
		_pool.append(self)
