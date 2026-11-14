class_name WeaponBob
extends Node3D
## Balanceo del arma: se mueve al caminar, vuelve al reposo al parar
## y retrocede si hay una pared delante para no atravesarla.

@export var player: Player
@export var bob_stats: WeaponBobStats

var _rest_position: Vector3
var _time: float = 0.0
var _wall_push: float = 0.0
var _applied_push: float = 0.0

@onready var _camera: Node3D = get_parent()


func _ready() -> void:
	_rest_position = position


func _physics_process(_delta: float) -> void:
	# Un rayo por el centro de la cámara y otro por el lado donde cuelga el arma.
	_wall_push = maxf(_push_from(Vector3.ZERO), _push_from(Vector3(_rest_position.x, _rest_position.y, 0.0)))


## Cuánto debe retroceder el arma según la pared que hay delante de `local_origin` (en espacio de la cámara).
func _push_from(local_origin: Vector3) -> float:
	var from: Vector3 = _camera.to_global(local_origin)
	var to: Vector3 = from - _camera.global_basis.z * bob_stats.weapon_reach
	var query := PhysicsRayQueryParameters3D.create(from, to, player.collision_mask, [player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return bob_stats.weapon_reach - from.distance_to(hit.position)


func _process(delta: float) -> void:
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var target := Vector2(_rest_position.x, _rest_position.y)
	var weight: float = bob_stats.return_speed
	if player.is_on_floor() and speed > 0.1:
		var intensity: float = speed / player.stats.move_speed
		_time += delta * bob_stats.frequency * intensity
		target += Vector2(cos(_time * 0.5) * 0.5, sin(_time)) * bob_stats.amplitude
		weight = bob_stats.smoothing
	var xy := Vector2(position.x, position.y).lerp(target, weight * delta)
	# Al acercarse a una pared el arma retrocede al instante; al alejarse vuelve suave.
	_applied_push = maxf(_wall_push, lerpf(_applied_push, _wall_push, bob_stats.return_speed * delta))
	position = Vector3(xy.x, xy.y, _rest_position.z + _applied_push)
