class_name PsxStyleSettings
extends Resource
## Ajustes del estilo PSX (resolución interna y dithering). Instancia en data/psx_style.tres.

## Resolución interna a la que se renderiza el juego antes de escalar a la ventana.
# TODO(GDD): 640x480 o 320x240 sin decidir (GDD §13).
@export var internal_resolution: Vector2i = Vector2i(640, 480)
## Activa o desactiva el dithering (ordenado, matriz Bayer 4x4).
@export var dither_enabled: bool = true
## Intensidad del patrón de dithering (0 = sin patrón, 1 = máximo).
@export_range(0.0, 1.0, 0.05) var dither_strength: float = 0.6
## Niveles de color por canal tras cuantizar (menos = más "PSX"; 32 ≈ 15 bits).
@export_range(2.0, 64.0, 1.0) var color_levels: float = 32.0
