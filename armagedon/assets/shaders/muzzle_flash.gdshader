shader_type spatial;
render_mode unshaded, cull_disabled, blend_add;

void vertex() {
	// Siempre mira hacia la cámara (billboard) manteniendo la rotación Z del nodo.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = floor(UV * 24.0) / 24.0;
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);

	// Estrella irregular de fogonazo PSX (6 puntas).
	float spikes = pow(abs(cos(a * 3.0)), 2.2) * 0.55 + pow(abs(sin(a * 5.0)), 3.0) * 0.25;
	float shape = smoothstep(0.45 + spikes, 0.08, r);
	float core = smoothstep(0.32, 0.0, r);

	vec3 outer_fire = vec3(1.8, 0.48, 0.05);
	vec3 hot_core = vec3(2.4, 2.1, 1.1);
	ALBEDO = mix(outer_fire, hot_core, core);
	ALPHA = clamp(shape, 0.0, 1.0);
}
