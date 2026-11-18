class_name TrainingDummy
extends StaticBody3D
## Muñeco de pruebas: no muere ni se mueve, solo muestra el daño recibido.

## Altura sobre el origen donde aparece el número.
@export var number_height: float = 2.2
## Dispersión horizontal para que los números seguidos no se tapen.
@export var number_spread: float = 0.35
## Solo pruebas: probabilidad de simular un crítico (rojo) en el muñeco.
# TODO(GDD): quitar cuando #49 tire el crítico en el arma y lo pase a take_damage.
@export_range(0.0, 1.0, 0.05) var debug_crit_chance: float = 0.2


func take_damage(amount: float, is_critical: bool = false) -> void:
	is_critical = is_critical or randf() < debug_crit_chance
	var offset := Vector3(
		randf_range(-number_spread, number_spread), 0.0, randf_range(-number_spread, number_spread)
	)
	DamageNumber.spawn(
		get_tree(), global_position + Vector3.UP * number_height + offset, amount, is_critical
	)
