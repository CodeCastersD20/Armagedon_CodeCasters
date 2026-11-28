class_name CircleTransitionConfig
extends Resource
## Qué transición de círculo se usa al vencer al jefe (GDD §2.2).
## Para probar otra: cambiar `selected` en data/rounds/circle_transition_config.tres
## (o en el menú debug F1 → Transición de círculo).

## false = al vencer al jefe se va directo al descanso, como antes.
@export var enabled: bool = true
@export var selected: CircleTransitionData
## Todas las opciones disponibles (las lista el menú debug).
@export var options: Array[CircleTransitionData] = []
