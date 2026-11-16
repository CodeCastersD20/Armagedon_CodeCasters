extends Node3D
## Escena de prueba del shader PSX: aplica el estilo al modelo al arrancar.


func _ready() -> void:
	# las texturas se colocan en codigo enves de en el editor asi ahorramos un poco de tiempo
	# en los scripts hay uno llamado sxt_style en el se coloca el shader por codigo y despues aplica
	# la textura cada enemigo llevara este script minimo en su nodo padre mas grande 
	# las texturas se aplican de esta forma:
	PsxStyle.apply(self, preload("res://assets/models/enemies/skeleton/base.png"))
