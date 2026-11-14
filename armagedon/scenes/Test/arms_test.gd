extends Node3D
## Prueba local de los brazos: F dispara, R recarga.

@onready var arms: PlayerArms = $Camera3D/PlayerArms


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				arms.play_fire()
			KEY_R:
				arms.play_reload()
