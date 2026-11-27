shader_type canvas_item;
// Bordes de pantalla en llamas (quemadura). Rejilla pixelada PSX; solo se dibuja mientras hay quemadura.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	if (intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 px_uv = floor(UV * vec2(160.0, 90.0)) / vec2(160.0, 90.0);
		vec2 centered = px_uv * 2.0 - 1.0;
		float edge = length(centered * vec2(0.9, 1.0));
		// Las llamas quedan solo en el borde inferior y las esquinas para no tapar la vista.
		float bottom = smoothstep(0.42, 1.05, centered.y);
		float radial = smoothstep(0.76 - intensity * 0.10, 1.22, edge);
		float flicker = noise2d(vec2(px_uv.x * 14.0, px_uv.y * 9.0 - TIME * 3.5));
		flicker += noise2d(vec2(px_uv.x * 28.0 + 3.1, px_uv.y * 18.0 - TIME * 6.0)) * 0.5;
		float mask = (radial * 0.7 + bottom * 0.5) * (0.55 + flicker * 0.6);
		float alpha = smoothstep(0.42, 0.88, mask) * (0.14 + intensity * 0.28);
		vec3 hot = vec3(1.0, 0.85, 0.25);
		vec3 cool = vec3(0.9, 0.2, 0.02);
		COLOR = vec4(mix(cool, hot, flicker * 0.6), clamp(alpha, 0.0, 0.38));
	}
}
