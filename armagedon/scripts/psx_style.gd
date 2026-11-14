class_name PsxStyle
extends RefCounted
## Aplica el shader PSX (vertex snapping) a todos los MeshInstance3D de un nodo,
## conservando la textura y el color que ya traía cada material original.
## Si el material original no trae textura (caso de las FBX de este proyecto,
## con el PNG suelto en la carpeta), se usa `fallback_texture`.
## Uso: PsxStyle.apply(modelo_instanciado, textura_del_modelo)

const SHADER: Shader = preload("res://assets/shaders/psx.gdshader")


## `snap_resolution` <= 0 usa el valor por defecto del shader.
static func apply(root: Node, fallback_texture: Texture2D = null, snap_resolution: float = 0.0) -> void:
	var converted: Dictionary = {}  # material original -> ShaderMaterial (se comparte)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		_apply_to_mesh(node as MeshInstance3D, fallback_texture, snap_resolution, converted)


static func _apply_to_mesh(
	mesh_instance: MeshInstance3D, fallback_texture: Texture2D, snap_resolution: float, converted: Dictionary
) -> void:
	if mesh_instance.mesh == null:
		return
	for surface in mesh_instance.mesh.get_surface_count():
		var source: Material = mesh_instance.get_active_material(surface)
		if source is ShaderMaterial and (source as ShaderMaterial).shader == SHADER:
			continue  # ya tiene el shader PSX
		if not converted.has(source):
			converted[source] = _make_material(source, fallback_texture, snap_resolution)
		mesh_instance.set_surface_override_material(surface, converted[source])


static func _make_material(source: Material, fallback_texture: Texture2D, snap_resolution: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	if source is BaseMaterial3D:
		var base := source as BaseMaterial3D
		material.set_shader_parameter("albedo_color", base.albedo_color)
		material.set_shader_parameter("albedo_texture", base.albedo_texture if base.albedo_texture else fallback_texture)
	else:
		material.set_shader_parameter("albedo_texture", fallback_texture)
	if snap_resolution > 0.0:
		material.set_shader_parameter("snap_resolution", snap_resolution)
	return material
