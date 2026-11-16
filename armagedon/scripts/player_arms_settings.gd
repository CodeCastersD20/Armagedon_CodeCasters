class_name PlayerArmsSettings
extends Resource
## Nombres de animación y tiempos de los brazos. Valores en data/player_arms.tres.

@export var idle_anim: StringName = &"finger_gun_idle"
## TODO(GDD): el pack Kuptchi no trae animación de caminar; vacío = sigue en idle.
@export var walk_anim: StringName = &""
@export var fire_anim: StringName = &"finger_gun_fire"
## TODO(GDD): confirmar que `finger_gun_fix` sirve como recarga.
@export var reload_anim: StringName = &"finger_gun_fix"
@export var blend_time: float = 0.1
@export_group("Espada y escudo")
## Postura con la espada en la mano derecha y el escudo en la izquierda.
@export var melee_idle_anim: StringName = &"knife_idle"
## Tajos que se alternan en cada ataque.
@export var melee_hit_anims: Array[StringName] = [&"knife_hit_01", &"knife_hit_02"]
## Postura mientras se cubre con el escudo.
@export var guard_anim: StringName = &"guard_idle"
