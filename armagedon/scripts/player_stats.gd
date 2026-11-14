class_name PlayerStats
extends Resource
## Valores de balance del jugador. Se editan en data/player_stats.tres.

# TODO(GDD): velocidad, salto y sensibilidad no están definidos en el GDD (§4, §5).
@export var vida: float = 100.0
@export var move_speed: float = 6.0
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.002
@export_range(0.0, 90.0) var max_pitch_degrees: float = 89.0
