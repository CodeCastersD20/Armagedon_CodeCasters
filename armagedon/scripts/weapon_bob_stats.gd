class_name WeaponBobStats
extends Resource
## Valores del balanceo del arma. Se editan en data/weapon_bob_stats.tres.

# TODO(GDD): intensidad y frecuencia no están definidas; ajustar en playtest.
@export var amplitude: float = 0.03
@export var frequency: float = 10.0
@export var smoothing: float = 12.0
@export var return_speed: float = 8.0
## Distancia de la cámara a la punta del arma en reposo. Si hay pared más cerca, el arma retrocede.
@export var weapon_reach: float = 0.7
