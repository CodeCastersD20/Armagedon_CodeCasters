class_name VisionTransition
extends CircleTransition
## E. Visión del arcángel: al romper el sello, el alma del jefe entra en Zahariel, destello blanco
## y una visión del siguiente círculo en un vacío (su nombre gigante, siluetas que esperan, una
## frase); despierta en la arena, ya en el nuevo círculo, levantándose del suelo.

## Lugar de la visión, lejos de la arena (a la misma altura: no activa la caída al vacío).
const POCKET: Vector3 = Vector3(2000.0, 0.0, 0.0)
const SOUL_FLIGHT_SECONDS: float = 1.1
const FOV_PULSE: float = 18.0
const PUSH_METERS: float = 6.0
const WAKE_HEAD_HEIGHT: float = 0.35
## Frase de la visión según el círculo al que se baja (índice de GameFlow.CIRCLE_NAMES).
const QUOTES: Array[String] = [
	"",
	"Un viento que nunca descansa arrastra a los que se dejaron arrastrar.",
	"Una lluvia fría y sucia cae sin fin sobre los que nunca se saciaron.",
	"Empujan rocas para siempre los que todo quisieron guardar.",
	"En el pantano se muerden los furiosos; bajo el lodo suspiran los que nada hicieron.",
	"Tumbas abiertas arden por los que negaron el alma.",
	"Un río de sangre hierve para los que la derramaron.",
	"Diez fosas guardan a los que mintieron con una sonrisa.",
	"El hielo no perdona a quien traicionó la confianza.",
	"Más allá del hielo espera el trono del primero que cayó.",
	"No queda nada. Solo tú y la oscuridad que sigue.",
]

var _seal_position: Vector3
var _pocket: Node3D
var _text_layer: CanvasLayer
var _head_y: float = 1.6
var _origin: Transform3D


func get_seal_position() -> Vector3:
	_seal_position = super.get_seal_position()
	return _seal_position


func play() -> void:
	var player: Player = ctx.player
	_head_y = player.get_head_stand_y()
	_origin = player.global_transform
	ctx.lock_all(true)
	if not await _enter_vision():
		return
	if not await _show_vision():
		return
	await _wake_up()


## Alma del jefe hacia los ojos, destello blanco y aparece en el vacío de la visión.
func _enter_vision() -> bool:
	_absorb_soul()
	play_sfx(SFX_SOUL, -6.0)
	if not await wait(SOUL_FLIGHT_SECONDS):
		return false
	await ctx.fade(Color.WHITE, 1.0, 0.35)
	if not alive():
		return false
	# La visión ya se ve con la niebla y el cielo del círculo al que se baja.
	ctx.swap_circle(false)
	ctx.set_cinematic_view(true)
	_build_pocket()
	ctx.teleport_player(POCKET + Vector3.UP * 0.1, 0.0)
	if ctx.camera != null:
		ctx.camera.fov = 75.0
	_show_quote()
	await ctx.fade(Color.WHITE, 0.0, 0.8)
	return alive()


## Avanza despacio hacia el nombre del círculo mientras se escribe la frase.
func _show_vision() -> bool:
	var player: Player = ctx.player
	var push: Tween = create_tween()
	var target: Vector3 = player.global_position + Vector3.FORWARD * PUSH_METERS
	push.tween_property(player, "global_position", target, maxf(cfg.travel_seconds, 0.5)).set_trans(
		Tween.TRANS_SINE
	)
	if not await wait(cfg.travel_seconds):
		return false
	await ctx.fade(Color.WHITE, 1.0, 0.45)
	return alive()


## Vuelve a la arena (ya en el círculo nuevo) tumbado y se levanta.
func _wake_up() -> void:
	var player: Player = ctx.player
	_pocket.queue_free()
	_text_layer.queue_free()
	player.global_transform = _origin
	player.velocity = Vector3.ZERO
	player.set_head_height(WAKE_HEAD_HEIGHT)
	await ctx.fade(Color.WHITE, 0.0, 1.0)
	if not alive():
		return
	var rise: Tween = create_tween()
	rise.tween_method(
		player.set_head_height, WAKE_HEAD_HEIGHT, _head_y, maxf(cfg.arrival_seconds, 0.3)
	)
	rise.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ctx.set_cinematic_view(false)
	await rise.finished
	if not alive():
		return
	ctx.show_banner_now()
	ctx.lock_all(false)


## Restos del alma del jefe que vuelan desde el sello hasta los ojos de Zahariel.
func _absorb_soul() -> void:
	var cam: Camera3D = ctx.camera
	if cam == null:
		return
	var start: Vector3 = _seal_position + Vector3.UP * 1.3
	for i in 9:
		var soul := make_sprite(SPRITE_SOUL + i % 3, 0.03)
		soul.global_position = (
			start + Vector3(randf_range(-1, 1), randf_range(-0.5, 1), randf_range(-1, 1))
		)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		var dur: float = SOUL_FLIGHT_SECONDS * randf_range(0.7, 1.0)
		(
			tw
			. tween_property(soul, "global_position", cam.global_position, dur)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		tw.tween_property(soul, "pixel_size", 0.005, dur)
		tw.chain().tween_callback(soul.queue_free)
	var base_fov: float = cam.fov
	var fov_tw: Tween = create_tween()
	fov_tw.tween_property(cam, "fov", base_fov + FOV_PULSE, SOUL_FLIGHT_SECONDS * 0.8)
	fov_tw.tween_property(cam, "fov", base_fov, 0.3)
	ctx.player.add_camera_shake(0.35, SOUL_FLIGHT_SECONDS)


## El vacío de la visión: nombre del círculo gigante, siluetas con ojos rojos, rocas que flotan
## y brasas que suben.
func _build_pocket() -> void:
	_pocket = Node3D.new()
	add_child(_pocket)
	_pocket.global_position = POCKET
	var tint: Color = ctx.next_circle_fog_color().lightened(0.45)
	var title := Label3D.new()
	title.text = ctx.next_circle_name()
	title.font_size = 200
	title.outline_size = 32
	title.pixel_size = 0.012
	title.modulate = tint.lightened(0.3)
	title.outline_modulate = Color(0.05, 0.0, 0.0)
	title.shaded = false
	title.no_depth_test = true
	title.render_priority = 10
	title.outline_render_priority = 9
	title.position = Vector3(0.0, 3.2, -12.0)
	_pocket.add_child(title)
	var dark := make_unshaded(Color(0.02, 0.01, 0.02))
	var eye := make_unshaded(Color(1.0, 0.15, 0.05))
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.7
	body_mesh.height = 4.2
	body_mesh.radial_segments = 6
	body_mesh.rings = 2
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.09
	eye_mesh.height = 0.18
	eye_mesh.radial_segments = 4
	eye_mesh.rings = 2
	for i in 7:
		# Siluetas en semicírculo a los lados y al fondo: el nombre queda libre al centro.
		var ang: float = lerpf(-1.25, 1.25, float(i) / 6.0)
		var x: float = sin(ang) * 15.0
		var z: float = -cos(ang) * 15.0 - 6.0
		var body := MeshInstance3D.new()
		body.mesh = body_mesh
		body.material_override = dark
		body.position = Vector3(x, 1.6, z)
		body.scale = Vector3.ONE * randf_range(0.8, 1.5)
		_pocket.add_child(body)
		for side in [-0.22, 0.22]:
			var e := MeshInstance3D.new()
			e.mesh = eye_mesh
			e.material_override = eye
			e.position = Vector3(side, 1.35, 0.62)
			body.add_child(e)
	var rock_mesh := BoxMesh.new()
	rock_mesh.size = Vector3(1.2, 0.8, 1.0)
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.18, 0.14, 0.13)
	for i in 12:
		var rock := MeshInstance3D.new()
		rock.mesh = rock_mesh
		rock.material_override = rock_mat
		rock.position = Vector3(randf_range(-16, 16), randf_range(-3, 9), randf_range(-22, -4))
		rock.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		rock.scale = Vector3.ONE * randf_range(0.4, 1.6)
		_pocket.add_child(rock)
		var spin: Tween = rock.create_tween().set_loops()
		spin.tween_property(rock, "rotation:y", TAU, randf_range(8.0, 14.0)).as_relative()
	for i in 24:
		var ember := make_sprite(SPRITE_SPARK, 0.008, _pocket)
		ember.position = Vector3(randf_range(-12, 12), randf_range(-4, 2), randf_range(-20, -3))
		var up: Tween = ember.create_tween().set_loops()
		up.tween_property(ember, "position:y", 10.0, randf_range(3.0, 6.0)).as_relative()
		up.tween_property(ember, "position:y", -10.0, 0.0).as_relative()
	var glow := OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 2.5
	glow.omni_range = 30.0
	glow.position = Vector3(0.0, 6.0, -18.0)
	_pocket.add_child(glow)


## Frase del círculo en pantalla, escribiéndose letra a letra.
func _show_quote() -> void:
	_text_layer = CanvasLayer.new()
	_text_layer.layer = 19
	add_child(_text_layer)
	var label := Label.new()
	var idx: int = ctx.game_flow.call("circle_index_for_round", ctx.next_circle_round)
	var clamped_idx: int = clampi(idx, 0, QUOTES.size() - 1)
	var fallback_quote: String = QUOTES[clamped_idx]
	label.text = (
		LocalizationManager.t("vision.quote.%d" % clamped_idx, fallback_quote)
		if clamped_idx > 0
		else ""
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_top = -120.0
	label.offset_bottom = -60.0
	label.offset_left = 80.0
	label.offset_right = -80.0
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	label.visible_ratio = 0.0
	_text_layer.add_child(label)
	var tw: Tween = create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(label, "visible_ratio", 1.0, maxf(cfg.travel_seconds * 0.55, 0.5))


func cancel() -> void:
	super.cancel()
	if is_instance_valid(_text_layer):
		_text_layer.queue_free()
	if ctx != null and ctx.game_flow != null:
		ctx.game_flow.call("fade_screen", Color.WHITE, 0.0, 0.2)
