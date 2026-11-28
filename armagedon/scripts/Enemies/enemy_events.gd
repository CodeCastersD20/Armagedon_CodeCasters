extends Node

signal enemy_died(enemy_type: StringName, position: Vector3)


func report_death(enemy_type: StringName, position: Vector3) -> void:
	enemy_died.emit(enemy_type, position)
