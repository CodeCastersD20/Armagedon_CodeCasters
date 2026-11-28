class_name SlashWaveData
extends Resource
## La Espada en Llamas: habilidad única de la espada (GDD §6.1, §8.1; issue #43).
## Se mantiene la tecla de habilidad para cargar (la hoja se prende en fuego) y al soltar se
## lanza una media luna de fuego. Más carga = más daño, más enemigos atravesados y más alcance;
## a carga completa el alcance es infinito hasta chocar con algo sólido.
## Todos los valores son provisionales: el GDD aún no los define.

# TODO(GDD): daño, alcance, velocidad, ancho, carga y enfriamiento [PENDIENTE].
@export_group("Carga")
## Segundos manteniendo la tecla para llegar a carga completa.
@export var charge_seconds: float = 1.2
## Segundos mínimos de pose de carga aunque se suelte antes (la espada tiene que subir).
@export var min_windup_seconds: float = 0.12

@export_group("Daño por carga (mínima → completa)")
## Daño por enemigo alcanzado con carga mínima.
@export var min_damage: float = 20.0
## Daño por enemigo alcanzado con carga completa.
@export var max_damage: float = 90.0
## Enemigos que atraviesa con carga mínima antes de deshacerse.
@export var min_pierce: int = 1
## Enemigos que atraviesa con carga completa.
@export var max_pierce: int = 10

@export_group("Alcance y forma")
## Metros que recorre con carga mínima.
@export var min_range: float = 6.0
## Metros que recorre justo antes de la carga completa (a carga completa es infinito).
@export var max_range: float = 30.0
## Tope de seguridad del alcance "infinito" (metros), por si nunca choca con nada.
@export var infinite_range_cap: float = 400.0
## Velocidad de la onda en m/s.
@export var speed: float = 30.0
## Ancho de la media luna (metros) con carga mínima y completa; define el área de impacto.
@export var min_width: float = 1.6
@export var max_width: float = 3.2
## Alto del área de impacto (metros).
@export var height: float = 1.6
## Atraviesa blindajes (el frente del Wrapped Blindado): daña por cualquier lado.
@export var ignores_armor: bool = true

@export_group("Uso")
## Segundos entre usos (cuenta desde que se suelta).
@export var cooldown_seconds: float = 4.0
# TODO(GDD): se compra en la tienda (§8.1, 200 Esq.). Hasta que exista la tienda (#79)
# viene desbloqueado; la tienda llamará a Sword.unlock_ability().
@export var unlocked_by_default: bool = true
