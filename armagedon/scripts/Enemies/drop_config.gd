class_name DropConfig
extends Resource
## Comportamiento compartido por todos los pickups (GDD §11.1).

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
## Pickups simultáneos por tipo (pool por MultiMesh).
@export var max_pickups_per_type: int = 48

## Asignados por #85 cuando existan los assets SFX_Shard_Pickup y SFX_Divine_Restore.
@export var shard_pickup_sfx: AudioStream
@export var divine_restore_sfx: AudioStream
