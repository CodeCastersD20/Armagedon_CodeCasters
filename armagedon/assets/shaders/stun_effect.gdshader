shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

void fragment() {
	if (intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Rejilla pixelada PSX + pulso radial ámbar/blanco de impacto/aturdimiento.
		vec2 px_uv = floor(UV * vec2(160.0, 90.0)) / vec2(160.0, 90.0);
		vec2 centered = px_uv * 2.0 - 1.0;
		float dist = length(centered * vec2(0.85, 1.0));
		float angle = atan(centered.y, centered.x);

		float pulse = 0.5 + 0.5 * sin(TIME * 22.0);
		float wave = sin(dist * 14.0 - TIME * 16.0 + sin(angle * 4.0) * 0.6);
		float edge = smoothstep(0.45 - intensity * 0.15, 1.18, dist);
		float spark = step(0.82, hash21(px_uv * 24.0 + floor(TIME * 18.0)));

		float ring = clamp(0.45 + 0.35 * wave + 0.2 * pulse, 0.0, 1.0);
		float alpha = edge * ring * intensity * 0.52 + spark * edge * intensity * 0.25;
		vec3 col = mix(vec3(1.0, 0.68, 0.12), vec3(1.0, 0.95, 0.72), pulse * 0.5 + spark * 0.5);

		COLOR = vec4(col, clamp(alpha, 0.0, 0.62));
	}
}
