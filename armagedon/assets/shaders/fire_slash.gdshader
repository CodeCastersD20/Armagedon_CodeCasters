// Media luna de fuego de "La Espada en Llamas": sprite pixel art 2D que siempre mira a la cámara
// (billboard) y mantiene su inclinación en pantalla, así se lee igual aunque el jugador se mueva.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform int frames = 4;
uniform float fps = 14.0;
// Tamaño en metros (ancho, alto) y giro en el plano de la cámara (radianes).
uniform vec2 size = vec2(2.6, 1.3);
uniform float roll = 0.0;
// 1 = brillo completo, 0 = apagado (con blend_add, oscurecer equivale a desvanecer).
uniform float fade : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	vec2 p = VERTEX.xy * size;
	float c = cos(roll);
	float s = sin(roll);
	p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	vec3 world = MODEL_MATRIX[3].xyz + INV_VIEW_MATRIX[0].xyz * p.x + INV_VIEW_MATRIX[1].xyz * p.y;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(world, 1.0));
}

void fragment() {
	float frame = floor(mod(TIME * fps, float(frames)));
	vec4 tex = texture(atlas, vec2((frame + UV.x) / float(frames), UV.y));
	if (tex.a < 0.5) {
		discard;
	}
	ALBEDO = tex.rgb * fade;
}
