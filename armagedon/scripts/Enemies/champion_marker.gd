class_name ChampionMarker
extends Node3D
## Corona flotante y aura pequeña de un Campeón.
## Mallas y materiales compartidos (sin new() por spawn).

static var _crown_mesh: CylinderMesh
static var _aura_mesh: SphereMesh
static var _crown_mat: StandardMaterial3D
static var _aura_mat: StandardMaterial3D

var _crown: MeshInstance3D


## Crea el marcador encima de la cabeza (`head_height` en metros sobre el origen del enemigo).
static func create(champion: ChampionData, head_height: float) -> ChampionMarker:
	var marker := ChampionMarker.new()
	marker.name = "ChampionMarker"
	_ensure_shared(champion)
	marker._crown = MeshInstance3D.new()
	marker._crown.mesh = _crown_mesh
	marker._crown.material_override = _crown_mat
	marker._crown.position = Vector3(0.0, head_height + 0.25, 0.0)
	marker.add_child(marker._crown)
	var aura := MeshInstance3D.new()
	aura.mesh = _aura_mesh
	aura.material_override = _aura_mat
	aura.position = Vector3(0.0, head_height * 0.5, 0.0)
	marker.add_child(aura)
	return marker


static func _ensure_shared(champion: ChampionData) -> void:
	if _crown_mesh != null:
		return
	# Corona: cilindro de 5 lados, ancho arriba (low-poly).
	_crown_mesh = CylinderMesh.new()
	_crown_mesh.top_radius = 0.28
	_crown_mesh.bottom_radius = 0.2
	_crown_mesh.height = 0.22
	_crown_mesh.radial_segments = 5
	_crown_mesh.rings = 1
	_crown_mat = StandardMaterial3D.new()
	_crown_mat.albedo_color = champion.crown_color
	_crown_mat.emission_enabled = true
	_crown_mat.emission = champion.crown_color
	_crown_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mesh = SphereMesh.new()
	_aura_mesh.radius = 1.0
	_aura_mesh.height = 2.0
	_aura_mesh.radial_segments = 8
	_aura_mesh.rings = 4
	_aura_mat = StandardMaterial3D.new()
	_aura_mat.albedo_color = champion.aura_color
	_aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aura_mat.cull_mode = BaseMaterial3D.CULL_FRONT


func _process(delta: float) -> void:
	if _crown != null:
		_crown.rotate_y(delta * 2.0)
