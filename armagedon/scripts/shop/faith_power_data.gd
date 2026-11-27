class_name FaithPowerData
extends Resource

@export var id: StringName = &""
@export var nombre: String = ""
@export_multiline var efecto: String = ""

# TODO(GDD #22): Definir costo de Fe, cooldown, precio en tienda y escalado por nivel
@export var precio_tienda: int = 150
@export var costo_fe: float = 25.0
@export var cooldown: float = 5.0
# TODO(GDD): Confirmar duración definitiva de buffs temporales (0 = efecto instantáneo)
@export var duracion: float = 0.0
@export var valor_por_nivel: float = 10.0
@export var nivel_maximo: int = 3
@export var icono: Texture2D
