class_name PlayerStats
extends Resource
## Valores de balance del jugador. Se editan en data/player_stats.tres.

# TODO(GDD): velocidad, salto y sensibilidad no están definidos en el GDD (§4, §5).
# Todos estos valores pueden ser inventados al inicio en el medio o QA del desarollo
# seran cambiados para balancear y mejorar todo
@export var stamina: float = 3.0
@export var faith: float = 10.0
@export var move_speed: float = 10.0  # velocidad al caminar
@export var jump_velocity: float = 7.2
## Saltos extra en el aire (1 = doble salto). 0 = sin doble salto.
# TODO(GDD): el doble salto es la mejora "alas" (§ mejoras de personaje); los valores son
# [PENDIENTE]. El jugador empieza en 0 y la mejora lo sube.
@export var max_air_jumps: int = 0
## Velocidad vertical del salto en el aire.
@export var air_jump_velocity: float = 6.8
## Radianes de giro por píxel de mouse (0.002 ≈ sensibilidad media).
@export_range(0.0005, 0.01, 0.0005) var mouse_sensitivity: float = 0.002
@export_range(0.0, 90.0) var max_pitch_degrees: float = 89.0

# Movimiento: caminar es lo normal (move_speed); Ctrl alterna a correr
# (move_speed * run_speed_multiplier) hasta detenerse.
# Con always_run = true se corre siempre. C = agacharse (mantener).
# TODO(GDD): caminar, correr y agacharse no están definidos en el GDD;
# valores y teclas provisionales.
@export var always_run: bool = false
@export var run_speed_multiplier: float = 1.8
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_height: float = 1.0
@export var crouch_transition_speed: float = 12.0
## Velocidad, duración y enfriamiento del slide al presionar Ctrl mientras avanzas.
@export var slide_speed: float = 16.5
@export var slide_duration: float = 0.45
@export var slide_cooldown: float = 0.40
## Multiplicadores de impulso al saltar durante un slide (horizontal y vertical).
@export var slide_jump_horizontal_multiplier: float = 1.25
@export var slide_jump_vertical_multiplier: float = 1.12
## Golpe al suelo (Ctrl en el aire): altura mínima, enfriamiento, velocidad, daño y radio.
@export var slam_min_height: float = 1.6
@export var slam_cooldown: float = 1.0
@export var slam_speed: float = 32.0
@export var slam_damage: float = 25.0
@export var slam_radius: float = 4.0

# Dash: `stamina` es el máximo de cargas.
# TODO(GDD): consumo y recarga son [PENDIENTE] (ver #27); valores provisionales.
@export var dash_distance: float = 6.0
@export var dash_duration: float = 0.15
@export var dash_recharge_seconds: float = 3.0
@export var dash_in_air: bool = false
## Velocidad residual al terminar el dash (cae gradualmente en el suelo; se conserva al saltar).
@export var dash_residual_speed: float = 16.0
## Empuje vertical al hacer dash en el aire (0 = solo cancela caída, >0 = ligero impulso arriba).
@export var dash_air_vertical_boost: float = 1.5
## Tiempo de gracia tras salir de una plataforma en el que aún puedes saltar.
@export var coyote_time_seconds: float = 0.14

@export_group("Control en suelo, aire y cámara")
@export var ground_acceleration: float = 95.0
@export var ground_friction: float = 10.0
@export var air_acceleration: float = 28.0
@export var air_friction: float = 0.15
@export var dash_fov_boost: float = 14.0
@export var speed_fov_boost: float = 8.0
@export var camera_tilt_enabled: bool = true
@export var camera_tilt_degrees: float = 2.5

# Vida. TODO(GDD): los segundos de espera antes de regenerar son [PENDIENTE]
# (propuesta del GDD: 5 s, ver #27).
@export var max_health: float = 100.0
@export var regen_delay_seconds: float = 5.0
@export var regen_interval_seconds: float = 1.2
@export var regen_amount: float = 1.0
## Segundos de invulnerabilidad (i-frames) tras recibir daño.
@export var invulnerability_seconds: float = 0.25

# Si el jugador cae por debajo de esta altura, vuelve al punto de inicio.
# TODO(GDD): el GDD no define la caída al vacío; valor provisional.
@export var fall_limit_y: float = -20.0

# Escudo y mitigación (GDD §6.1).
# TODO(GDD): Confirmar si la reducción del 60% aplica siempre al llevar
# espada+escudo o solo al cubrirse (#27).
## Reducción pasiva de daño al llevar espada y escudo (0.60 = 60% menos de daño).
@export_range(0.0, 1.0, 0.05) var sword_shield_passive_reduction: float = 0.60
## Ángulo frontal de bloqueo efectivo con el escudo en grados (ej. 120° frontales).
@export_range(30.0, 180.0, 5.0) var shield_block_angle_degrees: float = 120.0
## Impulso hacia atrás al bloquear un golpe frontal con el escudo.
@export var shield_block_knockback: float = 4.5
