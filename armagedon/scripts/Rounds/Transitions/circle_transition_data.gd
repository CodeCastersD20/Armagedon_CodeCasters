class_name CircleTransitionData
extends Resource
## Una forma de pasar al siguiente círculo tras vencer al jefe (GDD §2.2). Igual que las
## habilidades de enemigo: `transition_script` es la subclase de CircleTransition que la ejecuta
## y el resto son sus parámetros. Valores provisionales.

# TODO(GDD): tiempos finales de cada transición [PENDIENTE].
## Script que extiende CircleTransition (elevator_transition.gd, vision_transition.gd...).
@export var transition_script: Script
## Nombre para el menú debug.
@export var display_name: String = ""

@export_group("Común")
## Segundos sin enemigos tras morir el jefe, para recoger drops, antes de que aparezca el sello.
@export var breather_seconds: float = 6.0
## true = el jugador tiene que romper el Sello del Jefe (tecla interact); false = empieza solo.
@export var require_interaction: bool = true
## Distancia (m) a la que se puede romper el sello.
@export var interact_distance: float = 2.4
## Transiciones a pie: segundos máximos esperando a que el jugador llegue a la puerta o a la
## salida; pasado ese tiempo la transición sigue sola (nunca se queda en bucle).
@export var max_wait_seconds: float = 90.0

@export_group("Viaje")
## Segundos del tramo principal del viaje (bajada, río, visión...).
@export var travel_seconds: float = 6.0
## Segundos del tramo de llegada a la arena nueva.
@export var arrival_seconds: float = 6.0
## Metros que baja (pozo) o sube (llegada) según la transición.
@export var travel_distance: float = 14.0
## Altura (m) desde la que llega a la arena nueva (elevador: colgado de cadenas).
@export var arrival_height: float = 22.0
## Almas que aparecen durante el viaje (se les puede disparar).
@export var soul_count: int = 10
