class_name HordeConfig
extends Resource
## Configuración de la horda: cuántos enemigos, qué tipos por ronda, variantes y campeones (GDD §9).
# TODO(GDD): variant_chance, max_variants y los umbrales de ronda son propuestas.

## Enemigos simultáneos de la horda (GDD §9: 12 constantes).
@export var target_count: int = 12
## Tope duro de enemigos en escena (GDD §7).
@export var hard_cap: int = 30
## Probabilidad por spawn de usar una variante con habilidad (si el tipo tiene alguna disponible).
@export var variant_chance: float = 0.2
## Máximo de variantes con habilidad vivas a la vez.
@export var max_variants: int = 4
## Segundos entre un enemigo muerto y su reposición.
@export var respawn_delay: float = 0.6
@export var entries: Array[HordeEntry] = []
@export var champion: ChampionData
