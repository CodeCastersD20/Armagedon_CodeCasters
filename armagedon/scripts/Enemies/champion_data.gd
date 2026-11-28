class_name ChampionData
extends Resource
## Parámetros del Campeón: enemigo más fuerte, con corona y aura.
## Se combina con cualquier variante.
# TODO(GDD): todos los valores son propuestas pendientes de confirmación con playtest.

## Probabilidad por spawn de que un enemigo sea campeón (0-1).
@export var spawn_chance: float = 0.05
## Primera ronda en la que pueden aparecer campeones.
@export var min_round: int = 5
## Máximo de campeones vivos a la vez.
@export var max_simultaneous: int = 2
@export var health_multiplier: float = 2.5
@export var damage_multiplier: float = 1.5
@export var speed_multiplier: float = 1.1
@export var scale_multiplier: float = 1.25
## Esquirlas extra al morir (además de las de su tipo), repartidas en varios pickups (GDD §11.2).
@export var bonus_shard_min: int = 10
@export var bonus_shard_max: int = 20
@export var bonus_shard_pickups: int = 3
@export var aura_color: Color = Color(1.0, 0.85, 0.2, 0.35)
@export var crown_color: Color = Color(1.0, 0.8, 0.1)
