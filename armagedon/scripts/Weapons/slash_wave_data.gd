class_name SlashWaveData
extends Resource
## Tajo a distancia: habilidad única de la espada (GDD §6.1, §8.1; issue #43).
## Todos los valores son provisionales: el GDD aún no los define.

# TODO(GDD): daño, alcance, velocidad, ancho y enfriamiento del Tajo a distancia [PENDIENTE].
## Daño por enemigo alcanzado (cada enemigo recibe la onda una sola vez).
@export var damage: float = 60.0
## Metros que recorre la onda antes de desvanecerse.
@export var max_range: float = 18.0
## Velocidad de la onda en m/s.
@export var speed: float = 26.0
## Ancho de la media luna (metros); define el área de impacto lateral.
@export var width: float = 2.6
## Alto del área de impacto (metros).
@export var height: float = 1.6
## Segundos entre usos.
@export var cooldown_seconds: float = 4.0
## Segundos de carga (espada hacia atrás) antes del tajo.
@export var windup_seconds: float = 0.22
# TODO(GDD): se compra en la tienda (§8.1, 200 Esq.). Hasta que exista la tienda (#79)
# viene desbloqueado; la tienda llamará a Sword.unlock_ability().
@export var unlocked_by_default: bool = true
