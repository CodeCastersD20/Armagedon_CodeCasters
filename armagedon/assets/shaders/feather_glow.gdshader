shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec3 white_color : source_color = vec3(1.15, 1.15, 1.12);
uniform vec3 gold_color : source_color = vec3(2.4, 1.8, 0.45);
uniform float rim_power : hint_range(0.5, 8.0) = 1.65;
uniform float rim_min : hint_range(0.0, 0.95) = 0.22;
uniform float rim_max : hint_range(0.05, 1.0) = 0.72;
uniform float edge_boost : hint_range(0.0, 3.0) = 1.4;

varying float v_alpha;

void vertex() {
	v_alpha = INSTANCE_CUSTOM.r;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndotv = clamp(abs(dot(n, v)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, rim_power);
	float rim = smoothstep(rim_min, rim_max, fresnel);

	vec3 col = mix(white_color, gold_color * edge_boost, rim);
	ALBEDO = col;
	ALPHA = clamp(v_alpha, 0.0, 1.0);
}
