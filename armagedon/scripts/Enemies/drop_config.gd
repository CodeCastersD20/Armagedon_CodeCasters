class_name DropConfig
extends Resource
## Comportamiento compartido por todos los pickups (GDD §11.1).

## Aspecto de los pickups: primitivas de color, modelos 3D low-poly o sprites 2D que miran
## siempre a la cámara. Se puede cambiar en vivo desde el menú debug (F1).
enum PickupVisual { CLASSIC, MODEL_3D, SPRITE_2D }

## Distancia a la que el pickup empieza a atraerse hacia el jugador.
@export var magnet_radius: float = 2.5
## Distancia a la que se recoge.
@export var collect_radius: float = 0.8
## Velocidad de atracción en metros por segundo.
@export var move_speed: float = 12.0
## Segundos antes de desaparecer.
@export var lifetime_seconds: float = 25.0
## Segundos finales en los que el pickup parpadea.
@export var blink_seconds: float = 5.0
## Fe restaurada por esfera azul.
@export var faith_per_sphere: float = 15.0
## Vida restaurada por esfera roja.
@export var health_per_sphere: float = 15.0
## TODO(GDD): elegir el aspecto definitivo tras probar 3D y 2D.
@export var visual: PickupVisual = PickupVisual.MODEL_3D
## Pickups simultáneos por tipo (pool por MultiMesh).
@export var max_pickups_per_type: int = 48

## Asignados por #85 cuando existan los assets SFX_Shard_Pickup y SFX_Divine_Restore.
@export var shard_pickup_sfx: AudioStream
@export var divine_restore_sfx: AudioStream
