shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform int mode : hint_range(0, 2) = 2;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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
	if (intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Rejilla pixelada PSX para que las manchas se integren con el estilo del juego.
		vec2 px_uv = floor(UV * vec2(160.0, 90.0)) / vec2(160.0, 90.0);
		vec2 centered = px_uv * 2.0 - 1.0;
		float edge_dist = length(centered * vec2(0.85, 1.0));
		float radial = smoothstep(0.35 - intensity * 0.25, 1.25, edge_dist);

		// Tinte rojo progresivo en bordes + latido.
		float tint_alpha = clamp(radial * (0.25 + intensity * 0.72 + pulse * 0.16), 0.0, 0.85);

		// Manchas de sangre orgánicas alrededor de los bordes.
		float n1 = noise2d(px_uv * 11.0);
		float n2 = noise2d(px_uv * 23.0 + vec2(4.2, 7.1));
		float blob = n1 * 0.65 + n2 * 0.35;
		float splatter_mask = radial * (0.55 + intensity * 0.75) + blob * 0.45;
		float splatter_alpha = smoothstep(0.72 - intensity * 0.38, 0.88 - intensity * 0.30, splatter_mask);
		splatter_alpha = clamp(splatter_alpha * (0.55 + intensity * 0.45 + pulse * 0.12), 0.0, 0.92);

		float final_alpha = 0.0;
		vec3 final_color = vec3(0.62, 0.02, 0.02);

		if (mode == 0) {
			final_alpha = tint_alpha;
			final_color = vec3(0.75, 0.03, 0.03);
		} else if (mode == 1) {
			final_alpha = splatter_alpha;
			final_color = mix(vec3(0.45, 0.01, 0.01), vec3(0.72, 0.02, 0.02), n2);
		} else {
			final_alpha = max(tint_alpha * 0.75, splatter_alpha);
			final_color = mix(vec3(0.72, 0.03, 0.03), vec3(0.45, 0.01, 0.01), splatter_alpha * 0.7);
		}

		COLOR = vec4(final_color, final_alpha);
	}
}
