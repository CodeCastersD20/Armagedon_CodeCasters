// Pickups 2D: sprite pixel art que siempre mira a la cámara (billboard, como la luna).
// Conserva la escala de cada instancia del MultiMesh (el parpadeo final usa escala 0).
// Atlas: filas = tipo de pickup, columnas = frames de animación.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform sampler2D atlas : source_color, filter_nearest;
uniform int row = 0;
uniform int rows = 3;
uniform int frames = 4;
uniform float fps = 6.0;

varying float frame_index;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	mat4 billboard = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard
		* mat4(vec4(scale.x, 0.0, 0.0, 0.0), vec4(0.0, scale.y, 0.0, 0.0), vec4(0.0, 0.0, scale.z, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// Desfase por instancia (posición) para que no animen todos a la vez.
	float phase = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
	frame_index = floor(mod(TIME * fps + phase * float(frames), float(frames)));
}

void fragment() {
	vec2 cell = vec2(1.0 / float(frames), 1.0 / float(rows));
	vec2 uv = (vec2(frame_index, float(row)) + UV) * cell;
	vec4 tex = texture(atlas, uv);
	if (tex.a < 0.5) {
		discard;
	}
	ALBEDO = tex.rgb;
}
