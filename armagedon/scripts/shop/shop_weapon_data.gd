class_name ShopWeaponData
extends Resource

enum WeaponSlot {
	FUEGO,
	MELEE
}

@export var id: StringName = &""
@export var nombre: String = ""
@export var slot: WeaponSlot = WeaponSlot.FUEGO
@export_multiline var efecto: String = ""

# TODO(GDD #22): Ajustar precio en tienda y vincular escena/recurso del arma cuando esté listo
@export var precio_tienda: int = 200
@export var weapon_scene: PackedScene
@export var icono: Texture2D