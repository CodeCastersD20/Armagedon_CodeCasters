class_name PlayerStats
extends Resource
## Valores de balance del jugador. Se editan en data/player_stats.tres.

enum JumpStyle { NINJA, BASIC }

# TODO(GDD): velocidad, salto y sensibilidad no están definidos en el GDD (§4, §5).
# Todos estos valores pueden ser inventados al inicio en el medio o QA del desarollo
# seran cambiados para balancear y mejorar todo
@export var stamina: float = 3.0
@export var faith: float = 10.0
@export var move_speed: float = 10.0  # velocidad al caminar
@export var jump_velocity: float = 5.0
## Saltos extra en el aire (1 = doble salto). 0 = sin doble salto.
# TODO(GDD): el doble salto es la mejora "alas" (§ mejoras de personaje); los valores son
# [PENDIENTE]. El jugador empieza en 0 y la mejora lo sube.
@export var max_air_jumps: int = 0
## Velocidad vertical del salto en el aire.
@export var air_jump_velocity: float = 5.0
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

# Dash: `stamina` es el máximo de cargas.
# TODO(GDD): consumo y recarga son [PENDIENTE] (ver #27); valores provisionales.
@export var dash_distance: float = 6.0
@export var dash_duration: float = 0.15
@export var dash_recharge_seconds: float = 3.0
@export var dash_in_air: bool = false

# Vida. TODO(GDD): los segundos de espera antes de regenerar son [PENDIENTE]
# (propuesta del GDD: 5 s, ver #27).
@export var max_health: float = 100.0
@export var regen_delay_seconds: float = 5.0
@export var regen_interval_seconds: float = 1.2
@export var regen_amount: float = 1.0

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

# Movimiento de cámara tomado de animaciones (scripts/Player/head_cam.gd). Escala: 0 = sin
# efecto, 1 = completo. APAGADO por defecto: pon los interruptores en true para probarlo.
@export_group("Cámara animada")
@export var head_cam_jump_enabled: bool = false
@export var head_cam_move_enabled: bool = false
## NINJA = NinjaJump (pack 2), BASIC = Jump (pack 1).
@export var head_cam_jump_style: JumpStyle = JumpStyle.NINJA
@export_range(0.0, 1.0, 0.05) var head_cam_jump_scale_position: float = 0.3
@export_range(0.0, 1.0, 0.05) var head_cam_jump_scale_rotation: float = 0.3
@export_range(0.0, 1.0, 0.05) var head_cam_move_scale_position: float = 0.5
@export_range(0.0, 1.0, 0.05) var head_cam_move_scale_rotation: float = 0.5
## Qué tan rápido (1/segundos) se desvanece la cámara animada al terminar la animación.
@export var head_cam_fade_speed: float = 6.0

# Interruptor general de las animaciones del pack Universal Animation Library en la espada y el
# escudo (manos reales, tajo de la espada, escudo que se mueve al atacar). Apagado = se usan las
# animaciones procedurales por código de siempre.
@export_group("Animaciones del pack (espada y escudo)")
@export var pack_animations_enabled: bool = false
