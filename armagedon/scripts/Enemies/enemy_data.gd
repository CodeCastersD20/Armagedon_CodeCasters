class_name EnemyData
extends Resource
## Stats base de un enemigo (ronda 1). Se editan en data/enemies/.
## El escalado por ronda se aplica en runtime desde Enemy (GDD §9).

enum DeathExplosionType { BLOOD, BONES }

@export var display_name: String = ""

## Vida base en la ronda 1 (GDD §7).
@export var max_health: float = 30.0

## Daño por contacto base en la ronda 1 (GDD §7).
@export var contact_damage: float = 10.0

## Velocidad de movimiento base. Se escala por ronda como multiplicador (GDD §9).
# TODO(GDD): velocidad base no definida.
@export var move_speed: float = 3.0

## Tiempo mínimo entre golpes por contacto (segundos).
# TODO(GDD): intervalo de daño por contacto no definido.
@export var contact_cooldown: float = 1.0

## Distancia máxima (metros) a la que aplica daño por contacto.
# TODO(GDD): alcance de contacto no definido.
@export var contact_range: float = 1.5

## Segundos desde el inicio del ataque hasta que el golpe conecta (0 = inmediato).
# TODO(GDD): momento de impacto por enemigo no definido.
@export var contact_hit_delay_seconds: float = 0.0

## Incremento de stats por ronda (GDD §9: propuesta 0.1 → +10% por ronda).
# TODO(GDD): fórmula propuesta pendiente de confirmación (§366).
@export var scaling_per_round: float = 0.1

## Altura sobre el origen donde aparece el número de daño.
@export var damage_number_height: float = 1.8

@export_group("Death Explosion")
## Tipo de explosión al morir (sangre para demonios, piezas óseas para esqueletos).
@export var death_explosion_type: DeathExplosionType = DeathExplosionType.BLOOD
## Cantidad de líneas rojas que salen del círculo al morir.
@export var death_gib_count: int = 20
## Paleta de colores de la explosión de sangre.
@export var death_gib_colors: Array[Color] = [
	Color(0.92, 0.05, 0.05),
	Color(0.68, 0.02, 0.02),
	Color(0.45, 0.01, 0.01),
]
## Cantidad de piezas que quedan en el suelo (modo BONES).
@export var bone_piece_count: int = 12
## Segundos que permanecen las piezas en el suelo antes de desaparecer (modo BONES).
@export var bone_floor_lifetime: float = 2.5

@export_group("Drops")
## Probabilidades y cantidades por tipo de enemigo (GDD §11.2).
@export var drops: DropData
