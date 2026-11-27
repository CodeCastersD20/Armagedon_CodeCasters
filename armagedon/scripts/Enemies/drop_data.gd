class_name DropData
extends Resource
## Probabilidad y cantidad de drops de un tipo de enemigo (GDD §11.2).

@export_group("Esquirlas de Alma")
## Probabilidad de soltar Esquirlas (1.0 = siempre).
@export var shard_probability: float = 1.0
## Total de Esquirlas sueltas por baja.
@export var shard_min: int = 10
@export var shard_max: int = 10
## Pickups en los que se reparte el total (1 para enemigos normales).
@export var shard_pickups_min: int = 1
@export var shard_pickups_max: int = 1

@export_group("Esfera azul (Fe)")
@export var faith_probability: float = 0.0
## Número de esferas; cada una restaura DropConfig.faith_per_sphere.
@export var faith_min: int = 0
@export var faith_max: int = 0

@export_group("Esfera roja (Vida)")
@export var health_probability: float = 0.0
## Número de esferas; cada una restaura DropConfig.health_per_sphere.
@export var health_min: int = 0
@export var health_max: int = 0
