class_name CrowdConfig
extends Resource
## Movimiento en grupo de los enemigos (GDD §7.2), lo aplica EnemyManager a todos a la vez:
## - Separación: cada enemigo se aparta de los que tiene muy cerca (no se apilan ni hacen fila).
## - Cerco: los que van directo al jugador se reparten en ángulos alrededor de él y llegan cada
##   uno por su lado, en vez de seguir todos la misma ruta.
## Valores provisionales.

# TODO(GDD): ajustar en QA.
@export_group("Separación")
## Distancia (m) a la que dos enemigos empiezan a apartarse.
@export var separation_radius: float = 1.6
## Fuerza del apartado frente a la dirección de avance (1 = igual de fuerte).
@export var separation_weight: float = 1.4

@export_group("No hacer fila")
## Si un enemigo queda detrás de otro (visto desde el jugador) a menos de estos grados,
## se abre de lado para no estar en la misma línea de fuego.
@export var line_avoid_degrees: float = 9.0
## Fuerza del desvío lateral (0 = apagado).
@export var line_avoid_weight: float = 1.6
## Solo cuenta a enemigos a menos de esta distancia (m) del jugador.
@export var line_avoid_range: float = 22.0

@export_group("Cerco")
@export var surround_enabled: bool = true
## Solo participan los enemigos a menos de esta distancia (m) del jugador.
@export var surround_range: float = 20.0
## Por debajo de esta distancia (m) dejan el cerco y van directo a golpear.
@export var surround_engage_distance: float = 3.0
## El punto del cerco queda estos metros más cerca del jugador que el enemigo
## (así se cierra en espiral).
@export var surround_ring_offset: float = 4.0
## Giro máximo (grados) entre el ángulo actual del enemigo y su hueco: evita cruces largos.
@export var surround_max_turn_degrees: float = 100.0
## Segundos entre repartos de huecos (no cada frame: evita temblores).
@export var surround_update_seconds: float = 0.3
