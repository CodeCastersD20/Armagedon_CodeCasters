class_name PlayerStats
extends Resource
## Valores de balance del jugador. Se editan en data/player_stats.tres.

# TODO(GDD): velocidad, salto y sensibilidad no están definidos en el GDD (§4, §5).
# Todos estos valores pueden ser inventados al inicio en el medio o QA del desarollo
# seran cambiados para balancear y mejorar todo
@export var vida: float = 100.0
@export var stamina: float = 3.0
@export var faith: float = 10.0
@export var move_speed: float = 10.0 # velocidad al caminar
@export var jump_velocity: float = 5.0
## Radianes de giro por píxel de mouse (0.002 ≈ sensibilidad media).
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity: float = 0.002
@export_range(0.0, 90.0) var max_pitch_degrees: float = 89.0

# Movimiento: caminar es lo normal (move_speed); Ctrl alterna a correr (move_speed * run_speed_multiplier)
# hasta detenerse. Con always_run = true se corre siempre. C = agacharse (mantener).
# TODO(GDD): caminar, correr y agacharse no están definidos en el GDD; valores y teclas provisionales.
@export var always_run: bool = false
@export var run_speed_multiplier: float = 1.8
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_height: float = 1.0
@export var crouch_transition_speed: float = 12.0

# Dash: `stamina` es el máximo de cargas.
# TODO(GDD): consumo y recarga son [PENDIENTE] (ver #27); valores provisionales.
@export var dash_distance: float = 6.0
@export var dash_duration: float = 0.15
@export var dash_recharge_seconds: float = 3.0
@export var dash_in_air: bool = false
