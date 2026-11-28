// Paredes de catacumba (pozo del elevador, escalera, derrumbe): osario de huesos y cráneos con
// nichos tallados (textura pixel art que se repite). Con luz: la iluminan las antorchas.
// Funciona por dentro de cilindros: la normal se invierte en las caras traseras.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform sampler2D wall_texture : source_color, filter_nearest, repeat_enable;
// Repeticiones del tile en (contorno, alto).
uniform vec2 tiles = vec2(16.0, 11.0);
uniform float scroll = 0.0;
// Brillo mínimo para que no quede negro lejos de las antorchas.
uniform float ambient_glow = 0.025;
// Más oscuro hacia abajo (0 arriba, 1 abajo en el UV del cilindro).
uniform float depth_darkening = 0.5;

void fragment() {
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec2 uv = UV * tiles + vec2(0.0, scroll);
	vec3 tex = texture(wall_texture, uv).rgb;
	float dark = mix(1.0, 1.0 - depth_darkening, clamp(UV.y, 0.0, 1.0));
	ALBEDO = tex * dark;
	ROUGHNESS = 1.0;
	EMISSION = tex * ambient_glow * dark;
}
