// Río del Infierno (Barca de Caronte): agua negra y espesa que corre, con ondas pixeladas y
// destellos de la luz del farol. Con luz para que el farol se refleje.
shader_type spatial;
render_mode cull_disabled, diffuse_lambert;

uniform vec3 deep_color : source_color = vec3(0.01, 0.025, 0.03);
uniform vec3 ripple_color : source_color = vec3(0.08, 0.16, 0.15);
uniform vec2 flow = vec2(0.0, 0.35);
uniform float pixel_density = 6.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	// Coordenadas de mundo pixeladas: el patrón no se estira con el tamaño del plano.
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = floor(world.xz * pixel_density) / pixel_density;
	float n = noise(p * 0.6 + flow * TIME) * 0.6 + noise(p * 1.7 - flow * TIME * 1.3) * 0.4;
	float ripple = smoothstep(0.62, 0.7, n) - smoothstep(0.7, 0.78, n);
	ALBEDO = mix(deep_color, ripple_color, ripple);
	ROUGHNESS = 0.15;
	SPECULAR = 0.6;
}
