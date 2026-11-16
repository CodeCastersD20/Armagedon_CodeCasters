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
## Alcance máximo en metros: rayo hitscan (fuego) o alcance del arco (melee).
@export var max_range: float = 100.0
## Solo melee: ángulo total del arco frontal en grados.
@export_range(10.0, 360.0, 5.0) var arc_angle_degrees: float = 90.0
## Solo melee: segundos desde el clic hasta que el golpe conecta (sincroniza con la animación).
@export var hit_delay_seconds: float = 0.0
## Escena con un script que herede de Weapon (#41, #45...). Si está vacía se usa Weapon base.
@export var weapon_scene: PackedScene
## Modelo provisional mientras no haya escena propia.
@export var mesh: Mesh

@export_group("Animación procedural (armas de fuego)")
## Cuánto sube el cañón al disparar (grados). 0 = sin recoil.
@export var recoil_kick_degrees: float = 0.0
## Cuánto sube el arma entera al disparar (metros).
@export var recoil_lift: float = 0.0
## Segundos que tarda en recuperarse del recoil.
@export var recoil_recovery_seconds: float = 0.25
## Al recargar: grados que baja el cañón (positivo = hacia abajo).
@export var reload_tilt_pitch_degrees: float = 0.0
## Al recargar: grados de giro lateral del arma.
@export var reload_tilt_roll_degrees: float = 0.0
## Al recargar: metros que baja el arma.
@export var reload_tilt_drop: float = 0.0

@export_group("Animación de melee (pack)")
## Solo melee: true = usa la animación de la mano del pack (Sword_Regular_*); false = el tajo
## procedural por código (Tween).
@export var use_pack_animation: bool = false
## Escala del recorrido de la mano (metros del modelo → metros en pantalla). 0 = sin movimiento.
@export_range(0.0, 1.5, 0.05) var pack_animation_position_scale: float = 0.5
## Escala de la rotación de la mano. 0 = sin giro, 1 = completo.
@export_range(0.0, 1.5, 0.05) var pack_animation_rotation_scale: float = 0.6
## Giro de la espada sobre su eje dentro del puño, en grados (se ve en el visor de depuración).
@export_range(-180.0, 180.0, 5.0) var pack_grip_roll_degrees: float = 25.0
## Dónde está el puño respecto a la mano (X = palma, Y = hacia los dedos, Z = hacia el pulgar).
@export var pack_grip_offset: Vector3 = Vector3(-0.02, 0.08, 0.0)
## Velocidad de reproducción (1 = la del pack).
@export_range(0.25, 3.0, 0.05) var pack_animation_speed: float = 1.0
