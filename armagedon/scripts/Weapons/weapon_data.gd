class_name WeaponData
extends Resource
## Stats de un arma. Cada arma tiene su .tres en data/weapons/.

enum Kind { FIRE, MELEE }

@export var display_name: String = ""
@export var kind: Kind = Kind.FIRE
@export var damage: float = 10.0
## Tamaño del cargador (munición infinita). 0 = sin cargador (melee).
@export var magazine_size: int = 0
@export var reload_seconds: float = 0.0
## Segundos entre ataques. 650 RPM = 60 / 650 ≈ 0.092 s.
# TODO(GDD): la cadencia de pistola, escopeta y subfusil es [PENDIENTE] (§6.2).
@export var attack_interval: float = 0.5
## Si es true, mantener clic izquierdo sigue disparando según la cadencia.
@export var automatic: bool = true
## Alcance máximo del rayo hitscan en metros (armas de fuego).
@export var max_range: float = 100.0
## Escena con un script que herede de Weapon (#41, #45...). Si está vacía se usa Weapon base.
@export var weapon_scene: PackedScene
## Modelo provisional mientras no haya escena propia.
@export var mesh: Mesh
