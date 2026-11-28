class_name Sword
extends Weapon
## Espada: arma melee inicial de Zahariel (GDD §6.1).
## Lógica modular separada:
## 1. Detección de daño (hit/raycasts del arco frontal limpio)
## 2. Animación procedural del arma (Tween)
## 3. Efecto visual independiente (Whoosh)

signal hit_enemy(enemy: Object, hit_position: Vector3)

## Altura (sobre los pies) del punto al que se apunta en cada enemigo para la línea de visión.
const TARGET_HEIGHT: float = 0.9
const MAX_TARGETS: int = 32
const SLASH_MARKS: int = 7
const SLASH_REACH_X: float = 0.35
const SLASH_RAISE_Y: float = 0.3
const SLASH_DROP_Y: float = 0.25
## Qué tan rápido (1/segundos) se desvanece la pose del pack al terminar la animación.
const PACK_FADE_SPEED: float = 8.0
# La Espada en Llamas (habilidad, issue #43): poses relativas a la pose de reposo.
const ABILITY_WINDUP_OFFSET: Vector3 = Vector3(-0.10, 0.04, 0.06)
const ABILITY_WINDUP_ROT_DEG: Vector3 = Vector3(8.0, 0.0, 18.0)
const ABILITY_STRIKE_OFFSET: Vector3 = Vector3(-0.40, -0.38, -0.14)
const ABILITY_STRIKE_ROT_DEG: Vector3 = Vector3(-85.0, 20.0, 50.0)
const ABILITY_RAISE_SECONDS: float = 0.15
const ABILITY_STRIKE_SECONDS: float = 0.07
const ABILITY_FOLLOW_SECONDS: float = 0.08
const ABILITY_RECOVER_SECONDS: float = 0.40
## Temblor de la espada al cargar: mínimo al empezar, máximo a carga completa.
const ABILITY_SHAKE_MIN: float = 0.002
const ABILITY_SHAKE: float = 0.014
## Segundos que la hoja sigue ardiendo tras soltar el tajo.
const FLAME_AFTER_SECONDS: float = 0.3
const FLAME_TEXTURE: Texture2D = preload("res://assets/textures/fire/flame_sprites.png")
## Tamaño de cada llama (16x24 px) y escala con carga mínima / completa.
const FLAME_SIZE: Vector2 = Vector2(0.09, 0.135)
const FLAME_SCALE_MIN: float = 0.35
const FLAME_SCALE_MAX: float = 1.4
const FLAME_RISE: float = 0.6
## Inclinación de la onda: diagonal "/" como el tajo de la animación.
const ABILITY_WAVE_ROLL_DEG: float = -35.0
## Giro de 180° en Y: pasa del personaje (mira a +Z) a la cámara (mira a -Z).
const CAMERA_FLIP: Basis = Basis(
	Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, -1.0)
)

## Llamas compartidas por todas las espadas (se crean una vez).
static var _flame_mesh: QuadMesh
static var _flame_material: StandardMaterial3D
static var _flame_curve: Curve

## Medidas del modelo "Espada PS1" (las da el visor scenes/Debug/anim_viewer.tscn):
## dirección de la hoja, dirección del ancho de la guarda y centro del mango.
@export var model_blade_dir: Vector3 = Vector3(0.0, -1.0, 0.0)
@export var model_wide_dir: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var model_grip_center: Vector3 = Vector3(0.0, 0.835771, 0.0)
## Hoja en el espacio de la malla de la espada: de la punta (y = 0) a la guarda.
@export var blade_length: float = 0.745
## La Espada en Llamas (habilidad única, tecla de habilidad). Sin recurso = sin habilidad.
@export var slash_wave: SlashWaveData

var _original_rotation: Vector3
var _original_position: Vector3
var _slash_tween: Tween
# Arranca en true: el primer ataque alterna a false y hace el tajo "\".
var _slash_alternate: bool = true
var _original_basis: Basis
## Estela de corte reutilizada en cada ataque (un solo nodo, malla y material).
var _whoosh_node: MeshInstance3D
var _whoosh_mesh: ImmediateMesh
var _whoosh_material: StandardMaterial3D
var _whoosh_tween: Tween
## Cada ataque lleva un número: si cambia durante el retraso del golpe, el golpe se cancela.
var _attack_id: int = 0
## Consulta de esfera reutilizada (no se crea una por tajo).
var _hit_shape: SphereShape3D
var _hit_query: PhysicsShapeQueryParameters3D
var _ability_unlocked: bool = false
var _ability_cooldown_left: float = 0.0
var _windup_base: Vector3
var _charging: bool = false
var _charge_time: float = 0.0
var _release_requested: bool = false
var _flames: CPUParticles3D
var _flame_off_left: float = 0.0


func _ready() -> void:
	super._ready()
	if _mesh_instance != null:
		_mesh_instance.position = Vector3(0.0, 0.4, -0.05)
	_original_rotation = rotation
	_original_position = position
	_original_basis = basis
	_ability_unlocked = slash_wave != null and slash_wave.unlocked_by_default
	_setup_flames()


func _process(delta: float) -> void:
	super._process(delta)
	_ability_cooldown_left = maxf(_ability_cooldown_left - delta, 0.0)
	if _charging:
		_step_charge(delta)
	elif _flame_off_left > 0.0:
		_flame_off_left -= delta
		if _flame_off_left <= 0.0:
			_set_flames(false, 0.0)


## La tienda (§8.1) llama a esto al comprar La Espada en Llamas.
func unlock_ability() -> void:
	_ability_unlocked = slash_wave != null


func is_ability_unlocked() -> bool:
	return _ability_unlocked


## Segundos que faltan para poder volver a usar La Espada en Llamas.
func get_ability_cooldown_left() -> float:
	return _ability_cooldown_left


## La Espada en Llamas: al pulsar empieza a cargar (la espada sube y se prende en fuego).
func try_ability() -> bool:
	if not _ability_unlocked or slash_wave == null or _charging:
		return false
	if _ability_cooldown_left > 0.0 or _cooldown > 0.0:
		return false
	_attack_id += 1
	_charging = true
	_charge_time = 0.0
	_release_requested = false
	_play_charge_animation()
	_set_flames(true, 0.0)
	return true


## Al soltar la tecla se lanza el tajo con la carga acumulada (tras la subida mínima).
func release_ability() -> void:
	if _charging:
		_release_requested = true


## Carga de 0 (toque) a 1 (completa).
func get_ability_charge() -> float:
	if not _charging or slash_wave == null:
		return 0.0
	return clampf(_charge_time / maxf(slash_wave.charge_seconds, 0.01), 0.0, 1.0)


func is_charging_ability() -> bool:
	return _charging


func _step_charge(delta: float) -> void:
	_charge_time += delta
	# Mientras carga no se ataca con clic izquierdo.
	_cooldown = maxf(_cooldown, 0.1)
	var charge: float = get_ability_charge()
	_set_flames(true, charge)
	if _charge_time >= ABILITY_RAISE_SECONDS:
		var amount: float = lerpf(ABILITY_SHAKE_MIN, ABILITY_SHAKE, charge)
		position = (
			_windup_base + Vector3(randf_range(-amount, amount), randf_range(-amount, amount), 0.0)
		)
	if _release_requested and _charge_time >= maxf(slash_wave.min_windup_seconds, 0.0):
		_strike(charge)


## Punto de entrada del ataque: dispara cada módulo por separado sin mezclarse.
## El golpe conecta tras hit_delay_seconds para coincidir con el tajo de la animación.
func _perform_attack() -> void:
	_slash_alternate = not _slash_alternate
	_attack_id += 1
	var attack_id: int = _attack_id
	_play_weapon_animation(_slash_alternate)
	_show_whoosh_effect(_slash_alternate)
	if data.hit_delay_seconds > 0.0:
		await get_tree().create_timer(data.hit_delay_seconds).timeout
		# Si se guardó el arma (o hubo otro ataque) durante el tajo, el golpe se cancela.
		if not is_inside_tree() or not visible or attack_id != _attack_id:
			return
	_perform_combat_hit()


# ==============================================================================
# MÓDULO 1: COMBATE Y DAÑO (HIT TOTALMENTE INDEPENDIENTE)
# Todo se calcula en espacio de mundo desde la cámara, sin usar la rotación del arma.
# Sector frontal: cuerpos dentro de una esfera (alcance), dentro del ángulo del arco
# (en el plano horizontal, así acierta a cualquier altura) y sin pared de por medio.
# ==============================================================================
func _perform_combat_hit() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		# Mirando casi recto arriba o abajo: se usa el frente del jugador.
		forward = -camera.global_basis.y
		forward.y = 0.0
	forward = forward.normalized()

	var exclude: Array[RID] = _player_exclude()

	var space_state := get_world_3d().direct_space_state
	# Las marcas rojas del tajo son ayuda de depuración: no corren en el juego exportado.
	if OS.is_debug_build():
		_mark_slash_line(space_state, camera, exclude)
	if _hit_shape == null:
		_hit_shape = SphereShape3D.new()
		_hit_query = PhysicsShapeQueryParameters3D.new()
		_hit_query.shape = _hit_shape
		_hit_query.collision_mask = HIT_MASK
	_hit_shape.radius = data.max_range
	var shape_query: PhysicsShapeQueryParameters3D = _hit_query
	shape_query.transform = Transform3D(Basis.IDENTITY, origin)
	shape_query.exclude = exclude

	var min_dot: float = cos(deg_to_rad(data.arc_angle_degrees * 0.5))
	var hit_targets: Array[Object] = []

	for result in space_state.intersect_shape(shape_query, MAX_TARGETS):
		var collider := result["collider"] as Node3D
		# El daño solo se aplica 1 vez por enemigo en este tajo
		if collider == null or hit_targets.has(collider) or not collider.has_method("take_damage"):
			continue
		var target_point: Vector3 = collider.global_position + Vector3.UP * TARGET_HEIGHT
		var to_target: Vector3 = target_point - origin
		var flat: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
		# Pegado al jugador siempre cuenta; si no, debe caer dentro del arco.
		if flat.length() > 0.3 and forward.dot(flat.normalized()) < min_dot:
			continue
		if not _has_line_of_sight(space_state, origin, target_point, exclude, collider):
			continue
		hit_targets.append(collider)
		var roll: Dictionary = roll_damage()
		collider.call("take_damage", roll["damage"], roll["crit"])
		var normal: Vector3 = -to_target.normalized()
		_spawn_impact(target_point, normal, ENEMY_IMPACT_SCALE)
		hit_enemy.emit(collider, target_point)
		hit_target.emit(collider, target_point, normal)
	if not hit_targets.is_empty():
		var player_node := _player_body
		if player_node == null or not is_instance_valid(player_node):
			player_node = get_tree().get_first_node_in_group("player") as CollisionObject3D
			_player_body = player_node
		if player_node != null:
			if player_node.has_method("add_camera_punch"):
				player_node.call("add_camera_punch", 0.85)
			if player_node.has_method("add_camera_shake"):
				player_node.call("add_camera_shake", 0.35, 0.12)
		Enemy._trigger_hit_stop(get_tree(), 0.035, 0.85, false)


## Ninguna pared debe estar entre el jugador y el enemigo.
func _has_line_of_sight(
	space_state: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	exclude: Array[RID],
	_target: CollisionObject3D
) -> bool:
	if _ray_query == null:
		_ray_query = PhysicsRayQueryParameters3D.new()
	_ray_query.from = from
	_ray_query.to = to
	_ray_query.collision_mask = 2
	_ray_query.exclude = exclude
	return space_state.intersect_ray(_ray_query).is_empty()


func _exit_tree() -> void:
	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	if is_instance_valid(_whoosh_node):
		_whoosh_node.queue_free()
	_whoosh_node = null


## Además de los efectos base, dibuja la estela de corte (transparente) con alfa 0.
func prewarm() -> void:
	super.prewarm()
	_prewarm_fire()
	_show_whoosh_effect(true)
	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	if _whoosh_material != null:
		_whoosh_material.albedo_color.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if _whoosh_node != null and is_instance_valid(_whoosh_node):
		_whoosh_node.visible = false


## Compila las llamas y la media luna de fuego al cargar (apagadas o diminutas, 2 frames).
func _prewarm_fire() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and get_tree().current_scene != null:
		SlashWave.prewarm(
			get_tree().current_scene, camera.global_position - camera.global_basis.z * 3.0
		)
	if _flames == null:
		return
	_set_flames(true, 0.0)
	_flames.scale_amount_min = 0.001
	_flames.scale_amount_max = 0.001
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_flames) and not _charging and _flame_off_left <= 0.0:
		_set_flames(false, 0.0)


## Al guardar el arma: anula el golpe pendiente y deja la espada en reposo.
func cancel_reload() -> void:
	super.cancel_reload()
	_attack_id += 1
	_charging = false
	_release_requested = false
	_flame_off_left = 0.0
	_set_flames(false, 0.0)
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()
	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	if _whoosh_node != null and is_instance_valid(_whoosh_node):
		_whoosh_node.visible = false
	rotation = _original_rotation
	position = _original_position


# ==============================================================================
# MÓDULO 2: ANIMACIÓN PROCEDURAL DEL ARMA (VISUAL MODELO)
# ==============================================================================
func _play_weapon_animation(alternate: bool) -> void:
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()

	_slash_tween = create_tween()
	# Tajo en diagonal frente a la cámara: "\" (arriba-izquierda a abajo-derecha) y
	# "/" (arriba-derecha a abajo-izquierda) alternando. La punta pasa de atrás a adelante.
	var start_side: float = 1.0 if alternate else -1.0
	var start_pos: Vector3 = (
		_original_position + Vector3(start_side * SLASH_REACH_X, SLASH_RAISE_Y, 0.0)
	)
	var end_pos: Vector3 = (
		_original_position + Vector3(-start_side * SLASH_REACH_X, -SLASH_DROP_Y, 0.0)
	)
	var start_rot: Vector3 = (
		_original_rotation + Vector3(deg_to_rad(10.0), 0.0, deg_to_rad(-start_side * 35.0))
	)
	var end_rot: Vector3 = (
		_original_rotation + Vector3(deg_to_rad(-65.0), 0.0, deg_to_rad(start_side * 35.0))
	)

	_slash_tween.tween_property(self, "position", start_pos, 0.07)
	_slash_tween.parallel().tween_property(self, "rotation", start_rot, 0.07)
	(
		_slash_tween
		. tween_property(self, "position", end_pos, 0.12)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", end_rot, 0.12)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. tween_property(self, "position", _original_position, 0.35)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", _original_rotation, 0.35)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


## Sube la espada atrás y arriba para cargar; el temblor lo añade _step_charge().
func _play_charge_animation() -> void:
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()
	_windup_base = _original_position + ABILITY_WINDUP_OFFSET
	var windup_rot: Vector3 = _original_rotation + _deg_vec(ABILITY_WINDUP_ROT_DEG)
	_slash_tween = create_tween()
	(
		_slash_tween
		. tween_property(self, "position", _windup_base, ABILITY_RAISE_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", windup_rot, ABILITY_RAISE_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


## Suelta el tajo: lanza la media luna de fuego y corta en diagonal muy rápido.
func _strike(charge: float) -> void:
	_charging = false
	_release_requested = false
	_ability_cooldown_left = maxf(slash_wave.cooldown_seconds, 0.01)
	_cooldown = ABILITY_STRIKE_SECONDS + ABILITY_FOLLOW_SECONDS + 0.15
	_flame_off_left = FLAME_AFTER_SECONDS
	_release_slash_wave(charge)
	if _slash_tween != null and _slash_tween.is_valid():
		_slash_tween.kill()
	var strike_pos: Vector3 = _original_position + ABILITY_STRIKE_OFFSET
	var strike_rot: Vector3 = _original_rotation + _deg_vec(ABILITY_STRIKE_ROT_DEG)
	_slash_tween = create_tween()
	(
		_slash_tween
		. tween_property(self, "position", strike_pos, ABILITY_STRIKE_SECONDS)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", strike_rot, ABILITY_STRIKE_SECONDS)
		. set_trans(Tween.TRANS_EXPO)
		. set_ease(Tween.EASE_OUT)
	)
	_slash_tween.tween_interval(ABILITY_FOLLOW_SECONDS)
	(
		_slash_tween
		. tween_property(self, "position", _original_position, ABILITY_RECOVER_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_slash_tween
		. parallel()
		. tween_property(self, "rotation", _original_rotation, ABILITY_RECOVER_SECONDS)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)


func _release_slash_wave(charge: float) -> void:
	if not is_inside_tree() or not visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	var scene: Node = get_tree().current_scene
	if camera == null or scene == null or slash_wave == null:
		return
	var dir: Vector3 = -camera.global_basis.z
	var origin: Vector3 = camera.global_position + dir * 1.2 - camera.global_basis.y * 0.15
	SlashWave.launch(
		scene,
		origin,
		dir,
		ABILITY_WAVE_ROLL_DEG,
		slash_wave,
		charge,
		data.crit_chance,
		data.crit_multiplier,
		_player_exclude(),
		_on_slash_wave_hit
	)
	_show_whoosh_effect(true)
	_play_sfx(data.sfx_attack)
	var player := _player_body as Player
	if player != null:
		player.add_camera_punch(lerpf(0.5, 1.6, charge))
		player.add_camera_shake(lerpf(0.25, 0.8, charge), 0.18)


# ==============================================================================
# LLAMAS 2D DE LA HOJA (sprites pixel art en partículas billboard)
# ==============================================================================
func _setup_flames() -> void:
	var blade_mesh := _find_blade_mesh()
	if blade_mesh == null:
		return
	if _flame_mesh == null:
		_build_flame_resources()
	_flames = CPUParticles3D.new()
	_flames.name = "BladeFlames"
	_flames.mesh = _flame_mesh
	_flames.amount = 40
	_flames.lifetime = 0.35
	_flames.local_coords = true
	_flames.emitting = false
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flames.emission_box_extents = Vector3(0.025, blade_length * 0.5, 0.01)
	_flames.position = Vector3(0.0, blade_length * 0.5, 0.0)
	_flames.direction = Vector3.UP
	_flames.spread = 25.0
	_flames.initial_velocity_min = 0.05
	_flames.initial_velocity_max = 0.2
	_flames.scale_amount_curve = _flame_curve
	_flames.anim_speed_min = 1.0
	_flames.anim_speed_max = 1.4
	_flames.anim_offset_max = 1.0
	_flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.visible = false
	blade_mesh.add_child(_flames)


## La primera malla del modelo de la espada (en su espacio la hoja va de y = 0 a blade_length).
func _find_blade_mesh() -> MeshInstance3D:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance != _mesh_instance:
			return mesh_instance
	return null


static func _build_flame_resources() -> void:
	_flame_material = StandardMaterial3D.new()
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_flame_material.particles_anim_h_frames = 4
	_flame_material.particles_anim_v_frames = 1
	_flame_material.particles_anim_loop = true
	_flame_material.albedo_texture = FLAME_TEXTURE
	_flame_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_flame_material.alpha_scissor_threshold = 0.5
	_flame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flame_mesh = QuadMesh.new()
	_flame_mesh.size = FLAME_SIZE
	_flame_mesh.material = _flame_material
	_flame_curve = Curve.new()
	_flame_curve.add_point(Vector2(0.0, 0.6))
	_flame_curve.add_point(Vector2(0.3, 1.0))
	_flame_curve.add_point(Vector2(1.0, 0.0))


## Enciende/apaga la hoja; `charge` agranda las llamas y las hace subir más rápido.
func _set_flames(on: bool, charge: float) -> void:
	if _flames == null:
		return
	if not on:
		_flames.emitting = false
		_flames.visible = false
		return
	_flames.visible = true
	_flames.emitting = true
	var flame_scale: float = lerpf(FLAME_SCALE_MIN, FLAME_SCALE_MAX, charge)
	_flames.scale_amount_min = flame_scale * 0.8
	_flames.scale_amount_max = flame_scale * 1.2
	# Con coordenadas locales la gravedad va en el espacio de la hoja: se reorienta hacia arriba
	# del mundo para que el fuego siempre suba aunque la espada esté inclinada.
	var world_to_blade: Basis = _flames.global_basis.orthonormalized().inverse()
	_flames.gravity = world_to_blade * Vector3.UP * lerpf(FLAME_RISE, FLAME_RISE * 2.5, charge)


func _on_slash_wave_hit(target: Object, point: Vector3, normal: Vector3) -> void:
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_spawn_impact(point, normal, ENEMY_IMPACT_SCALE)
	hit_enemy.emit(target, point)
	hit_target.emit(target, point, normal)


static func _deg_vec(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))


# ==============================================================================
# MÓDULO 3: ESTELA DE CORTE (WHOOSH VISUAL EN PANTALLA)
# ==============================================================================
func _show_whoosh_effect(alternate: bool) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	if _whoosh_mesh == null:
		_whoosh_mesh = ImmediateMesh.new()
		_whoosh_material = StandardMaterial3D.new()
		_whoosh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_whoosh_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_whoosh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_whoosh_material.albedo_color = Color(0.9, 0.95, 1.0, 0.85)

	var half_angle: float = deg_to_rad(data.arc_angle_degrees * 0.5)
	var steps: int = 16

	_whoosh_mesh.clear_surfaces()
	_whoosh_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _whoosh_material)
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var angle: float
		var y: float

		if alternate:
			# Diagonal /
			angle = half_angle - t * deg_to_rad(data.arc_angle_degrees)
			y = 0.18 - t * 0.42
		else:
			# Diagonal \
			angle = -half_angle + t * deg_to_rad(data.arc_angle_degrees)
			y = 0.18 - t * 0.42

		var x: float = sin(angle)
		var z: float = -cos(angle)

		_whoosh_mesh.surface_add_vertex(Vector3(x * 0.5, y * 0.5, z * 0.7))
		_whoosh_mesh.surface_add_vertex(Vector3(x * 1.1, y * 1.1, z * 1.3))
	_whoosh_mesh.surface_end()

	if _whoosh_node == null or not is_instance_valid(_whoosh_node):
		_whoosh_node = MeshInstance3D.new()
		_whoosh_node.mesh = _whoosh_mesh
		_whoosh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _whoosh_node.get_parent() != camera:
		if _whoosh_node.get_parent() != null:
			_whoosh_node.get_parent().remove_child(_whoosh_node)
		camera.add_child(_whoosh_node)
	_whoosh_node.position = Vector3(0.0, -0.05, 0.0)
	_whoosh_node.rotation = Vector3.ZERO
	_whoosh_node.visible = true

	if _whoosh_tween != null and _whoosh_tween.is_valid():
		_whoosh_tween.kill()
	_whoosh_tween = _whoosh_node.create_tween()
	_whoosh_tween.tween_property(_whoosh_material, "albedo_color:a", 0.0, 0.2)
	_whoosh_tween.tween_callback(_whoosh_node.set_visible.bind(false))


## Marca con puntos rojos en línea la superficie que recorre el tajo (diagonal, como el whoosh).
func _mark_slash_line(
	space_state: PhysicsDirectSpaceState3D, camera: Camera3D, exclude: Array[RID]
) -> void:
	var from: Vector3 = camera.global_position
	var half_angle: float = deg_to_rad(data.arc_angle_degrees * 0.5)
	for i in range(SLASH_MARKS):
		var t: float = float(i) / float(SLASH_MARKS - 1)
		var yaw: float = lerpf(half_angle, -half_angle, t) * (1.0 if _slash_alternate else -1.0)
		var pitch: float = lerpf(0.18, -0.24, t)
		var dir: Vector3 = (camera.global_basis * Vector3(sin(yaw), pitch, -cos(yaw))).normalized()
		var query := PhysicsRayQueryParameters3D.create(
			from, from + dir * data.max_range, 0xFFFFFFFF, exclude
		)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty() or (hit["collider"] as Object).has_method("take_damage"):
			continue
		_spawn_impact(hit["position"], hit["normal"])
