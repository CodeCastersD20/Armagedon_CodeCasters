class_name WallLurker
extends StaticBody3D
## Cráneo o brazo esquelético incrustado en la pared de la catacumba. Tiembla y, cuando el
## jugador pasa cerca, se lanza hacia él gritando (como un enemigo que intenta salir) y vuelve.
## Se puede disparar o cortar (capa Enemy): revienta en huesos. Decorativo: no hace daño.

enum Kind { SKULL, ARM }

const SPRITES: Texture2D = preload("res://assets/textures/transitions/catacomb_sprites.png")
const SKULL_CALM: int = 0
const SKULL_SCREAM: int = 1
const SKULL_ANGRY: int = 2
const ARM: int = 3
const SKULL_CRACKED: int = 6
const ENEMY_LAYER: int = 4
const BONE_COLOR: Color = Color(0.86, 0.82, 0.7)

var kind: Kind = Kind.SKULL
## Hacia dónde sale de la pared (hacia el centro del pasillo o del pozo), en el espacio del padre.
var outward: Vector3 = Vector3.FORWARD
var trigger_distance: float = 4.5
var lunge_distance: float = 0.9
var _sprite: Sprite3D
var _home: Vector3
var _time: float = 0.0
var _cooldown: float = 0.0
var _lunging: bool = false
var _player: Node3D
var _dead: bool = false


func _ready() -> void:
	collision_layer = ENEMY_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45 if kind == Kind.SKULL else 0.4
	shape.shape = sphere
	add_child(shape)
	_sprite = Sprite3D.new()
	_sprite.texture = SPRITES
	_sprite.hframes = 4
	_sprite.vframes = 2
	_sprite.frame = ARM if kind == Kind.ARM else (SKULL_CRACKED if randf() < 0.3 else SKULL_CALM)
	_sprite.pixel_size = 0.032 if kind == Kind.SKULL else 0.04
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sprite)
	_home = position
	_time = randf() * TAU
	_player = get_tree().get_first_node_in_group("player") as Node3D


func _process(delta: float) -> void:
	if _dead:
		return
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not _lunging:
		# Tiembla en su hueco, como empujando para salir.
		var shake: float = 0.02 + 0.02 * sin(_time * 1.3)
		_sprite.position = Vector3(sin(_time * 23.0), cos(_time * 19.0), 0.0) * shake
		if _cooldown <= 0.0 and is_instance_valid(_player):
			if global_position.distance_to(_player.global_position + Vector3.UP) < trigger_distance:
				_lunge()


func _lunge() -> void:
	_lunging = true
	if kind == Kind.SKULL:
		_sprite.frame = SKULL_ANGRY if randf() < 0.5 else SKULL_SCREAM
	var target: Vector3 = _home + outward * lunge_distance
	var tw: Tween = create_tween()
	tw.tween_property(self, "position", target, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.35)
	tw.tween_property(self, "position", _home, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_end_lunge)


func _end_lunge() -> void:
	_lunging = false
	_cooldown = randf_range(1.5, 3.0)
	if kind == Kind.SKULL:
		_sprite.frame = SKULL_CALM


## Las armas llaman a esto: revienta en huesos.
func take_damage(_amount: float, _is_critical: bool = false, _ignore_armor: bool = false) -> void:
	if _dead:
		return
	_dead = true
	collision_layer = 0
	EnemyGib.spawn_burst(
		get_tree(), global_position, 6, [BONE_COLOR] as Array[Color], EnemyGib.Style.BONES
	)
	queue_free()
