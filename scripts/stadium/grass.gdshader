shader_type spatial;
// Césped: verde claro parejo con franjas de corte suaves (como la referencia)
// + una variación natural muy leve (ruido procedural).
// Sin texturas externas: funciona en Forward+ y en Compatibilidad.

uniform vec3 color_a : source_color = vec3(0.27, 0.42, 0.15);
uniform vec3 color_b : source_color = vec3(0.255, 0.40, 0.142);
uniform float stripe_width = 5.25;
uniform float variation = 0.1;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	float stripe = step(0.5, fract(world_pos.x / (stripe_width * 2.0)));
	vec3 c = mix(color_a, color_b, stripe);
	float n = noise(world_pos.xz * 0.3) * 0.5 + noise(world_pos.xz * 2.5) * 0.3 + noise(world_pos.xz * 20.0) * 0.2;
	c *= (1.0 - variation * 0.5) + n * variation;
	ALBEDO = c;
	ROUGHNESS = 0.97;
	SPECULAR = 0.15;
}
