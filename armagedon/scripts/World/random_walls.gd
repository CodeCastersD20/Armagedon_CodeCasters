class_name RandomWalls
extends Node3D
## Redistribuye aleatoriamente los muros hijos existentes dentro de la arena al iniciar.

const MAX_ATTEMPTS: int = 40

@export var randomize_on_ready: bool = true
@export var area_half_extents: Vector2 = Vector2(16.0, 16.0)
@export var safe_center_radius: float = 2.2
@export var min_spacing: float = 4.2
@export var protected_nodes: Array[NodePath] = []
@export var protected_radius: float = 2.2
## 0 = semilla aleatoria en cada partida; distinto de 0 = layout reproducible.
@export var random_seed: int = 0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	if randomize_on_ready:
		randomize_walls()


## Recoloca y rota en Y todos los muros hijos dentro del área configurada.
func randomize_walls() -> void:
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()

	var placed: Array[Vector2] = []
	var protected_points: Array[Vector2] = _get_protected_points()

	for child in get_children():
		var wall: Node3D = child as Node3D
		if wall == null:
			continue
		var pos_2d: Variant = _find_valid_position(placed, protected_points)
		if pos_2d == null:
			continue
		var coords: Vector2 = pos_2d as Vector2
		placed.append(coords)
		wall.position = Vector3(coords.x, wall.position.y, coords.y)
		wall.rotation.y = _rng.randf_range(0.0, TAU)


func _find_valid_position(
	placed: Array[Vector2], protected_points: Array[Vector2]
) -> Variant:
	var min_spacing_sq: float = min_spacing * min_spacing
	var center_radius_sq: float = safe_center_radius * safe_center_radius
	var protected_radius_sq: float = protected_radius * protected_radius

	for _attempt in range(MAX_ATTEMPTS):
		var candidate: Vector2 = Vector2(
			_rng.randf_range(-area_half_extents.x, area_half_extents.x),
			_rng.randf_range(-area_half_extents.y, area_half_extents.y)
		)
		if candidate.length_squared() < center_radius_sq:
			continue
		if _is_too_close(candidate, protected_points, protected_radius_sq):
			continue
		if _is_too_close(candidate, placed, min_spacing_sq):
			continue
		return candidate
	return null


func _is_too_close(point: Vector2, others: Array[Vector2], min_dist_sq: float) -> bool:
	for other in others:
		if point.distance_squared_to(other) < min_dist_sq:
			return true
	return false


func _get_protected_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for path in protected_nodes:
		var node: Node3D = get_node_or_null(path) as Node3D
		if node != null:
			var p: Vector3 = node.global_position if node.is_inside_tree() else node.position
			points.append(Vector2(p.x, p.z))
	return points
