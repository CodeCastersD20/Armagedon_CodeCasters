class_name RoundConfig
extends Resource
## Configuración de tiempos, recompensas e hitos de rondas (GDD §3, §16).

@export var rest_duration: float = 40.0
@export var boss_round_interval: int = 10
@export var lucifer_round: int = 100
## TODO(GDD): confirmar valores finales de recompensa fija por ronda.
@export var base_round_score: int = 1000
@export var base_round_shards: int = 100
@export var reward_reference_time: float = 90.0
@export var min_time_reward_factor: float = 0.25
