shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(0.95, 0.95, 1.0, 0.18);

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	if (intensity <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		// Rejilla pixelada estilo PSX coherente con damage_vignette.
		vec2 px_uv = floor(UV * vec2(160.0, 90.0)) / vec2(160.0, 90.0);
		vec2 centered = px_uv * 2.0 - 1.0;
		float radius = length(centered * vec2(0.85, 1.0));
		float angle = atan(centered.y, centered.x);

		// Rayos radiales delgados solo en el borde exterior para no tapar la visión.
		float sector = floor((angle + 3.14159265) * 22.0);
		float rnd = hash11(sector);
		float streak = step(0.68, fract(rnd * 7.13 + TIME * (4.0 + rnd * 2.5)));
		float edge_mask = smoothstep(0.82 - intensity * 0.06, 1.26, radius);

		float alpha = edge_mask * streak * intensity * line_color.a;
		COLOR = vec4(line_color.rgb, clamp(alpha, 0.0, 0.24));
	}
}
