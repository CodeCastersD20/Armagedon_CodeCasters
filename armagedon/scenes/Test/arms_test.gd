extends Node3D
## Prueba local de los brazos. Teclas: 1 espada en reposo, 2 tajo A, 3 tajo B, 4 guardia,
## 5 pistola en reposo, 6 disparo, 7 recarga. F y R siguen disparando/recargando con PlayerArms.

const CLIPS: Dictionary = {
	KEY_1: &"sword_idle",
	KEY_2: &"sword_hit_a",
	KEY_3: &"sword_hit_b",
	KEY_4: &"guard",
	KEY_5: &"gun_idle",
	KEY_6: &"gun_fire",
	KEY_7: &"gun_reload",
}

@onready var arms: PlayerArms = $Camera3D/PlayerArms
@onready var _anim: AnimationPlayer = $Camera3D/PlayerArms/ArmsAnim

var _base: StringName = &"sword_idle"


func _ready() -> void:
	# Sin WeaponManager en esta escena, PlayerArms solo mostraría la pose de pistola: aquí se elige a mano.
	arms.set_process(false)
	_anim.animation_finished.connect(_on_animation_finished)
	_play(&"sword_idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if CLIPS.has(event.keycode):
			_play(CLIPS[event.keycode])
			return
		match event.keycode:
			KEY_F:
				arms.play_fire()
			KEY_R:
				arms.play_reload()


func _play(clip: StringName) -> void:
	if not _anim.has_animation(clip):
		push_warning("No existe la animación %s" % clip)
		return
	if _anim.get_animation(clip).loop_mode != Animation.LOOP_NONE:
		_base = clip
	_anim.play(clip, 0.1)


## Los tajos, el disparo y la recarga no hacen bucle: al terminar vuelven a la postura base.
func _on_animation_finished(clip: StringName) -> void:
	if _anim.get_animation(clip).loop_mode == Animation.LOOP_NONE:
		_anim.play(_base, 0.15)
