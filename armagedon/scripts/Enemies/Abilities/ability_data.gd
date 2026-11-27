class_name AbilityData
extends Resource
## Parámetros genéricos de una habilidad de enemigo (GDD §7.1).
## Cada habilidad usa solo los que necesita.
# TODO(GDD): todos los valores son propuestas pendientes de confirmación con playtest.

## Segundos entre usos de la habilidad.
@export var cooldown: float = 3.0
## Segundos de aviso/preparación antes de ejecutarla.
@export var windup: float = 0.0
## Duración del efecto (quemadura, creep, embestida máxima), en segundos.
@export var duration: float = 1.0
## Daño base de la habilidad (se escala con la ronda como el daño de contacto).
@export var damage: float = 8.0
## Alcance máximo para activarla (metros).
@export var max_range: float = 15.0
@export var projectile_speed: float = 12.0
## Velocidad de la embestida del cargador (m/s).
@export var charge_speed: float = 14.0
## Segundos que aturde al jugador al impactar (0 = sin aturdimiento).
@export var player_stun_seconds: float = 0.0
## Segundos que queda aturdido el cargador al chocar contra una pared.
@export var wall_stun_seconds: float = 2.0
## Proyectiles por disparo (1 = disparo simple). Con más de uno salen en abanico.
@export var projectile_count: int = 1
## Apertura total del abanico en grados (solo si projectile_count > 1).
@export var spread_degrees: float = 60.0
## Segundos entre un proyectil del abanico y el siguiente (0 = todos a la vez).
@export var burst_interval: float = 0.0
## Si es true, el abanico alterna en cada disparo: horizontal (izq/der) y vertical (arriba/abajo).
@export var alternate_fan: bool = false
## Radio de explosión/zona (metros).
@export var radius: float = 2.0
@export var count_min: int = 2
@export var count_max: int = 4
## Gravedad del proyectil (0 = recto, >0 = parabólico).
@export var gravity: float = 0.0
## Segundos entre ticks de daño continuo.
@export var tick_interval: float = 0.5
## Ángulo del cono (lanzallamas) o del arco trasero vulnerable (blindado), en grados.
@export var arc_degrees: float = 60.0
## Multiplicador de la velocidad de la animación de caminar mientras dura la habilidad (embestida).
@export var animation_speed: float = 1.0
## Multiplicador de velocidad de movimiento del enemigo.
@export var speed_multiplier: float = 1.0
## Fracción del daño que reciben otros enemigos (explosión del kamikaze).
@export var enemy_damage_factor: float = 0.5
## Velocidad de giro en rad/s (0 = instantáneo).
@export var turn_speed: float = 0.0
## Si el proyectil deja una zona dañina al caer.
@export var leaves_creep: bool = false
@export var color: Color = Color.WHITE
@export_group("Explosion")
## Empuje al jugador (m/s) al explotar. 0 = sin empuje.
@export var knockback_speed: float = 0.0
## Sacudida de cámara al explotar (1.0 = la del ground slam) y su duración en segundos.
@export var camera_shake_strength: float = 0.0
@export var camera_shake_duration: float = 0.4
@export_group("Summon")
@export var summon_scene: PackedScene
@export var summon_health_factor: float = 0.4
@export var summon_damage_factor: float = 0.5
@export var summon_speed_factor: float = 1.2
@export var summon_attack_cooldown_factor: float = 0.6
@export var summon_scale: float = 0.6
