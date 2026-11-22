class_name SkeletonEnemy
extends AnimatedEnemy

const BASE_TEXTURE: Texture2D = preload("res://assets/models/enemies/skeleton/base.png")


func _ready() -> void:
	fallback_texture = BASE_TEXTURE
	super._ready()
