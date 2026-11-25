shader_type canvas_item;

uniform float scroll_time = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	// Rejilla PSX de 160x90 para paredes de piedra y lava cayendo al abismo.
	vec2 uv = floor(UV * vec2(160.0, 90.0)) / vec2(160.0, 90.0);
	float scroll_y = uv.y + scroll_time * 1.85;

	// Profundidad del abismo: más oscuro arriba, resplandor infernal abajo.
	vec3 abyss = mix(vec3(0.04, 0.01, 0.01), vec3(0.32, 0.05, 0.02), pow(uv.y, 1.5));

	// Paredes laterales de piedra dentada pasando rápido hacia arriba.
	float dist_edge = min(uv.x, 1.0 - uv.x);
	float rock_noise = noise2d(vec2(uv.x * 12.0, scroll_y * 6.0));
	float detail_noise = noise2d(vec2(uv.x * 28.0, scroll_y * 14.0));
	float wall_width = 0.22 + rock_noise * 0.14;

	vec3 col = abyss;
	if (dist_edge < wall_width) {
		float shade = 0.45 + detail_noise * 0.55;
		vec3 stone = vec3(0.14, 0.07, 0.06) * shade;
		// Grietas de lava brillante dentro de la pared de piedra.
		float lava_crack = smoothstep(0.76, 0.86, detail_noise * 0.6 + rock_noise * 0.45);
		vec3 lava = mix(vec3(0.95, 0.22, 0.02), vec3(1.0, 0.72, 0.15), lava_crack);
		col = mix(stone, lava, lava_crack * 0.85);
	} else {
		// Líneas sutiles de velocidad en el centro del abismo.
		float streak = noise2d(vec2(uv.x * 42.0, scroll_y * 10.0));
		col += vec3(0.28, 0.06, 0.02) * smoothstep(0.82, 0.96, streak) * 0.5;
	}

	COLOR = vec4(col, 1.0);
}
