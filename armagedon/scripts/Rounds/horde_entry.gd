class_name HordeEntry
extends Resource
## Un tipo de enemigo de la horda y sus variantes con habilidad.

@export var scene: PackedScene
## Primera ronda en la que aparece este tipo (GDD §9).
@export var min_round: int = 1
@export var weight: float = 1.0
@export var variants: Array[HordeVariant] = []
