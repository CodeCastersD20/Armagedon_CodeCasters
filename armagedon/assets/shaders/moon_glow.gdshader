shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, fog_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(0.95, 0.18, 0.14, 1.0);
uniform float glow_strength : hint_range(0.0, 1.5) = 0.55;
uniform float edge_softness : hint_range(0.01, 0.3) = 0.08;

void vertex() {
	// Billboard orientado a la cámara.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;

	// El disco lunar ocupa el centro para dejar margen al halo difuminado alrededor.
	vec2 disc_uv = centered * 1.45 + vec2(0.5);
	float disc_r = length(disc_uv - vec2(0.5)) * 2.0;

	vec4 tex = vec4(0.0);
	if (disc_uv.x >= 0.0 && disc_uv.x <= 1.0 && disc_uv.y >= 0.0 && disc_uv.y <= 1.0) {
		tex = texture(albedo_texture, disc_uv);
	}

	float rim_fade = smoothstep(1.0, 1.0 - edge_softness, disc_r);
	float disc_alpha = tex.a * rim_fade;

	float halo = pow(clamp(1.0 - dist, 0.0, 1.0), 2.4) * glow_strength;
	vec3 disc_rgb = tex.rgb * albedo_color.rgb * 1.15;
	vec3 halo_rgb = albedo_color.rgb * 1.1;

	ALBEDO = mix(halo_rgb, disc_rgb, disc_alpha);
	ALPHA = clamp(max(disc_alpha, halo), 0.0, 1.0);
}
