class_name BehaviorData
extends Resource
## Parámetros de un comportamiento de movimiento de enemigo (GDD §7.2).
## Cada comportamiento (script que extiende EnemyBehavior) usa solo los que necesita.
# TODO(GDD): todos los valores son propuestas pendientes de confirmación con playtest.

## Script del comportamiento (extiende EnemyBehavior).
@export var behavior_script: Script
## Peso en el sorteo cuando un EnemyData lista varios comportamientos.
@export var weight: float = 1.0
## Multiplicador de velocidad general de este comportamiento.
@export var speed_multiplier: float = 1.0
## A esta distancia (m) del jugador deja la táctica y va directo a golpear.
@export var engage_distance: float = 3.0

@export_group("Emboscada")
## Metros por delante del jugador a los que apunta.
@export var lead_distance: float = 5.0

@export_group("Flanqueo")
## Separación lateral (m) del punto de flanqueo respecto al jugador.
@export var flank_offset: float = 5.0

@export_group("Distancia (kite)")
## Más cerca que esto, se aleja.
@export var preferred_min: float = 8.0
## Más lejos que esto, se acerca.
@export var preferred_max: float = 14.0
## Metros que intenta alejarse al huir.
@export var flee_distance: float = 6.0
## Velocidad relativa al moverse de lado dentro de la banda.
@export var strafe_speed_mult: float = 0.6
## Segundos (mín. y máx.) antes de cambiar el lado del strafe.
@export var strafe_switch_min: float = 1.5
@export var strafe_switch_max: float = 3.5

@export_group("Golpear y retirarse")
## Segundos que se aleja después de golpear.
@export var retreat_seconds: float = 1.6
## Metros que intenta alejarse al retirarse.
@export var retreat_distance: float = 7.0
## Velocidad relativa durante la retirada.
@export var retreat_speed_mult: float = 1.2

@export_group("Órbita")
## Radio inicial de la órbita (m).
@export var orbit_radius: float = 7.0
## Metros por segundo que se cierra la espiral.
@export var orbit_shrink_speed: float = 0.8

@export_group("Zigzag")
## Desvío lateral máximo (m).
@export var zigzag_amplitude: float = 2.5
## Oscilaciones por segundo.
@export var zigzag_frequency: float = 0.8
