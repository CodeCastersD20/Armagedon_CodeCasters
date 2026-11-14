shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
// Menos = más temblor. ~160 da el look PS1 clásico.
uniform float snap_resolution : hint_range(16.0, 640.0, 1.0) = 160.0;

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
}