class_name DebugView
extends Node3D
## Vista en tercera persona SOLO PARA DEPURAR. Con la tecla V alterna entre la cámara de primera
## persona y una cámara detrás del jugador. Muestra el maniquí de Universal Animation Library 2 con
## sus huesos y la espada en la mano derecha, y reproduce su animación de espada cuando atacas.
## El arma y el escudo de primera persona siguen colgados de la cámara,
## así se compara el movimiento. Solo funciona en depuración. Si falta el modelo
## (está en .gitignore), usa una cápsula.

const MANNEQUIN_PATH: String = "res://assets/animations/universal/UAL2_Standard.glb"
const SWORD_PATH: String = "res://assets/models/weapons/espada_ps1/Espada PS1.fbx"
const IDLE_CLIP: String = "Idle_Shield"
const HAND_BONE: String = "hand_r"

@export var toggle_key: Key = KEY_V
## Posición de la cámara de tercera persona, relativa a la cabeza (X derecha, Y arriba, Z atrás).
@export var camera_offset: Vector3 = Vector3(0.9, 0.5, 3.2)
@export var show_bones: bool = true
@export var show_mesh: bool = true

# Agarre de la espada en la mano (los mismos valores del visor y de WeaponData).
@export var grip_roll_degrees: float = 25.0
@export var grip_offset: Vector3 = Vector3(-0.02, 0.08, 0.0)
@export var sword_blade_dir: Vector3 = Vector3(0.0, -1.0, 0.0)
@export var sword_wide_dir: Vector3 = Vector3(1.0, 0.0, 0.0)
@export var sword_grip_center: Vector3 = Vector3(0.0, 0.835771, 0.0)

var _first_person_camera: Camera3D
var _third_person_camera: Camera3D
var _holder: Node3D
var _mannequin: Node3D
var _skeleton: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer
var _bones_mesh: ImmediateMesh
var _bones_node: MeshInstance3D
var _label: Label
var _active: bool = false
var _weapon: Weapon
var _slash_alternate: bool = true


func _ready() -> void:
	set_process(false)
	if not OS.is_debug_build():
		set_process_unhandled_input(false)
		return
	_build.call_deferred()


func _build() -> void:
	var player := get_parent() as Player
	var head: Node3D = player.get_node("Head")
	_first_person_camera = head.get_node("Camera3D") as Camera3D

	_third_person_camera = Camera3D.new()
	_third_person_camera.fov = 75.0
	head.add_child(_third_person_camera)
	_third_person_camera.position = camera_offset
	_third_person_camera.look_at(head.global_position)

	_holder = Node3D.new()
	_holder.visible = false
	add_child(_holder)
	if ResourceLoader.exists(MANNEQUIN_PATH):
		_build_mannequin()
	else:
		_build_capsule()

	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.text = "Tercera persona (depuración) - V para volver"
	_label.position = Vector2(8.0, 8.0)
	_label.visible = false
	layer.add_child(_label)

	var manager := get_tree().get_first_node_in_group("weapon_manager") as WeaponManager
	if manager != null:
		manager.weapon_changed.connect(_on_weapon_changed)
		_on_weapon_changed(manager.get_current_weapon())


func _build_capsule() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.7, 1.0, 0.45)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	capsule.material = material
	body.mesh = capsule
	body.position = Vector3(0.0, 0.9, 0.0)
	_holder.add_child(body)


func _build_mannequin() -> void:
	_mannequin = (load(MANNEQUIN_PATH) as PackedScene).instantiate() as Node3D
	# El maniquí mira a +Z; el jugador mira a -Z.
	_mannequin.rotation.y = PI
	_holder.add_child(_mannequin)
	var skeletons: Array[Node] = _mannequin.find_children("*", "Skeleton3D", true, false)
	var players: Array[Node] = _mannequin.find_children("*", "AnimationPlayer", true, false)
	if skeletons.is_empty() or players.is_empty():
		push_error("DebugView: el maniquí no tiene Skeleton3D o AnimationPlayer")
		return
	_skeleton = skeletons[0] as Skeleton3D
	_anim = players[0] as AnimationPlayer
	_meshes.assign(_mannequin.find_children("*", "MeshInstance3D", true, false))
	_play_idle()
	_anim.animation_finished.connect(_on_animation_finished)

	_bones_mesh = ImmediateMesh.new()
	_bones_node = MeshInstance3D.new()
	_bones_node.mesh = _bones_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	_bones_node.material_override = material
	_holder.add_child(_bones_node)

	if ResourceLoader.exists(SWORD_PATH):
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = HAND_BONE
		_skeleton.add_child(attachment)
		var sword := (load(SWORD_PATH) as PackedScene).instantiate() as Node3D
		attachment.add_child(sword)
		sword.transform = _grip_transform()


## Misma colocación de la espada en el puño que el visor: hoja por el lado del pulgar.
func _grip_transform() -> Transform3D:
	var normal: Vector3 = sword_blade_dir.cross(sword_wide_dir)
	var model_frame := Basis(sword_wide_dir, normal, sword_blade_dir)
	var hand_frame := Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var roll := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(grip_roll_degrees))
	var basis_rot: Basis = roll * hand_frame * model_frame.inverse()
	return Transform3D(basis_rot, grip_offset - basis_rot * sword_grip_center)


func _play_idle() -> void:
	if _anim.has_animation(IDLE_CLIP):
		_anim.get_animation(IDLE_CLIP).loop_mode = Animation.LOOP_LINEAR
		_anim.play(IDLE_CLIP)


func _on_animation_finished(anim_name: StringName) -> void:
	# Al terminar el tajo (y su recuperación) vuelve a la postura de reposo.
	if anim_name.begins_with("Sword_Regular_") and anim_name.ends_with("_Rec"):
		_play_idle()


func _on_weapon_changed(weapon: Weapon) -> void:
	if _weapon != null and _weapon.attacked.is_connected(_on_weapon_attacked):
		_weapon.attacked.disconnect(_on_weapon_attacked)
	_weapon = weapon
	if _weapon != null and _weapon.is_melee():
		_weapon.attacked.connect(_on_weapon_attacked)


func _on_weapon_attacked() -> void:
	if _anim == null:
		return
	_slash_alternate = not _slash_alternate
	var clip: String = "Sword_Regular_B" if _slash_alternate else "Sword_Regular_A"
	_anim.play(clip)
	_anim.queue(clip + "_Rec")


func _process(_delta: float) -> void:
	if _skeleton == null:
		return
	for mesh: MeshInstance3D in _meshes:
		mesh.visible = show_mesh
	_draw_bones()


func _draw_bones() -> void:
	_bones_mesh.clear_surfaces()
	if not show_bones:
		return
	_bones_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in _skeleton.get_bone_count():
		var parent: int = _skeleton.get_bone_parent(i)
		if parent < 0:
			continue
		var name: String = _skeleton.get_bone_name(i)
		var is_arm: bool = (
			name.ends_with("_r")
			and (
				name.begins_with("upperarm")
				or name.begins_with("lowerarm")
				or name.begins_with("hand")
			)
		)
		var color: Color = Color(1.0, 0.8, 0.1) if is_arm else Color(0.3, 0.9, 1.0)
		_bones_mesh.surface_set_color(color)
		_bones_mesh.surface_add_vertex(_bone_position(parent))
		_bones_mesh.surface_set_color(color)
		_bones_mesh.surface_add_vertex(_bone_position(i))
	_bones_mesh.surface_end()


func _bone_position(index: int) -> Vector3:
	return _holder.to_local(
		(_skeleton.global_transform * _skeleton.get_bone_global_pose(index)).origin
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == toggle_key:
		_set_active(not _active)


func _set_active(value: bool) -> void:
	if _third_person_camera == null:
		return
	_active = value
	if _active:
		_third_person_camera.make_current()
	else:
		_first_person_camera.make_current()
	_holder.visible = _active
	_label.visible = _active
	set_process(_active and _skeleton != null)
