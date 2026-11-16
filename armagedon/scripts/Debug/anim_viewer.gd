extends Node3D
## Visor de animaciones (solo para depurar): muestra el esqueleto de Universal Animation Library
## 1 y 2 con sus huesos, la malla, una espada en la mano derecha y la estela de la mano.
## Abre scenes/Debug/anim_viewer.tscn y ejecútala con F6.

const PACKS: Dictionary = {
	"Pack 1 (UAL1)": "res://assets/animations/universal/UAL1_Standard.glb",
	"Pack 2 (UAL2)": "res://assets/animations/universal/UAL2_Standard.glb",
}
const SWORD_SCENE: String = "res://assets/models/weapons/espada_ps1/Espada PS1.fbx"
const TRAIL_POINTS: int = 90
const HAND_BONE: String = "hand_r"

var _model: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _bones_mesh: ImmediateMesh
var _trail_mesh: ImmediateMesh
var _trail: Array[Vector3] = []
var _hand_marker: MeshInstance3D
var _sword_attachment: BoneAttachment3D
var _sword: Node3D
var _blade_dir: Vector3
var _wide_dir: Vector3
var _grip_center: Vector3

var _yaw: float = 0.5
var _pitch: float = -0.25
var _distance: float = 4.0
var _target: Vector3 = Vector3(0.0, 1.0, 0.0)

var _pack_option: OptionButton
var _anim_option: OptionButton
var _speed_slider: HSlider
var _loop_check: CheckBox
var _bones_check: CheckBox
var _mesh_check: CheckBox
var _sword_check: CheckBox
var _trail_check: CheckBox
var _roll_slider: HSlider
var _roll_label: Label
var _grip_label: Label
var _content: VBoxContainer
var _toggle_button: Button
var _grip_slider: HSlider
var _info: Label

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_build_world()
	_build_ui()
	_load_pack(PACKS.keys()[0])
	_update_camera()


func _build_world() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.0, 10.0)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.18, 0.2)
	plane.material = floor_mat
	add_child(floor_mesh)

	_bones_mesh = ImmediateMesh.new()
	var bones := MeshInstance3D.new()
	bones.mesh = _bones_mesh
	bones.material_override = _line_material()
	add_child(bones)
	_trail_mesh = ImmediateMesh.new()
	var trail := MeshInstance3D.new()
	trail.mesh = _trail_mesh
	trail.material_override = _line_material()
	add_child(trail)

	_hand_marker = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.04
	sphere.height = 0.08
	_hand_marker.mesh = sphere
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.8, 0.1)
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.no_depth_test = true
	_hand_marker.material_override = marker_mat
	add_child(_hand_marker)


func _line_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	return mat


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(8.0, 8.0)
	layer.add_child(panel)
	var root_box := VBoxContainer.new()
	panel.add_child(root_box)

	_toggle_button = Button.new()
	_toggle_button.text = "Ocultar menú (H)"
	_toggle_button.pressed.connect(_toggle_menu)
	root_box.add_child(_toggle_button)

	_content = VBoxContainer.new()
	root_box.add_child(_content)
	var box: VBoxContainer = _content

	_pack_option = OptionButton.new()
	for pack_name: String in PACKS:
		_pack_option.add_item(pack_name)
	_pack_option.item_selected.connect(func(i: int) -> void: _load_pack(_pack_option.get_item_text(i)))
	box.add_child(_pack_option)

	_anim_option = OptionButton.new()
	_anim_option.item_selected.connect(func(_i: int) -> void: _play_selected())
	box.add_child(_anim_option)

	_loop_check = _check("Repetir", true, box)
	_loop_check.toggled.connect(func(_on: bool) -> void: _apply_loop())
	_bones_check = _check("Huesos", true, box)
	_mesh_check = _check("Malla", true, box)
	_sword_check = _check("Espada en la mano derecha", true, box)
	_sword_check.toggled.connect(func(on: bool) -> void: _sword_attachment.visible = on)
	_trail_check = _check("Estela de la mano", true, box)

	_roll_label = Label.new()
	box.add_child(_roll_label)
	_roll_slider = _slider(-180.0, 180.0, 5.0, 0.0, box)
	_grip_label = Label.new()
	box.add_child(_grip_label)
	_grip_slider = _slider(-0.1, 0.2, 0.005, 0.06, box)
	_update_value_labels()

	var speed_label := Label.new()
	speed_label.text = "Velocidad"
	box.add_child(speed_label)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.0
	_speed_slider.max_value = 2.0
	_speed_slider.step = 0.05
	_speed_slider.value = 1.0
	_speed_slider.custom_minimum_size = Vector2(180.0, 0.0)
	_speed_slider.value_changed.connect(func(v: float) -> void: _anim.speed_scale = v)
	box.add_child(_speed_slider)

	var copy_button := Button.new()
	copy_button.text = "Copiar valores finales"
	copy_button.pressed.connect(_copy_values)
	box.add_child(copy_button)

	_info = Label.new()
	box.add_child(_info)
	var help := Label.new()
	help.text = "Clic derecho: girar | Rueda: zoom | Espacio: pausa | H: menú"
	box.add_child(help)


func _toggle_menu() -> void:
	_content.visible = not _content.visible
	_toggle_button.text = "Ocultar menú (H)" if _content.visible else "Mostrar menú (H)"


func _update_value_labels() -> void:
	_roll_label.text = "Giro de la espada: %d°" % int(_roll_slider.value)
	_grip_label.text = "Agarre (subir/bajar por la mano): %.3f m" % _grip_slider.value


## Texto con los valores que hay que pasar a la versión final.
func _values_text() -> String:
	return (
		"grip_roll_degrees = %.1f\ngrip_offset = Vector3(-0.02, %.3f, 0.0)\nblade_dir = %s\nwide_dir = %s\ngrip_center_model = %s"
		% [_roll_slider.value, _grip_slider.value, _blade_dir, _wide_dir, _grip_center]
	)


func _copy_values() -> void:
	var text: String = _values_text()
	DisplayServer.clipboard_set(text)
	print("--- Valores de la espada en la mano ---\n", text)


func _slider(low: float, high: float, step: float, value: float, parent: Node) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = low
	sl.max_value = high
	sl.step = step
	sl.value = value
	sl.custom_minimum_size = Vector2(180.0, 0.0)
	sl.value_changed.connect(
		func(_v: float) -> void:
			_update_value_labels()
			_fit_sword()
	)
	parent.add_child(sl)
	return sl


func _check(label: String, value: bool, parent: Node) -> CheckBox:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = value
	parent.add_child(c)
	return c


func _load_pack(pack_name: String) -> void:
	if _model != null:
		_model.queue_free()
	var scene := load(PACKS[pack_name]) as PackedScene
	_model = scene.instantiate() as Node3D
	add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE

	_sword_attachment = BoneAttachment3D.new()
	_sword_attachment.bone_name = HAND_BONE
	_skeleton.add_child(_sword_attachment)
	_sword = (load(SWORD_SCENE) as PackedScene).instantiate() as Node3D
	_sword_attachment.add_child(_sword)
	_analyze_sword()
	_fit_sword()
	_sword_attachment.visible = _sword_check != null and _sword_check.button_pressed

	_anim_option.clear()
	for anim_name in _anim.get_animation_list():
		_anim_option.add_item(anim_name)
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = _mesh_check == null or _mesh_check.button_pressed
	_play_selected()


## Mide el modelo de la espada: dirección de la hoja, ancho de la guarda y centro del mango.
## La hoja es el lado largo (de la guarda a la punta); el mango, el lado corto (guarda a pomo).
func _analyze_sword() -> void:
	var mesh_instance := _sword.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var to_sword: Transform3D = _sword.global_transform.affine_inverse() * mesh_instance.global_transform
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var points: Array[Vector3] = []
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for v in verts:
		var p: Vector3 = to_sword * v
		points.append(p)
		low = low.min(p)
		high = high.max(p)
	var size: Vector3 = high - low
	var long_axis: int = size.max_axis_index()
	var wide_axis: int = 0
	var best_wide: float = -1.0
	for axis in 3:
		if axis != long_axis and size[axis] > best_wide:
			best_wide = size[axis]
			wide_axis = axis
	# Guarda: tramo del eje largo donde la espada es más ancha.
	var bins: int = 24
	var width_min: Array[float] = []
	var width_max: Array[float] = []
	for b in bins:
		width_min.append(INF)
		width_max.append(-INF)
	for p in points:
		var t: float = (p[long_axis] - low[long_axis]) / maxf(size[long_axis], 0.0001)
		var b: int = clampi(int(t * bins), 0, bins - 1)
		width_min[b] = minf(width_min[b], p[wide_axis])
		width_max[b] = maxf(width_max[b], p[wide_axis])
	var guard_bin: int = 0
	var guard_width: float = -1.0
	for b in bins:
		var w: float = width_max[b] - width_min[b]
		if w > guard_width:
			guard_width = w
			guard_bin = b
	var guard_pos: float = low[long_axis] + size[long_axis] * (float(guard_bin) + 0.5) / bins
	var from_low: float = guard_pos - low[long_axis]
	var from_high: float = high[long_axis] - guard_pos
	# El lado más largo desde la guarda es la hoja.
	var blade_sign: float = -1.0 if from_low > from_high else 1.0
	var grip_end: float = high[long_axis] if blade_sign < 0.0 else low[long_axis]
	_blade_dir = Vector3.ZERO
	_blade_dir[long_axis] = blade_sign
	_wide_dir = Vector3.ZERO
	_wide_dir[wide_axis] = 1.0
	_grip_center = (low + high) * 0.5
	_grip_center[long_axis] = (guard_pos + grip_end) * 0.5


## Coloca la espada en el puño derecho: el mango cruza la palma y la hoja sale por el lado del pulgar.
## Ejes de la mano en este rig: +Y = dedos, +Z = pulgar, -X = palma.
func _fit_sword() -> void:
	if _sword == null or _roll_slider == null:
		return
	var normal: Vector3 = _blade_dir.cross(_wide_dir)
	var model_frame := Basis(_wide_dir, normal, _blade_dir)
	var hand_frame := Basis(Vector3(0.0, 1.0, 0.0), Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0))
	var roll := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(_roll_slider.value))
	var rotation_basis: Basis = roll * hand_frame * model_frame.inverse()
	var grip_in_hand := Vector3(-0.02, _grip_slider.value, 0.0)
	_sword.transform = Transform3D(rotation_basis, grip_in_hand - rotation_basis * _grip_center)


func _play_selected() -> void:
	if _anim_option.item_count == 0:
		return
	_trail.clear()
	_apply_loop()
	_anim.play(_anim_option.get_item_text(_anim_option.selected))
	_anim.speed_scale = _speed_slider.value if _speed_slider != null else 1.0


func _apply_loop() -> void:
	if _anim_option.item_count == 0:
		return
	var animation := _anim.get_animation(_anim_option.get_item_text(_anim_option.selected))
	animation.loop_mode = Animation.LOOP_LINEAR if _loop_check.button_pressed else Animation.LOOP_NONE


func _process(_delta: float) -> void:
	if _skeleton == null:
		return
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		mesh.visible = _mesh_check.button_pressed
	_draw_bones()
	_update_hand()
	_update_info()


func _draw_bones() -> void:
	_bones_mesh.clear_surfaces()
	if not _bones_check.button_pressed:
		return
	_bones_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in _skeleton.get_bone_count():
		var parent := _skeleton.get_bone_parent(i)
		if parent < 0:
			continue
		var a: Vector3 = _bone_world(parent)
		var b: Vector3 = _bone_world(i)
		var is_hand: bool = _skeleton.get_bone_name(i).ends_with("_r") and (
			_skeleton.get_bone_name(i).begins_with("upperarm")
			or _skeleton.get_bone_name(i).begins_with("lowerarm")
			or _skeleton.get_bone_name(i).begins_with("hand")
		)
		var color: Color = Color(1.0, 0.8, 0.1) if is_hand else Color(0.3, 0.9, 1.0)
		_bones_mesh.surface_set_color(color)
		_bones_mesh.surface_add_vertex(a)
		_bones_mesh.surface_set_color(color)
		_bones_mesh.surface_add_vertex(b)
	_bones_mesh.surface_end()


func _bone_world(index: int) -> Vector3:
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(index)).origin


func _update_hand() -> void:
	var hand: int = _skeleton.find_bone(HAND_BONE)
	if hand < 0:
		return
	var pos: Vector3 = _bone_world(hand)
	_hand_marker.global_position = pos
	_hand_marker.visible = _trail_check.button_pressed
	_trail.append(pos)
	if _trail.size() > TRAIL_POINTS:
		_trail.pop_front()
	_trail_mesh.clear_surfaces()
	if not _trail_check.button_pressed or _trail.size() < 2:
		return
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in _trail.size():
		var fade: float = float(i) / float(_trail.size())
		_trail_mesh.surface_set_color(Color(1.0, 0.4, 0.2, fade))
		_trail_mesh.surface_add_vertex(_trail[i])
	_trail_mesh.surface_end()


func _update_info() -> void:
	if not _anim.is_playing() and _anim.current_animation == "":
		_info.text = "Sin animación"
		return
	var length: float = _anim.current_animation_length
	_info.text = (
		"%s  %.2f / %.2f s\n%s"
		% [_anim.current_animation, _anim.current_animation_position, length, _values_text()]
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.01
		_pitch = clampf(_pitch - event.relative.y * 0.01, -1.4, 1.4)
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(_distance - 0.3, 0.8)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(_distance + 0.3, 12.0)
			_update_camera()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_H:
		_toggle_menu()
	elif event.is_action_pressed("ui_accept") or (
		event is InputEventKey and event.pressed and event.keycode == KEY_SPACE
	):
		if _anim.is_playing():
			_anim.pause()
		else:
			_anim.play()


func _update_camera() -> void:
	var offset := Vector3(0.0, 0.0, _distance)
	offset = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * offset
	_camera.position = _target + offset
	_camera.look_at(_target)
