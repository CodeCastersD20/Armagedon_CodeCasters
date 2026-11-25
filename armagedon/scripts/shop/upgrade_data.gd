class_name UpgradeData
extends Resource

enum Category {
	SIEMPRE,        # Vida (curación), Fe (recarga)
	MELEE,          # Mejoras de espada
	FUEGO,          # Mejoras de arma de fuego
	PERSONAJE,      # Stats y movilidad (HP máx, Dash, Velocidad, Alas)
	FE,             # Poderes de Fe
	HABILIDAD_ARMA, # Habilidades de arma (Tajo a distancia, etc.)
	ARMA_FUEGO      # Reemplazo de arma equipada
}

@export var id: StringName = &""
@export var nombre: String = ""
@export var categoria: Category = Category.PERSONAJE
@export_multiline var efecto: String = ""

# TODO(GDD #22): Ajustar precios, valor por nivel y nivel máximo con la tabla final de balance
@export var precio: int = 100
@export var valor_por_nivel: float = 0.0
@export var nivel_maximo: int = 1 # 0 = sin límite (consumibles "Siempre")
@export var icono: Texture2D