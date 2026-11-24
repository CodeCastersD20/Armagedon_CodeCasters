shader_type spatial;
render_mode unshaded, cull_disabled;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	// Rejilla PSX sutil para mantener el estilo retro.
	vec2 px = floor(centered * 48.0) / 48.0;
	float r = length(px);
	float angle = atan(px.y, px.x);

	// Espiral mística giratoria + anillos concéntricos.
	float spiral = sin(angle * 6.0 - r * 14.0 + TIME * 4.5) * 0.5 + 0.5;
	float rings = sin(r * 22.0 - TIME * 6.0) * 0.5 + 0.5;
	float rays = sin(angle * 12.0 + TIME * 2.5) * 0.5 + 0.5;

	float core = smoothstep(0.38, 0.0, r);
	float energy = mix(spiral, rings, 0.45) * 0.7 + rays * 0.3;
	float edge_fade = smoothstep(1.0, 0.35, r);

	vec3 gold = vec3(1.85, 1.45, 0.65);
	vec3 white = vec3(2.4, 2.4, 2.3);
	vec3 col = mix(gold, white, clamp(core + energy * 0.65, 0.0, 1.0));

	float alpha = clamp((core * 1.2 + energy * edge_fade * 0.95) * step(r, 1.0), 0.0, 1.0);
	ALBEDO = col;
	ALPHA = alpha;
}
