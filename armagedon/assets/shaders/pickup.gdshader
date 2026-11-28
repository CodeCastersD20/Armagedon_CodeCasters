// Pickups 3D (Esquirla/Fe/Vida): textura PSX con temblor de vértices y un brillo que late
// para que se lean en la arena oscura.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float snap_resolution : hint_range(16.0, 640.0, 1.0) = 160.0;
uniform float glow : hint_range(0.0, 2.0) = 0.45;
uniform float pulse_speed = 4.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec2 ndc = clip.xy / clip.w;
	ndc = floor(ndc * snap_resolution + 0.5) / snap_resolution;
	clip.xy = ndc * clip.w;
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = tex.rgb;
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);
	EMISSION = tex.rgb * glow * pulse;
}
