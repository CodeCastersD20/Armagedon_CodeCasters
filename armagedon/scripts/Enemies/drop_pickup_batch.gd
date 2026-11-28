class_name DropPickupBatch
extends MultiMeshInstance3D
## Un lote de pickups del mismo tipo con buffers planos y un solo MultiMesh.

signal collected(type: int, amount: float)

@export var type: int = 0
@export var spin: bool = false
@export var visual_scale: float = 1.0

var capacity: int = 0

var _positions: PackedVector3Array = PackedVector3Array()
var _amounts: PackedFloat32Array = PackedFloat32Array()
var _ages: PackedFloat32Array = PackedFloat32Array()
var _phases: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0


func setup(p_type: int, mesh: Mesh, material: Material, p_capacity: int, p_spin: bool) -> void:
	type = p_type
	spin = p_spin
	capacity = p_capacity
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	multimesh = mm
	material_override = material
	_positions.resize(capacity)
	_amounts.resize(capacity)
	_ages.resize(capacity)
	_phases.resize(capacity)


## Cambia malla, material y giro sin perder los pickups activos.
func set_look(mesh: Mesh, material: Material, p_spin: bool, p_scale: float) -> void:
	spin = p_spin
	visual_scale = maxf(p_scale, 0.01)
	multimesh.mesh = mesh
	material_override = material
	for index in _count:
		multimesh.set_instance_transform(index, _make_transform(index, false))


## Muestra una instancia diminuta (sin contarla como pickup) para compilar el shader al cargar.
func show_prewarm(world_pos: Vector3) -> void:
	if _count > 0 or capacity <= 0:
		return
	multimesh.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 0.001), world_pos))
	multimesh.visible_instance_count = 1


func spawn(world_pos: Vector3, amount: float) -> void:
	if _count >= capacity:
		return
	var index: int = _count
	_count += 1
	_positions[index] = world_pos
	_amounts[index] = amount
	_ages[index] = 0.0
	_phases[index] = randf_range(0.0, TAU)
	multimesh.set_instance_transform(index, _make_transform(index, false))
	multimesh.visible_instance_count = _count


func step(delta: float, player_pos: Vector3, can_collect: bool, cfg: DropConfig) -> void:
	var magnet_radius: float = maxf(cfg.magnet_radius, 0.0)
	var magnet_sq: float = magnet_radius * magnet_radius
	var collect_radius: float = maxf(cfg.collect_radius, 0.0)
	var collect_sq: float = collect_radius * collect_radius
	var speed: float = maxf(cfg.move_speed, 0.0)
	var lifetime: float = maxf(cfg.lifetime_seconds, 0.01)
	var blink_start: float = lifetime - maxf(cfg.blink_seconds, 0.0)
	var index: int = _count - 1
	while index >= 0:
		_ages[index] += delta
		if _ages[index] >= lifetime:
			_swap_remove(index)
			index -= 1
			continue
		var to_player: Vector3 = player_pos - _positions[index]
		to_player.y = 0.0
		var dist_sq: float = to_player.length_squared()
		if dist_sq <= collect_sq and can_collect:
			collected.emit(type, _amounts[index])
			_swap_remove(index)
			index -= 1
			continue
		# Si no se puede recoger (barra llena), se queda en el suelo: no se pega al jugador.
		if can_collect and dist_sq <= magnet_sq and dist_sq > 0.0001:
			var dist: float = sqrt(dist_sq)
			var travel: float = speed * delta
			if travel >= dist:
				_positions[index] = player_pos
			else:
				_positions[index] += to_player / dist * travel
		var hidden: bool = _ages[index] >= blink_start and fmod(_ages[index], 0.2) >= 0.1
		multimesh.set_instance_transform(index, _make_transform(index, hidden))
		index -= 1
	multimesh.visible_instance_count = _count


func clear() -> void:
	_count = 0
	multimesh.visible_instance_count = 0


func has_active() -> bool:
	return _count > 0


func _make_transform(index: int, hidden: bool) -> Transform3D:
	if hidden:
		return Transform3D(Basis().scaled(Vector3.ZERO), _positions[index])
	var pickup_basis := Basis()
	if spin:
		pickup_basis = Basis.from_euler(Vector3(0.0, _ages[index] * 2.5 + _phases[index], 0.0))
	pickup_basis = pickup_basis.scaled(Vector3.ONE * visual_scale)
	var bob: float = sin(_ages[index] * 4.0 + _phases[index]) * 0.05
	return Transform3D(pickup_basis, _positions[index] + Vector3.UP * bob)


func _swap_remove(index: int) -> void:
	var last: int = _count - 1
	if index != last:
		_positions[index] = _positions[last]
		_amounts[index] = _amounts[last]
		_ages[index] = _ages[last]
		_phases[index] = _phases[last]
		multimesh.set_instance_transform(index, _make_transform(index, false))
	_count = last
