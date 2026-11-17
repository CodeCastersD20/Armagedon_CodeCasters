extends SceneTree
## Genera assets/animations/arms/arms_custom.res: animaciones de los brazos (espada, escudo, pistola).
## Uso: godot --headless --path armagedon -s res://tools/build_arms_animations.gd
##
## - Los dedos salen de la pose de puño de `sword_idle` TAL COMO ESTÁ en el recurso (la que retocaste a mano);
##   la mano izquierda usa el puño reflejado. `sword_idle` no se regenera, solo se actualizan sus dedos izquierdos.
## - `sword_hit_a/b` se definen por poses de la HOJA (hacia dónde apunta) y de la mano, en ejes de cámara,
##   partiendo de tu pose de `sword_idle`. A corta de arriba-derecha a abajo-izquierda y B al revés.
##   Si el giro te queda al lado contrario, cambia SLASH_FLIP a -1.0.
## - El recorrido de cada mano se toma de las animaciones del pack (knife_*, guard_idle, finger_gun_*)
##   y un resolutor calcula hombro-codo-muñeca para que la mano pase por esos puntos con TUS dedos.
## - Cada animación queda con claves cada pocas décimas: ábrelas en el editor y retócalas.

const ARMS_SCENE := "res://scenes/Player/player_arms.tscn"
## 1.0: A corta de derecha a izquierda (y B de izquierda a derecha); -1.0 los invierte.
const SLASH_FLIP := 1.0
## Giro del modelo de la espada respecto a la mano (grados): es arms_grip_rotation_degrees de sword.tscn.
## Con él se sabe hacia dónde apunta la hoja (-Y del modelo) y el filo (X del modelo) en ejes de la mano.
const GRIP_EULER_DEG := Vector3(7.3998, 72.1699, -102.3824)
## Poses del tajo A (derecha -> izquierda): [tiempo, dirección de la hoja en ejes de cámara
## (x derecha, y arriba, z hacia atrás), hacia dónde mira el filo (Vector3.ZERO = como en reposo),
## desplazamiento de la mano en metros, cuánto cruza hacia el centro del cuerpo en el tajo B (0 a 1)].
## Entre poses se suaviza.
const SLASH_KEYS := [
	[0.00, Vector3(0.00, 1.00, -0.15), Vector3.ZERO, Vector3(0.00, 0.00, 0.00), 0.0],
	[0.14, Vector3(0.45, 0.85, 0.25), Vector3.ZERO, Vector3(0.06, 0.08, 0.08), 0.3],
	[0.26, Vector3(0.00, 0.30, -0.95), Vector3(-1.0, 0.0, 0.0), Vector3(-0.02, 0.00, -0.18), 0.8],
	[0.34, Vector3(-0.85, -0.45, -0.30), Vector3(-0.6, -0.7, 0.2), Vector3(-0.18, -0.12, -0.08), 1.0],
	[0.50, Vector3(-0.75, -0.30, -0.35), Vector3(-0.6, -0.7, 0.2), Vector3(-0.14, -0.08, -0.05), 1.0],
	[0.95, Vector3(0.00, 1.00, -0.15), Vector3.ZERO, Vector3(0.00, 0.00, 0.00), 0.0],
]
## En el tajo B la mano parte de la derecha: cruza esta distancia (m) hacia el centro para que la hoja no salga de cuadro.
const SLASH_B_CROSS := 0.22
const SLASH_STEP := 0.025
## Peso de la orientación de la mano frente a su posición al resolver el tajo.
const SLASH_ROT_WEIGHT := 3.0
const OUT := "res://assets/animations/arms/arms_custom.res"
const ARMS_POS := Vector3(0, -1.26423, 0.27001363)
const ARM_BONES := {
	"R": ["upper_arm.R", "forearm.R", "hand.R"],
	"L": ["upper_arm.L", "forearm.L", "hand.L"],
}
## Estilo de dedos por mano y animación.
const SWORD := "sword"
const GUN := "gun"
## Giro de la muñeca derecha (grados, sobre el eje de los dedos) con la espada: deja la espada vertical
## (empuñadura a lo largo de los nudillos, pulgar hacia arriba).
const SWORD_ROLL_DEG := 90.0

## nombre, clip del pack, paso entre claves (s), bucle, dedos mano derecha
const ANIMS := [
	["guard", "guard_idle", 0.5, true, SWORD],
	["gun_idle", "finger_gun_idle", 0.5, true, GUN],
	["gun_fire", "finger_gun_fire", 0.05, false, GUN],
	["gun_reload", "finger_gun_fix", 0.1, false, GUN],
]

var cam: Camera3D
var sk: Skeleton3D
var pack_ap: AnimationPlayer
var bones: Array[String] = []
var default_pose := {}
var fist := {}
var mirror_mode: int = 0
var rot_weight: float = 1.0
var idle_arms := {}  # huesos de brazo de sword_idle (R y L), tal cual


func _init() -> void:
	await process_frame
	_setup()
	await process_frame
	var lib: AnimationLibrary = ResourceLoader.load(OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as AnimationLibrary
	if lib == null or not lib.has_animation("sword_idle"):
		push_error("Falta %s con sword_idle: no hay pose base." % OUT)
		quit(1)
		return
	_read_idle(lib)
	_patch_idle_left_fingers(lib)
	for def in ANIMS:
		_replace(lib, def[0], _build_animation(def))
	_replace(lib, "sword_hit_a", _build_hit(SLASH_FLIP))
	_replace(lib, "sword_hit_b", _build_hit(-SLASH_FLIP))
	var err := ResourceSaver.save(lib, OUT)
	print("guardado ", OUT, " -> ", error_string(err))
	quit()


func _replace(lib: AnimationLibrary, anim_name: String, anim: Animation) -> void:
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, anim)
	print("listo: ", anim_name, " (", snappedf(anim.length, 0.01), " s)")


func _setup() -> void:
	cam = Camera3D.new()
	cam.fov = 90.0
	root.add_child(cam)
	var arms: Node3D = load(ARMS_SCENE).instantiate()
	cam.add_child(arms)
	arms.position = ARMS_POS
	arms.set_process(false)
	for ap in arms.find_children("*", "AnimationPlayer", true, false):
		if (ap as AnimationPlayer).has_animation("knife_idle"):
			pack_ap = ap
		(ap as AnimationPlayer).stop()
		(ap as AnimationPlayer).active = false
	sk = arms.find_children("*", "Skeleton3D", true, false)[0]
	for i in range(1, 47):
		bones.append(sk.get_bone_name(i))
		default_pose[sk.get_bone_name(i)] = sk.get_bone_pose_rotation(i)


func _read_idle(lib: AnimationLibrary) -> void:
	var anim: Animation = lib.get_animation("sword_idle")
	for i in anim.get_track_count():
		var path := str(anim.track_get_path(i))
		if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D or not path.begins_with("Skeleton3D:"):
			continue
		var bone := path.get_slice(":", 1)
		var q: Quaternion = anim.rotation_track_interpolate(i, 0.0)
		if bone.ends_with(".R") and _is_finger(bone):
			fist[bone] = q
		if ARM_BONES["R"].has(bone) or ARM_BONES["L"].has(bone):
			idle_arms[bone] = q


## Reescribe en sword_idle solo los dedos de la mano izquierda (reflejo del puño derecho actual).
func _patch_idle_left_fingers(lib: AnimationLibrary) -> void:
	var anim: Animation = lib.get_animation("sword_idle")
	var left := finger_pose(SWORD)
	for b in left:
		if not (b as String).ends_with(".L"):
			continue
		var t := anim.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		if t >= 0:
			anim.track_set_key_value(t, 0, left[b])


# ---- dedos ----------------------------------------------------------------------------------

func _is_finger(b: String) -> bool:
	return b.begins_with("palm") or b.begins_with("f_") or b.begins_with("thumb")


func _mirror(q: Quaternion) -> Quaternion:
	match mirror_mode:
		0: return Quaternion(q.x, -q.y, -q.z, q.w)
		1: return Quaternion(-q.x, q.y, -q.z, q.w)
		2: return Quaternion(-q.x, -q.y, q.z, q.w)
	return q


func finger_pose(right_style: String) -> Dictionary:
	var pose := {}
	for b in bones:
		if not _is_finger(b):
			continue
		if b.ends_with(".R"):
			var q: Quaternion = fist.get(b, default_pose[b])
			# Pistola: el índice se queda estirado sobre el gatillo.
			if right_style == GUN and b.begins_with("f_index"):
				q = default_pose[b]
			pose[b] = q
		else:
			var rb := b.trim_suffix(".L") + ".R"
			var delta: Quaternion = (default_pose[rb] as Quaternion).inverse() * (fist.get(rb, default_pose[rb]) as Quaternion)
			pose[b] = (default_pose[b] as Quaternion) * _mirror(delta)
	return pose


# ---- resolutor de brazos --------------------------------------------------------------------

func hand_cam(side: String) -> Transform3D:
	var idx := sk.find_bone("hand." + side)
	return cam.global_transform.affine_inverse() * (sk.global_transform * sk.get_bone_global_pose(idx))


func _loss(side: String, q: Dictionary, target: Transform3D) -> float:
	for n in ARM_BONES[side]:
		sk.set_bone_pose_rotation(sk.find_bone(n), q[n])
	var h := hand_cam(side)
	var pos_err: float = (h.origin - target.origin).length()
	var rot_err: float = h.basis.get_rotation_quaternion().angle_to(target.basis.get_rotation_quaternion())
	var reg: float = 0.0
	for n in ARM_BONES[side]:
		reg += (q[n] as Quaternion).angle_to(default_pose[n])
	return pos_err * 10.0 + rot_err * rot_weight + reg * 0.02


func solve(side: String, target: Transform3D, start: Dictionary) -> Dictionary:
	var q := {}
	for n in ARM_BONES[side]:
		q[n] = start[n]
	var best := _loss(side, q, target)
	for step in [25.0, 12.0, 6.0, 3.0, 1.5, 0.7]:
		var rad: float = deg_to_rad(step)
		for sweep in 8:
			var improved := false
			for n in ARM_BONES[side]:
				for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
					for sign in [-1.0, 1.0]:
						var cand := q.duplicate()
						cand[n] = (q[n] as Quaternion) * Quaternion(axis, rad * sign)
						var l := _loss(side, cand, target)
						if l < best - 0.00001:
							q = cand
							best = l
							improved = true
			if not improved:
				break
	return q


# ---- animaciones ----------------------------------------------------------------------------

func _sample_pack(clip: String, t: float) -> Dictionary:
	pack_ap.active = true
	pack_ap.play(clip)
	pack_ap.seek(t, true)
	pack_ap.advance(0.0)
	var result := {"R": hand_cam("R"), "L": hand_cam("L")}
	pack_ap.stop()
	pack_ap.active = false
	return result


func _build_animation(def: Array) -> Animation:
	var clip: String = def[1]
	var step: float = def[2]
	var length: float = pack_ap.get_animation(clip).length
	var times: Array[float] = []
	var t := 0.0
	while t < length - 0.001:
		times.append(t)
		t += step
	if not def[3]:
		times.append(length)  # los tajos terminan en la pose final del pack
	var fingers := finger_pose(def[4])
	var current := default_pose.duplicate()
	var arm_keys := {}  # hueso -> [[t, q], ...]
	for n in ARM_BONES["R"] + ARM_BONES["L"]:
		arm_keys[n] = []
	for time in times:
		var targets := _sample_pack(clip, time)
		# restaurar pose por defecto antes de resolver (el pack movió los huesos)
		if def[4] == SWORD:
			targets["R"].basis = (targets["R"] as Transform3D).basis * Basis(Vector3.UP, deg_to_rad(SWORD_ROLL_DEG))
		for side in ["R", "L"]:
			var q := solve(side, targets[side], current)
			for n in q:
				current[n] = q[n]
				arm_keys[n].append([time, q[n]])
	var anim := Animation.new()
	anim.length = length if not def[3] else length
	anim.loop_mode = Animation.LOOP_LINEAR if def[3] else Animation.LOOP_NONE
	for b in bones:
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("Skeleton3D:" + b))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		if arm_keys.has(b):
			for k in arm_keys[b]:
				anim.rotation_track_insert_key(track, k[0], k[1])
			if def[3]:
				anim.rotation_track_insert_key(track, length, arm_keys[b][0][1])  # cierra el bucle
		elif fingers.has(b):
			anim.rotation_track_insert_key(track, 0.0, fingers[b])
		else:
			anim.rotation_track_insert_key(track, 0.0, default_pose[b])
	return anim


# ---- tajos --------------------------------------------------------------------------------------

## Quita de `e` la parte paralela a `d` (el filo siempre es perpendicular a la hoja).
func _orth(e: Vector3, d: Vector3) -> Vector3:
	return (e - d * e.dot(d)).normalized()


## Poses del tajo con el filo de reposo ya resuelto y sin saltos de signo entre poses.
func _slash_keys(idle_edge: Vector3, flip: float) -> Array:
	var out: Array = []
	var prev_edge := Vector3.ZERO
	for k in SLASH_KEYS:
		var d: Vector3 = Vector3((k[1] as Vector3).x * flip, (k[1] as Vector3).y, (k[1] as Vector3).z).normalized()
		var e: Vector3 = idle_edge if (k[2] as Vector3) == Vector3.ZERO else Vector3((k[2] as Vector3).x * flip, (k[2] as Vector3).y, (k[2] as Vector3).z)
		e = _orth(e, d)
		if prev_edge != Vector3.ZERO and e.dot(prev_edge) < 0.0:
			e = -e  # la espada es simétrica: se elige el giro corto
		prev_edge = e
		var o: Vector3 = k[3]
		var cross_x: float = -SLASH_B_CROSS * (k[4] as float) if flip < 0.0 else 0.0
		out.append([k[0], d, e, Vector3(o.x * flip + cross_x, o.y, o.z)])
	return out


## Pose del tajo en el instante t: [dirección de la hoja, dirección del filo, desplazamiento de la mano].
func _slash_at(keys: Array, t: float) -> Array:
	var i := 0
	while i < keys.size() - 2 and t > keys[i + 1][0]:
		i += 1
	var k0: Array = keys[i]
	var k1: Array = keys[i + 1]
	var u: float = clampf((t - k0[0]) / (k1[0] - k0[0]), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)  # arranque y frenada suaves
	var dir: Vector3 = (k0[1] as Vector3).lerp(k1[1], u).normalized()
	var edge: Vector3 = _orth((k0[2] as Vector3).lerp(k1[2], u), dir)
	return [dir, edge, (k0[3] as Vector3).lerp(k1[3], u)]


func _build_hit(flip: float) -> Animation:
	# Pose de reposo (la tuya): se aplica y se mide dónde queda la mano derecha.
	apply_arm_pose(idle_arms)
	var idle: Transform3D = hand_cam("R")
	var grip := Basis.from_euler(GRIP_EULER_DEG * (PI / 180.0))
	var idle_edge: Vector3 = (idle.basis * grip * Vector3.RIGHT).normalized()
	var slash := _slash_keys(idle_edge, flip)
	var end_time: float = slash[slash.size() - 1][0]
	var current := idle_arms.duplicate()
	var keys := {}
	for n in ARM_BONES["R"]:
		keys[n] = []
	rot_weight = SLASH_ROT_WEIGHT
	var worst := 0.0
	var t := 0.0
	while true:
		var pose := _slash_at(slash, minf(t, end_time))
		# Espada deseada en ejes de cámara: X = filo, Y = -hoja (la hoja es -Y del modelo), Z = el resto.
		var edge: Vector3 = pose[1]
		var down: Vector3 = -(pose[0] as Vector3)
		var sword := Basis(edge, down, edge.cross(down))
		var target := Transform3D(sword * grip.inverse(), idle.origin + (pose[2] as Vector3))
		var q := solve("R", target, current)
		for n in q:
			current[n] = q[n]
			keys[n].append([minf(t, end_time), q[n]])
		var got: Vector3 = (hand_cam("R").basis * grip * Vector3(0, -1, 0)).normalized()
		worst = maxf(worst, rad_to_deg(got.angle_to(pose[0])))
		if t >= end_time:
			break
		t += SLASH_STEP
	rot_weight = 1.0
	print("   error máximo de la hoja: ", snappedf(worst, 0.1), "°")
	var anim := Animation.new()
	anim.length = end_time
	anim.loop_mode = Animation.LOOP_NONE
	var fingers := finger_pose(SWORD)
	for b in bones:
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath("Skeleton3D:" + b))
		anim.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
		if keys.has(b):
			for k in keys[b]:
				anim.rotation_track_insert_key(track, k[0], k[1])
		elif idle_arms.has(b):
			anim.rotation_track_insert_key(track, 0.0, idle_arms[b])  # mano izquierda quieta con el escudo
		elif fingers.has(b):
			anim.rotation_track_insert_key(track, 0.0, fingers[b])
		else:
			anim.rotation_track_insert_key(track, 0.0, default_pose[b])
	return anim


func apply_arm_pose(pose: Dictionary) -> void:
	for b in pose:
		sk.set_bone_pose_rotation(sk.find_bone(b), pose[b])
