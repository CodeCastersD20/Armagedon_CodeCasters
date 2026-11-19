class_name Crosshair
extends Control
## Mira en el centro de la pantalla: una cruz con hueco al centro y borde oscuro para que se vea
## sobre cualquier fondo. El disparo sale por el centro de la cámara, que es donde cae la cruz.

@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.7)
## Largo de cada brazo de la cruz, en píxeles.
@export_range(2.0, 40.0, 1.0) var arm_length: float = 8.0
## Hueco entre el centro y cada brazo, en píxeles.
@export_range(0.0, 30.0, 1.0) var gap: float = 4.0
@export_range(1.0, 8.0, 1.0) var thickness: float = 2.0
## Punto en el centro.
@export var show_dot: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var arms: Array[Rect2] = [
		Rect2(center + Vector2(gap, -thickness * 0.5), Vector2(arm_length, thickness)),
		Rect2(
			center + Vector2(-gap - arm_length, -thickness * 0.5), Vector2(arm_length, thickness)
		),
		Rect2(center + Vector2(-thickness * 0.5, gap), Vector2(thickness, arm_length)),
		Rect2(
			center + Vector2(-thickness * 0.5, -gap - arm_length), Vector2(thickness, arm_length)
		),
	]
	if show_dot:
		arms.append(
			Rect2(center - Vector2(thickness, thickness) * 0.5, Vector2(thickness, thickness))
		)
	for rect in arms:
		draw_rect(rect.grow(1.0), outline_color)
	for rect in arms:
		draw_rect(rect, color)
