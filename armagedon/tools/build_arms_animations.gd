extends SceneTree
## Genera assets/animations/arms/arms_custom.res: animaciones de los brazos (espada, escudo, pistola).
## Uso: godot --headless --path armagedon -s res://tools/build_arms_animations.gd
##
## - Los dedos salen de la pose de puño que hiciste a mano en `sword_idle` (scenes/Test/arms_test.tscn);
##   la mano izquierda usa el puño reflejado.
## - El recorrido de cada mano se toma de las animaciones del pack (knife_*, guard_idle, finger_gun_*)
##   y un resolutor calcula hombro-codo-muñeca para que la mano pase por esos puntos con TUS dedos.
## - Cada animación queda con claves cada pocas décimas: ábrelas en el editor y retócalas.

const ARMS_SCENE := "res://scenes/Player/player_arms.tscn"
const USER_SCENE := "res://scenes/Test/arms_test.tscn"
const OUT := "res://assets/animations/arms/arms_custom.res"
const ARMS_POS := Vector3(0, -1.26423, 0.27001363)
const ARM_BONES := {
	"R": ["upper_arm.R", "forearm.R", "hand.R"],
	"L": ["upper_arm.L", "forearm.L", "hand.L"],
}
## Estilo de dedos por mano y animación.
const SWORD := "sword"
const GUN := "gun"

## nombre, clip del pack, paso entre claves (s), bucle, dedos mano derecha
const ANIMS := [
	["sword_idle", "knife_idle", 0.5, true, SWORD],
	["sword_hit_a", "knife_hit_01", 0.1, false, SWORD],
	["sword_hit_b", "knife_hit_02", 0.1, false, SWORD],
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


func _init() -> void:
	await process_frame
	_setup()
	await process_frame
	_read_user_fist()
	var lib := AnimationLibrary.new()
	for def in ANIMS:
		var anim := _build_animation(def)
		lib.add_animation(def[0], anim)
		print("listo: ", def[0], " (", anim.length, " s)")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(lib, OUT)
	print("guardado ", OUT, " -> ", error_string(err))
	quit()


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


func _read_user_fist() -> void:
	var user: Node = load(USER_SCENE).instantiate()
	var player := user.find_child("CustomAnim", true, false) as AnimationPlayer
	var anim: Animation = player.get_animation("sword_idle")
	for i in anim.get_track_count():
		var path := str(anim.track_get_path(i))
		if anim.track_get_type(i) == Animation.TYPE_ROTATION_3D and path.begins_with("Skeleton3D:"):
			fist[path.get_slice(":", 1)] = anim.rotation_track_interpolate(i, 0.0)
	user.free()


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
	return pos_err * 10.0 + rot_err * 1.0 + reg * 0.02


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
