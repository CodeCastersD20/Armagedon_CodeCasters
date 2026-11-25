class_name CurrencyPickup
extends Area3D

@export var amount: int = 10
@export var magnet_speed: float = 12.0

var _target: Node3D = null

func _ready() -> void:
	# El Player está en Collision Layer 1
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if is_instance_valid(_target):
		global_position = global_position.move_toward(_target.global_position, magnet_speed * delta)
		if global_position.distance_to(_target.global_position) < 0.8:
			_collect()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_target = body

func _collect() -> void:
	CurrencyManager.add(amount)
	queue_free()