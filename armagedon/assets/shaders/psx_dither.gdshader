shader_type canvas_item;
// Dithering ordenado (Bayer 4x4) + cuantización de color, a pantalla completa.
// Corre sobre la imagen ya renderizada a la resolución interna: 1 celda = 1 píxel.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float color_levels : hint_range(2.0, 64.0) = 32.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

void fragment() {
	vec3 color = texture(screen_tex, SCREEN_UV).rgb;
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float threshold = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
	color += threshold * strength / color_levels;
	color = floor(color * color_levels + 0.5) / color_levels;
	COLOR = vec4(color, 1.0);
}
